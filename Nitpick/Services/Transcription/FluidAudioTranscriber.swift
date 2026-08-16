import FluidAudio
import Foundation

/// Local Parakeet transcription via FluidAudio. The model downloads once
/// from HuggingFace during `prepare()` and works offline afterwards.
actor FluidAudioTranscriber: Transcriber {
    private var manager: AsrManager?

    func isModelInstalled() async -> Bool {
        AsrModels.modelsExist(at: AsrModels.defaultCacheDirectory(for: .v3))
    }

    func prepare(progress: (@Sendable (Double) -> Void)?) async throws {
        guard manager == nil else { return }
        do {
            let models = try await AsrModels.downloadAndLoad(version: .v3) {
                progress?($0.fractionCompleted)
            }
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            self.manager = manager
        } catch {
            throw TranscriberError.downloadFailed
        }
    }

    func transcribe(audioURL: URL) async throws -> String {
        try await prepare(progress: nil)
        guard let manager else { throw TranscriberError.modelNotInstalled }
        do {
            var decoderState = try TdtDecoderState()
            let result = try await manager.transcribe(
                audioURL, decoderState: &decoderState
            )
            return result.text
        } catch {
            throw TranscriberError.transcriptionFailed
        }
    }
}
