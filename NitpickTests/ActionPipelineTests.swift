import Foundation
import Testing
@testable import Nitpick

// MARK: - Stubs

private struct StubRecorder: AudioRecording {
    var url = URL(filePath: "/tmp/nitpick-stub.wav")
    func start(
        deviceUID: String?, levelHandler: (@Sendable (Float) -> Void)?
    ) async throws {}
    func stop() async throws -> (url: URL, duration: TimeInterval) { (url, 2.5) }
    func cancel() async {}
}

private struct StubTranscriber: Transcriber {
    var text: String
    var fails = false
    func isModelInstalled() async -> Bool { true }
    func prepare(progress: (@Sendable (Double) -> Void)?) async throws {}
    func transcribe(audioURL: URL) async throws -> String {
        if fails { throw TranscriberError.transcriptionFailed }
        return text
    }
}

private final class StubInserter: TextInserting, @unchecked Sendable {
    var inserted: [String] = []
    var outcome: InsertionOutcome = .inserted
    func insert(_ text: String) async -> InsertionOutcome {
        inserted.append(text)
        return outcome
    }
}

private final class StubCollector: ContextCollecting, @unchecked Sendable {
    var snapshot = ContextSnapshot()
    var lastIncludeScreen: Bool?
    var lastSources: [ContextSource]?
    func collect(
        target: TargetApp?, sources: [ContextSource],
        storedKeyHashes: Set<String>, includeScreen: Bool
    ) async -> ContextSnapshot {
        lastIncludeScreen = includeScreen
        lastSources = sources
        return snapshot
    }
}

private final class StubProvider: CloudProviderClient, @unchecked Sendable {
    var transform: @Sendable (String) -> String = { $0 }
    var error: ProviderError?
    var lastRequest: CompletionRequest?
    func validate(apiKey: SecretValue) async throws {}
    func fetchModels(apiKey: SecretValue) async throws -> [CloudModelDescriptor] { [] }
    func complete(
        request: CompletionRequest, apiKey: SecretValue
    ) async throws -> CompletionResponse {
        lastRequest = request
        if let error { throw error }
        let user = request.messages.last?.text ?? ""
        return CompletionResponse(text: transform(user))
    }
}

// MARK: - Helpers

private func makePipeline(
    transcript: String,
    transcriberFails: Bool = false,
    inserter: StubInserter = StubInserter(),
    collector: StubCollector = StubCollector(),
    provider: StubProvider? = nil
) -> ActionPipeline {
    let services = PipelineServices(
        recorder: StubRecorder(),
        transcriber: StubTranscriber(text: transcript, fails: transcriberFails),
        inserter: inserter,
        collector: collector,
        providerClient: { _ in provider ?? StubProvider() },
        apiKey: { _ in provider == nil ? nil : SecretValue("stub-key") }
    )
    return ActionPipeline(services: services)
}

private let defaultMode = ModeInput(
    name: "Default", isSystemDefault: true, instructions: ""
)

private let emailMode = ModeInput(
    name: "Email", isSystemDefault: false,
    instructions: "Rewrite as email.", providerID: .groq, modelID: "llama-x"
)

private func makeConfig(
    sources: [ContextSource] = [], consent: Bool = false,
    supportsImage: Bool = false
) -> PipelineConfig {
    PipelineConfig(
        enabledSources: sources, contextConsent: consent,
        storedKeyHashes: [], modelSupportsImage: supportsImage
    )
}

// MARK: - Tests

struct ActionPipelineTests {
    private let rules = [
        DictionaryRule(phrase: "my email", replacement: "me@example.com"),
        DictionaryRule(phrase: "nit pick", replacement: "Nitpick"),
    ]

    @Test func defaultDictateStaysLocalAndInserts() async {
        let inserter = StubInserter()
        let pipeline = makePipeline(transcript: "send to my email", inserter: inserter)
        let outcome = await pipeline.run(
            action: .dictate, mode: defaultMode, rules: rules,
            config: makeConfig(), target: nil
        )
        #expect(outcome.status == .succeeded)
        #expect(outcome.finalOutput == "send to me@example.com")
        #expect(inserter.inserted == ["send to me@example.com"])
        #expect(outcome.usedContext.isEmpty)
        #expect(outcome.errorCategory == nil)
        #expect(outcome.audioURL != nil)
    }

