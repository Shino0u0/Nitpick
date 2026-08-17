import AVFoundation
import AppKit
import ScreenCaptureKit
import SwiftUI

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome, access, microphone, localModel, accessibility, screen,
        models, shortcuts, tryDictate, complete

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome: "Welcome"
        case .access: "Access"
        case .microphone: "Microphone"
        case .localModel: "Local Model"
        case .accessibility: "Accessibility"
        case .screen: "Screen Context"
        case .models: "Models"
        case .shortcuts: "Shortcuts"
        case .tryDictate: "Try Dictate"
        case .complete: "Done"
        }
    }
}

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var step: OnboardingStep = .welcome
    @State private var microphoneGranted = false
    @State private var modelProgress: Double = 0
    @State private var modelState: ModelState = .idle
    @State private var accessibilityTrusted = AXIsProcessTrusted()

    enum ModelState: Equatable { case idle, downloading, ready, failed }

    var body: some View {
        HStack(spacing: 0) {
            rail
            page
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(28)
                .background(NP.canvas)
        }
        .frame(minWidth: 760, minHeight: 520)
    }

    private var rail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Vortex")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.bottom, 8)
            ForEach(OnboardingStep.allCases) { candidate in
                HStack(spacing: 8) {
                    Circle()
                        .fill(
                            candidate.rawValue < step.rawValue
                                ? NP.accent
                                : candidate == step
                                    ? Color.white : .white.opacity(0.25)
                        )
                        .frame(width: 7, height: 7)
                    Text(candidate.title)
                        .font(.caption)
                        .foregroundStyle(
                            candidate == step ? .white : .white.opacity(0.55)
                        )
                }
            }
            Spacer()
        }
        .padding(16)
        .frame(width: 150)
        .frame(maxHeight: .infinity)
        .background(NP.rail)
    }

    @ViewBuilder
    private var page: some View {
        VStack(alignment: .leading, spacing: 14) {
            NPEyebrow("Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count)")
            Text(step.title).font(.title2.weight(.semibold))
            stepBody
            Spacer()
            controls
        }
    }

    @ViewBuilder
    private var stepBody: some View {
        switch step {
        case .welcome:
            explain(
                "Vortex turns speech into text anywhere on your Mac.",
                "Transcription runs entirely on this Mac. Cloud Modes are optional, use your own API keys, and only send what you approve. No account, no telemetry."
            )
        case .access:
            explain(
                "A quick tour of what Vortex may ask for.",
                "Microphone is required to record. The local model download is required once. Accessibility lets Vortex type for you (optional - clipboard fallback works). Screen Recording is optional and only used for explicit screen context."
            )
        case .microphone:
            explain(
                "Vortex records only while you dictate or ask.",
                "macOS will ask for microphone access the first time."
            )
            Button(microphoneGranted ? "Microphone ready" : "Allow microphone") {
                requestMicrophone()
            }
            .buttonStyle(NPCapsuleButtonStyle(prominent: !microphoneGranted))
            .disabled(microphoneGranted)
        case .localModel:
            explain(
                "One local Parakeet model powers transcription.",
                "About a one-time download. Afterwards Dictate works offline."
            )
            switch modelState {
            case .idle:
                Button("Download model") { downloadModel() }
                    .buttonStyle(NPCapsuleButtonStyle(prominent: true))
            case .downloading:
                ProgressView(value: modelProgress) {
                    Text("Downloading \(Int(modelProgress * 100))%")
                        .font(.callout)
                }
                .frame(maxWidth: 320)
            case .ready:
                Label("Model installed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed:
                Label("Download failed", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.red)
                Button("Retry") { downloadModel() }
                    .buttonStyle(NPCapsuleButtonStyle(prominent: true))
            }
        case .accessibility:
            explain(
                "Accessibility lets Vortex insert text where your cursor is.",
                "Without it, results are copied to the clipboard instead and Vortex tells you to paste."
            )
            Button(
                accessibilityTrusted ? "Accessibility granted" : "Open Accessibility settings"
            ) {
                requestAccessibility()
            }
            .buttonStyle(NPCapsuleButtonStyle(prominent: !accessibilityTrusted))
            .disabled(accessibilityTrusted)
        case .screen:
            explain(
                "Screen context sends one screenshot of the target window to your chosen cloud model, only when that model supports images and only for cloud Modes.",
                "Nothing is captured in the background and screenshots are never saved. Skip freely - everything else works without it."
            )
            Toggle(
                "Allow sending approved context (app, clipboard, time, screen) to my chosen provider",
                isOn: consentBinding
            )
            Button("Request Screen Recording permission") {
                CGRequestScreenCaptureAccess()
            }
            .buttonStyle(NPCapsuleButtonStyle())
        case .models:
            explain(
                "Optionally connect a cloud provider for AI Modes.",
                "Bring your own key. You can also do this later in the Models tab."
            )
            ModelsView()
                .frame(maxHeight: 300)
        case .shortcuts:
            explain(
                "Global shortcuts start Dictate and Ask anywhere.",
                "Press the shortcut again to stop recording."
            )
            ShortcutRecorderRow(kind: .dictate)
            ShortcutRecorderRow(kind: .ask)
        case .tryDictate:
            explain(
                "Give it a spin.",
                "Click the button, say something, then press Stop on the floating pill. With Default Mode the transcript stays on this Mac."
            )
            Button("Start a test dictation") {
                appState.startAction(.dictate)
            }
            .buttonStyle(NPCapsuleButtonStyle(prominent: true))
        case .complete:
            explain(
                "You're set.",
                "Vortex lives in your menu bar. History opens next; your first dictation is one shortcut away."
            )
        }
    }

    private var controls: some View {
        HStack {
            if step != .welcome, step != .complete {
                Button("Back") {
                    step = OnboardingStep(rawValue: step.rawValue - 1) ?? .welcome
                }
                .buttonStyle(NPCapsuleButtonStyle())
            }
            Spacer()
            if canSkip {
                Button("Skip") { advance() }
                    .buttonStyle(NPCapsuleButtonStyle())
            }
            Button(step == .complete ? "Open Vortex" : "Continue") {
                if step == .complete {
                    appState.completeOnboarding()
                } else {
                    advance()
                }
            }
            .buttonStyle(NPCapsuleButtonStyle(prominent: true))
            .disabled(step == .localModel && modelState == .downloading)
        }
    }

    private var canSkip: Bool {
        switch step {
        case .accessibility, .screen, .models, .tryDictate: true
        default: false
        }
    }

    private var consentBinding: Binding<Bool> {
        Binding(
            get: { (try? appState.store.settings())?.contextConsentGranted ?? false },
            set: { value in
                if let settings = try? appState.store.settings() {
                    settings.contextConsentGranted = value
                    try? appState.store.save()
                }
            }
        )
    }

    private func explain(_ heading: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(heading).font(.body.weight(.medium))
            Text(detail).font(.callout).foregroundStyle(NP.inkSecondary)
        }
        .frame(maxWidth: 460, alignment: .leading)
    }

    private func advance() {
        step = OnboardingStep(rawValue: step.rawValue + 1) ?? .complete
    }

    private func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            Task { @MainActor in microphoneGranted = granted }
        }
    }

    private func requestAccessibility() {
        let options =
            ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        accessibilityTrusted = AXIsProcessTrustedWithOptions(options)
        // Re-check when the user returns from System Settings.
        Task {
            for _ in 0..<30 {
                try? await Task.sleep(for: .seconds(2))
                if AXIsProcessTrusted() {
                    accessibilityTrusted = true
                    break
                }
            }
        }
    }

    private func downloadModel() {
        modelState = .downloading
        modelProgress = 0
        Task {
            do {
                try await appState.transcriber.prepare { fraction in
                    Task { @MainActor in modelProgress = fraction }
                }
                modelState = .ready
            } catch {
                modelState = .failed
            }
        }
    }
}

