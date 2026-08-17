import Foundation

enum TranscriberError: Error {
    case modelNotInstalled
    case downloadFailed
    case transcriptionFailed
}

protocol Transcriber: Sendable {
    /// True when the local model files are already on disk (offline-ready).
    func isModelInstalled() async -> Bool
    /// Downloads (first run) and loads the local model. `progress` receives
    /// 0...1 on an arbitrary thread.
    func prepare(progress: (@Sendable (Double) -> Void)?) async throws
    func transcribe(audioURL: URL) async throws -> String
}