    @Test func customDictateProtectsLiteralsThroughProvider() async {
        let provider = StubProvider()
        provider.transform = { "Improved: \($0)" }
        let inserter = StubInserter()
        let pipeline = makePipeline(
            transcript: "send to my email", inserter: inserter, provider: provider
        )
        let outcome = await pipeline.run(
            action: .dictate, mode: emailMode, rules: rules,
            config: makeConfig(), target: nil
        )
        #expect(outcome.status == .succeeded)
        // Provider never saw the raw email, only a placeholder.
        let sent = provider.lastRequest?.messages.last?.text ?? ""
        #expect(!sent.contains("me@example.com"))
        #expect(sent.contains("⟦"))
        // Final output restored it exactly.
        #expect(outcome.finalOutput?.contains("me@example.com") == true)
        #expect(inserter.inserted.count == 1)
    }

    @Test func providerFailurePreservesTranscript() async {
        let provider = StubProvider()
        provider.error = .rateLimited
        let pipeline = makePipeline(transcript: "hello nit pick", provider: provider)
        let outcome = await pipeline.run(
            action: .dictate, mode: emailMode, rules: rules,
            config: makeConfig(), target: nil
        )
        #expect(outcome.status == .failed)
        #expect(outcome.errorCategory == .providerRateLimited)
        #expect(outcome.originalTranscript == "hello Nitpick")
        #expect(outcome.finalOutput == nil)
        #expect(outcome.audioURL != nil)
    }

    @Test func mangledPlaceholderFallsBackToLocalTranscript() async {
        let provider = StubProvider()
        provider.transform = { text in
            text.replacingOccurrences(of: "\u{27E6}", with: "[")
        }
        let pipeline = makePipeline(transcript: "send to my email", provider: provider)
        let outcome = await pipeline.run(
            action: .dictate, mode: emailMode, rules: rules,
            config: makeConfig(), target: nil
        )
        #expect(outcome.status == .succeeded)
        #expect(outcome.finalOutput == "send to me@example.com")
        #expect(outcome.errorCategory == .placeholderCorrupted)
    }

    @Test func askWithoutProviderFailsSafely() async {
        let pipeline = makePipeline(transcript: "what time is it")
        let outcome = await pipeline.run(
            action: .ask, mode: defaultMode, rules: [],
            config: makeConfig(), target: nil
        )
        #expect(outcome.status == .failed)
        #expect(outcome.errorCategory == .providerUnavailable)
        #expect(outcome.originalTranscript == "what time is it")
    }

    @Test func askReturnsAnswerWithoutInserting() async {
        let provider = StubProvider()
        provider.transform = { _ in "It is noon." }
        let inserter = StubInserter()
        let pipeline = makePipeline(
            transcript: "what time is it", inserter: inserter, provider: provider
        )
        let outcome = await pipeline.run(
            action: .ask, mode: emailMode, rules: [],
            config: makeConfig(), target: nil
        )
        #expect(outcome.status == .succeeded)
        #expect(outcome.finalOutput == "It is noon.")
        #expect(inserter.inserted.isEmpty)
        #expect(outcome.insertion == nil)
    }

    @Test func screenshotGatedByCapabilityAndConsent() async {
        let collector = StubCollector()
        let pipeline = makePipeline(
            transcript: "t", collector: collector, provider: StubProvider()
        )
        _ = await pipeline.run(
            action: .dictate, mode: emailMode, rules: [],
            config: makeConfig(
                sources: ContextSource.allCases, consent: true, supportsImage: false
            ),
            target: nil
        )
        #expect(collector.lastIncludeScreen == false)

        _ = await pipeline.run(
            action: .dictate, mode: emailMode, rules: [],
            config: makeConfig(
                sources: ContextSource.allCases, consent: true, supportsImage: true
            ),
            target: nil
        )
        #expect(collector.lastIncludeScreen == true)
    }

    @Test func noConsentSendsNoContext() async {
        let collector = StubCollector()
        let pipeline = makePipeline(
            transcript: "t", collector: collector, provider: StubProvider()
        )
        _ = await pipeline.run(
            action: .dictate, mode: emailMode, rules: [],
            config: makeConfig(sources: ContextSource.allCases, consent: false),
            target: nil
        )
        #expect(collector.lastSources?.isEmpty == true)
    }

    @Test func defaultModeNeverCollectsContext() async {
        let collector = StubCollector()
        let pipeline = makePipeline(transcript: "t", collector: collector)
        _ = await pipeline.run(
            action: .dictate, mode: defaultMode, rules: [],
            config: makeConfig(sources: ContextSource.allCases, consent: true),
            target: nil
        )
        #expect(collector.lastSources == nil)
    }

    @Test func transcriptionFailureReportsCategory() async {
        let pipeline = makePipeline(transcript: "", transcriberFails: true)
        let outcome = await pipeline.run(
            action: .dictate, mode: defaultMode, rules: [],
            config: makeConfig(), target: nil
        )
        #expect(outcome.status == .failed)
        #expect(outcome.errorCategory == .transcriptionFailed)
        #expect(outcome.audioURL != nil)
    }
}
