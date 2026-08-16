import CryptoKit
import Foundation

/// Decides whether a clipboard snapshot is safe to include as cloud context.
/// Never sees raw stored provider keys: callers pass `hash(_:)` digests.
enum SecretGuard {
    /// Conservative clipboard context limit, in characters.
    static let maxLength = 8000

    enum OmissionReason: Equatable, Sendable {
        case matchesStoredKey
        case privateKeyMaterial
        case credentialLike
        case keyEditorSource
    }

    enum Verdict: Equatable, Sendable {
        case allowed(String, truncated: Bool)
        case omitted(reason: OmissionReason)
    }

    static func evaluate(
        _ text: String,
        storedKeyHashes: Set<String> = [],
        sourceIsKeyEditor: Bool = false
    ) -> Verdict {
        if sourceIsKeyEditor {
            return .omitted(reason: .keyEditorSource)
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if storedKeyHashes.contains(hash(trimmed)) {
            return .omitted(reason: .matchesStoredKey)
        }
        if trimmed.contains("-----BEGIN"), trimmed.contains("PRIVATE KEY") {
            return .omitted(reason: .privateKeyMaterial)
        }
        if isCredentialLikeToken(trimmed) {
            return .omitted(reason: .credentialLike)
        }
        if text.count > maxLength {
            return .allowed(String(text.prefix(maxLength)), truncated: true)
        }
        return .allowed(text, truncated: false)
    }

    /// SHA-256 hex digest used to compare clipboard text against stored
    /// provider keys without keeping the keys in memory.
    static func hash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Heuristics

    private static let knownKeyPrefixes = [
        "sk-", "gsk_", "pk_", "api-", "key-", "ghp_", "gho_", "xox", "bearer ",
    ]

    /// A single whitespace-free token that is long and either carries a known
    /// key prefix or looks random (high entropy across a diverse charset).
    private static func isCredentialLikeToken(_ trimmed: String) -> Bool {
        guard trimmed.count >= 20, !trimmed.contains(where: \.isWhitespace) else {
            // "bearer <token>" is two words; check it before bailing on spaces.
            return trimmed.lowercased().hasPrefix("bearer ")
                && !trimmed.dropFirst(7).contains(where: \.isWhitespace)
        }
        let lowered = trimmed.lowercased()
        if knownKeyPrefixes.contains(where: lowered.hasPrefix) {
            return true
        }
        let hasUpper = trimmed.contains(where: \.isUppercase)
        let hasLower = trimmed.contains(where: \.isLowercase)
        let hasDigit = trimmed.contains(where: \.isNumber)
        let diverse = [hasUpper, hasLower, hasDigit].filter { $0 }.count >= 2
        return diverse && shannonEntropy(trimmed) >= 4.0
    }

    private static func shannonEntropy(_ value: String) -> Double {
        let counts = value.reduce(into: [Character: Int]()) { $0[$1, default: 0] += 1 }
        let total = Double(value.count)
        return counts.values.reduce(0) { entropy, count in
            let p = Double(count) / total
            return entropy - p * log2(p)
        }
    }
}
