import Foundation

/// Wrapper for provider API keys. Exists so a key can never leak through
/// string interpolation, logging, or reflection: both description forms are
/// fixed literals, and raw access is scoped through `withRaw`.
/// Never persisted outside the Keychain.
struct SecretValue: Sendable, Equatable {
    private let raw: String

    init(_ raw: String) {
        self.raw = raw
    }

    var isEmpty: Bool { raw.isEmpty }

    /// Scoped access for building Authorization headers and Keychain data.
    /// Callers must not store the raw value beyond the closure.
    func withRaw<T>(_ body: (String) throws -> T) rethrows -> T {
        try body(raw)
    }
}

extension SecretValue: CustomStringConvertible, CustomDebugStringConvertible {
    var description: String { "SecretValue(redacted)" }
    var debugDescription: String { "SecretValue(redacted)" }
}