private struct ShortcutRecorderRow: View {
    enum Kind { case dictate, ask }
    @Environment(AppState.self) private var appState
    let kind: Kind
    @State private var capturing = false
    @State private var display = ""
    @State private var conflict = false

    var body: some View {
        HStack(spacing: 10) {
            Text(kind == .dictate ? "Dictate" : "Ask")
                .frame(width: 60, alignment: .leading)
            Text(display.isEmpty ? current.display : display)
                .font(.callout.monospaced())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(NP.canvasSecondary, in: RoundedRectangle(cornerRadius: 6))
            Button(capturing ? "Press keys…" : "Change") { capture() }
                .buttonStyle(NPCapsuleButtonStyle())
            if conflict {
                Text("That shortcut is taken - try another.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var current: HotkeyManager.Shortcut {
        let settings = try? appState.store.settings()
        let stored = kind == .dictate
            ? settings?.dictateShortcut : settings?.askShortcut
        return stored.flatMap(HotkeyManager.Shortcut.init)
            ?? (kind == .dictate ? .defaultDictate : .defaultAsk)
    }

    private func capture() {
        capturing = true
        conflict = false
        var monitor: Any?
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if let shortcut = HotkeyManager.Shortcut(event: event) {
                apply(shortcut)
            } else {
                conflict = true
            }
            capturing = false
            if let monitor { NSEvent.removeMonitor(monitor) }
            return nil
        }
    }

    private func apply(_ shortcut: HotkeyManager.Shortcut) {
        let id: UInt32 = kind == .dictate ? 1 : 2
        let registered = appState.hotkeys.register(shortcut, id: id) { [weak appState] in
            guard let appState else { return }
            if appState.recorderState == .recording {
                appState.stopAndProcess()
            } else {
                appState.startAction(kind == .dictate ? .dictate : .ask)
            }
        }
        guard registered else {
            conflict = true
            appState.registerHotkeys()
            return
        }
        if let settings = try? appState.store.settings() {
            if kind == .dictate {
                settings.dictateShortcut = shortcut.serialized
            } else {
                settings.askShortcut = shortcut.serialized
            }
            try? appState.store.save()
        }
        display = shortcut.display
    }
}
