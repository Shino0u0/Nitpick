import AppKit
import Foundation
import Observation
import SwiftData

enum MainTab: String, CaseIterable, Identifiable {
    case history = "History"
    case models = "Models"
    case modes = "Modes"
    case dictionary = "Dictionary"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .history: "clock"
        case .models: "cpu"
        case .modes: "sparkles"
        case .dictionary: "character.book.closed"
        }
    }
}

enum RecorderState: Equatable {
    case idle
    case recording
    case processing(String)
    case notice(String)
}

/// Main-actor hub: owns the store, services, pipeline, recorder panel state
/// and the currently selected Mode.
@MainActor
@Observable
final class AppState {
    let store: AppStore
    let modelCache = ModelCache.standard()
    let transcriber = FluidAudioTranscriber()
    private let pipeline: ActionPipeline
    let hotkeys = HotkeyManager()

    var selectedTab: MainTab = .history
    var selectedModeID: UUID?
    var recorderState: RecorderState = .idle
    var recorderLevels: [Float] = []
    var activeAction: VortextAction = .dictate
    var askResponse: String?
    var lastError: String?
    var onboardingCompleted: Bool

    private var recorderPanel: RecorderPanelController?
    private var askPanel: AskPanelController?
    private var currentTarget: TargetApp?

    init() throws {
        let store = try AppStore()
        self.store = store
        onboardingCompleted = (try? store.settings().onboardingCompleted) ?? false
        pipeline = ActionPipeline(
            services: PipelineServices(
                recorder: AVAudioEngineRecorder(),
                transcriber: transcriber,
                inserter: AccessibilityTextInserter(),
                collector: SystemContextCollector(),
                providerClient: { OpenAICompatibleClient(provider: $0) },
                apiKey: { try KeychainStore().read(provider: $0) }
            )
        )
        selectedModeID = try? store.modes().first?.id
        registerHotkeys()
    }

    // MARK: - Modes

    var selectedMode: ModeRecord? {
        let modes = (try? store.modes()) ?? []
        return modes.first { $0.id == selectedModeID } ?? modes.first
    }

    private func modeInput(for record: ModeRecord) -> ModeInput {
        let settings = try? store.settings()
        return ModeInput(
            id: record.id,
            name: record.name,
            isSystemDefault: record.isSystemDefault,
            instructions: record.instructions,
            providerID: record.isSystemDefault
                ? nil : record.providerOverride ?? settings?.defaultProviderID,
            modelID: record.isSystemDefault
                ? nil : record.modelOverride ?? settings?.defaultModelID
        )
    }

    // MARK: - Actions

