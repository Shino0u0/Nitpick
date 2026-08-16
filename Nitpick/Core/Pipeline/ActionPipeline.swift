import Foundation

/// Value snapshot of the selected Mode so the pipeline never touches
/// SwiftData objects off the main actor.
struct ModeInput: Sendable {
    var id: UUID?
    var name: String
    var isSystemDefault: Bool
    var instructions: String
    var providerID: ProviderID?
    var modelID: String?

    init(
        id: UUID? = nil,
        name: String,
        isSystemDefault: Bool,
        instructions: String,
        providerID: ProviderID? = nil,
        modelID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.isSystemDefault = isSystemDefault
        self.instructions = instructions
        self.providerID = providerID
        self.modelID = modelID
    }
}

struct PipelineConfig: Sendable {
    var enabledSources: [ContextSource]
    var contextConsent: Bool
    var storedKeyHashes: Set<String>
    var modelSupportsImage: Bool
}

struct PipelineServices: Sendable {
    var recorder: any AudioRecording
    var transcriber: any Transcriber
    var inserter: any TextInserting
    var collector: any ContextCollecting
    var providerClient: @Sendable (ProviderID) -> any CloudProviderClient
    /// Reads the provider key from Keychain at request time; never cached.
    var apiKey: @Sendable (ProviderID) throws -> SecretValue?
}

/// Everything the caller needs to persist a HistoryEntry and update the UI.
/// The pipeline itself never writes to SwiftData.
struct PipelineOutcome: Sendable {
    var status: EntryStatus
    var originalTranscript: String
    var finalOutput: String?
    var insertion: InsertionOutcome?
    var usedContext: [ContextSource]
    var clipboardOmittedReason: String?
    var errorCategory: ErrorCategory?
    var audioURL: URL?
    var duration: TimeInterval?
}

enum PipelineStage: Sendable {
    case transcribing
    case collectingContext
    case enhancing
    case inserting
}

/// SPEC section 13 orchestration: record → transcribe → dictionary →
/// protect → Default insert / custom enhance → restore → insert or answer.
actor ActionPipeline {
    private let services: PipelineServices
    private var recording = false

    init(services: PipelineServices) {
        self.services = services
    }

    // MARK: - Recording control

    func startRecording(
        deviceUID: String?, levelHandler: (@Sendable (Float) -> Void)?
    ) async throws {
        try await services.recorder.start(
            deviceUID: deviceUID, levelHandler: levelHandler
        )
        recording = true
    }

    func cancelRecording() async {
        recording = false
        await services.recorder.cancel()
    }

    /// Stops recording and runs the rest of the pipeline.
    func run(
        action: NitpickAction,
        mode: ModeInput,
        rules: [DictionaryRule],
        config: PipelineConfig,
        target: TargetApp?,
        onStage: (@Sendable (PipelineStage) -> Void)? = nil
    ) async -> PipelineOutcome {
        recording = false
        var audioURL: URL?
        var duration: TimeInterval?
        if let recorded = try? await services.recorder.stop() {
            audioURL = recorded.url
            duration = recorded.duration
        }

        var outcome = PipelineOutcome(
            status: .failed, originalTranscript: "", usedContext: [],
            audioURL: audioURL, duration: duration
        )

        onStage?(.transcribing)
        let rawTranscript: String
        do {
            guard let audioURL else { throw TranscriberError.transcriptionFailed }
            rawTranscript = try await services.transcriber.transcribe(audioURL: audioURL)
        } catch {
            outcome.errorCategory = .transcriptionFailed
            return outcome
        }
        if Task.isCancelled {
            outcome.status = .cancelled
            return outcome
        }

        let localTranscript = DictionaryEngine.apply(
            rules.filter(\.isEnabled), to: rawTranscript
        )
        outcome.originalTranscript = localTranscript

        let usesCloud = !mode.isSystemDefault && mode.providerID != nil
            && mode.modelID != nil

        if action == .ask && !usesCloud {
            outcome.errorCategory = .providerUnavailable
            return outcome
        }

        if !usesCloud {
            onStage?(.inserting)
            outcome.finalOutput = localTranscript
            outcome.insertion = await services.inserter.insert(localTranscript)
            outcome.status = .succeeded
            return outcome
        }

        // Cloud path.
        guard let providerID = mode.providerID, let modelID = mode.modelID else {
            outcome.errorCategory = .providerUnavailable
            return outcome
        }
        guard let apiKey = (try? services.apiKey(providerID)) ?? nil else {
            outcome.errorCategory = .providerInvalidKey
            return outcome
        }

        onStage?(.collectingContext)
        let sources = config.contextConsent ? config.enabledSources : []
        let context = await services.collector.collect(
            target: target,
            sources: sources,
            storedKeyHashes: config.storedKeyHashes,
            includeScreen: config.modelSupportsImage && config.contextConsent
        )
        outcome.usedContext = context.usedSources
        outcome.clipboardOmittedReason = context.clipboardOmittedReason

        let protected = ReplacementProtector.protect(localTranscript, rules: rules)
        let messages = PromptAssembler().assemble(
            instructions: mode.instructions,
            transcript: protected.text,
            context: context,
            hasProtectedValues: !protected.map.isEmpty,
            attachScreenshot: context.screenPNG != nil
        )

        onStage?(.enhancing)
        let response: CompletionResponse
        do {
            response = try await services.providerClient(providerID).complete(
                request: CompletionRequest(modelID: modelID, messages: messages),
                apiKey: apiKey
            )
        } catch let error as ProviderError {
            outcome.errorCategory = Self.category(for: error)
            return outcome
        } catch is CancellationError {
            outcome.status = .cancelled
            return outcome
        } catch {
            outcome.errorCategory = .unknown
            return outcome
        }

        let finalText: String
        switch ReplacementProtector.restore(response.text, map: protected.map) {
        case .success(let restored):
            finalText = restored
        case .failure:
            // Safe fallback: pre-enhancement transcript, flagged so History
            // can explain what happened.
            finalText = localTranscript
            outcome.errorCategory = .placeholderCorrupted
        }

        outcome.finalOutput = finalText
        if action == .dictate {
            onStage?(.inserting)
            outcome.insertion = await services.inserter.insert(finalText)
        }
        outcome.status = .succeeded
        return outcome
    }

    private static func category(for error: ProviderError) -> ErrorCategory {
        switch error {
        case .invalidKey: .providerInvalidKey
        case .rateLimited: .providerRateLimited
        case .http: .providerUnavailable
        case .malformedResponse: .providerUnavailable
        case .transport: .network
        }
    }
}