    func startAction(_ action: VortextAction) {
        guard recorderState == .idle else { return }
        activeAction = action
        currentTarget = TargetApp.frontmost()
        recorderState = .recording
        recorderLevels = []
        showRecorderPanel()
        Task {
            do {
                let deviceUID = try? store.settings().selectedInputDeviceUID
                try await pipeline.startRecording(deviceUID: deviceUID) { level in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        recorderLevels.append(level)
                        if recorderLevels.count > 60 { recorderLevels.removeFirst() }
                    }
                }
            } catch {
                recorderState = .notice("Microphone unavailable")
                hideRecorderPanelSoon()
            }
        }
    }

    func stopAndProcess() {
        guard recorderState == .recording else { return }
        recorderState = .processing("Transcribing")
        let modeRecord = selectedMode
        Task {
            await finishAction(modeRecord: modeRecord)
        }
    }

    func cancelAction() {
        Task { await pipeline.cancelRecording() }
        recorderState = .idle
        recorderPanel?.hide()
    }

    private func finishAction(modeRecord: ModeRecord?) async {
        let mode = modeRecord.map(modeInput(for:))
            ?? ModeInput(name: "Default", isSystemDefault: true, instructions: "")
        let rules = (try? store.activeRules()) ?? []
        let settings = try? store.settings()
        let config = PipelineConfig(
            enabledSources: settings?.enabledContextSources ?? [],
            contextConsent: settings?.contextConsentGranted ?? false,
            storedKeyHashes: storedKeyHashes(),
            modelSupportsImage: modelSupportsImage(mode: mode)
        )
        let action = activeAction
        let outcome = await pipeline.run(
            action: action, mode: mode, rules: rules, config: config,
            target: currentTarget
        ) { stage in
            Task { @MainActor [weak self] in
                self?.recorderState = .processing(Self.label(for: stage))
            }
        }
        persist(outcome: outcome, action: action, mode: mode)

        switch outcome.status {
        case .succeeded:
            if action == .ask, let answer = outcome.finalOutput {
                askResponse = answer
                showAskPanel()
            }
            if outcome.insertion == .copiedToClipboard {
                recorderState = .notice("Copied - paste into your app")
            } else if let reason = outcome.clipboardOmittedReason {
                recorderState = .notice(reason)
            } else {
                recorderState = .idle
            }
        case .failed:
            recorderState = .notice(Self.message(for: outcome.errorCategory))
        case .cancelled:
            recorderState = .idle
        }
        hideRecorderPanelSoon()
    }

    private func persist(
        outcome: PipelineOutcome, action: VortextAction, mode: ModeInput
    ) {
        let entry = HistoryEntry(
            duration: outcome.duration,
            action: action,
            status: outcome.status,
            modeID: mode.id,
            modeName: mode.name,
            providerID: mode.providerID,
            modelID: mode.modelID,
            targetAppBundleID: currentTarget?.bundleID,
            targetAppName: currentTarget?.name,
            originalTranscript: outcome.originalTranscript,
            finalOutput: outcome.finalOutput,
            usedContext: outcome.usedContext,
            audioFileURL: outcome.audioURL,
            errorCategory: outcome.errorCategory
        )
        try? store.addHistory(entry)
    }

    /// Hashes of currently stored provider keys for the clipboard guard.
    /// Keys are read, hashed, and dropped immediately.
    private func storedKeyHashes() -> Set<String> {
        var hashes: Set<String> = []
        let keychain = KeychainStore()
        for provider in ProviderID.allCases {
            if let key = try? keychain.read(provider: provider) {
                hashes.insert(key.withRaw { SecretGuard.hash($0) })
            }
        }
        return hashes
    }

    private func modelSupportsImage(mode: ModeInput) -> Bool {
        guard let provider = mode.providerID, let modelID = mode.modelID,
            let entry = modelCache.load(for: provider)
        else { return false }
        return entry.models.first { $0.modelID == modelID }?.supportsImageInput
            ?? false
    }

    // MARK: - Panels

    private func showRecorderPanel() {
        if recorderPanel == nil {
            recorderPanel = RecorderPanelController(appState: self)
        }
        recorderPanel?.show()
    }

    private func hideRecorderPanelSoon() {
        Task {
            try? await Task.sleep(for: .seconds(recorderState == .idle ? 0.3 : 2.2))
            if recorderState != .recording {
                recorderState = .idle
                recorderPanel?.hide()
            }
        }
    }

    private func showAskPanel() {
        if askPanel == nil {
            askPanel = AskPanelController(appState: self)
        }
        askPanel?.show()
    }

    // MARK: - Hotkeys

    func registerHotkeys() {
        let settings = try? store.settings()
        let dictate = settings?.dictateShortcut.flatMap(HotkeyManager.Shortcut.init)
            ?? .defaultDictate
        let ask = settings?.askShortcut.flatMap(HotkeyManager.Shortcut.init)
            ?? .defaultAsk
        _ = hotkeys.register(dictate, id: 1) { [weak self] in
            self?.toggleFromShortcut(.dictate)
        }
        _ = hotkeys.register(ask, id: 2) { [weak self] in
            self?.toggleFromShortcut(.ask)
        }
    }

    private func toggleFromShortcut(_ action: VortextAction) {
        if recorderState == .recording {
            stopAndProcess()
        } else {
            startAction(action)
        }
    }

    // MARK: - Onboarding

    func completeOnboarding() {
        if let settings = try? store.settings() {
            settings.onboardingCompleted = true
            try? store.save()
        }
        onboardingCompleted = true
        selectedTab = .history
    }

    // MARK: - Status labels

    private static func label(for stage: PipelineStage) -> String {
        switch stage {
        case .transcribing: "Transcribing"
        case .collectingContext: "Collecting context"
        case .enhancing: "Enhancing"
        case .inserting: "Inserting"
        }
    }

    static func message(for category: ErrorCategory?) -> String {
        switch category {
        case .transcriptionFailed: "Transcription failed - try again"
        case .providerInvalidKey: "Invalid API key - check Models"
        case .providerRateLimited: "Rate limited - transcript kept"
        case .providerUnavailable: "Provider unavailable - transcript kept"
        case .modelRemoved: "Model removed - pick a new one"
        case .accessibilityUnavailable: "Copied - paste into your app"
        case .placeholderCorrupted: "Kept your exact values"
        case .network: "Network error - transcript kept"
        case .unknown, .none: "Something went wrong - transcript kept"
        }
    }
}
