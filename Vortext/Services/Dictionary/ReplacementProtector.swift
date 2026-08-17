import Foundation

enum ProtectionError: Error, Equatable {
    /// The model dropped or altered a placeholder; the caller must fall back
    /// to the pre-enhancement transcript.
    case corrupted
}

/// Opaque token standing in for a protected replacement value while text is
/// with a cloud model.
struct Placeholder: Hashable, Sendable {
    let token: String
}

/// Shields dictionary replacement values that must survive cloud enhancement
/// byte-for-byte: email addresses, URLs, handles, identifier-like strings,
/// and user-marked literals. Values are swapped for unique placeholders
/// before the provider request and restored exactly afterwards.
enum ReplacementProtector {
    /// The delimiters are rare enough that residue after restoration is
    /// treated as corruption rather than legitimate output.
    private static let open = "\u{27E6}"   // ⟦
    private static let close = "\u{27E7}"  // ⟧

    static func protect(
        _ text: String,
        rules: [DictionaryRule]
    ) -> (text: String, map: [Placeholder: String]) {
        var result = text
        var map: [Placeholder: String] = [:]
        for rule in rules where rule.isEnabled && isProtectable(rule) {
            guard result.contains(rule.replacement) else { continue }
            let placeholder = Placeholder(token: "\(open)NP-\(randomHex())\(close)")
            result = result.replacingOccurrences(of: rule.replacement, with: placeholder.token)
            map[placeholder] = rule.replacement
        }
        return (result, map)
    }

    static func restore(
        _ text: String,
        map: [Placeholder: String]
    ) -> Result<String, ProtectionError> {
        var result = text
        for (placeholder, value) in map {
            guard result.contains(placeholder.token) else { return .failure(.corrupted) }
            result = result.replacingOccurrences(of: placeholder.token, with: value)
        }
        guard !result.contains(open), !result.contains(close) else {
            return .failure(.corrupted)
        }
        return .success(result)
    }

    // MARK: - Heuristics

    private static func isProtectable(_ rule: DictionaryRule) -> Bool {
        if rule.isProtectedLiteral { return true }
        let value = rule.replacement
        if looksLikeEmail(value) || looksLikeURL(value) || looksLikeHandle(value) {
            return true
        }
        return looksLikeIdentifier(value)
    }

    private static func looksLikeEmail(_ value: String) -> Bool {
        value.wholeMatch(of: /[^@\s]+@[^@\s]+\.[^@\s]+/) != nil
    }

    private static func looksLikeURL(_ value: String) -> Bool {
        value.contains("://") || value.hasPrefix("www.")
    }

    private static func looksLikeHandle(_ value: String) -> Bool {
        value.hasPrefix("@") && !value.contains(" ")
    }

    /// Code-ish tokens: no whitespace, mixes letters with digits or
    /// separator punctuation, long enough not to be a word.
    private static func looksLikeIdentifier(_ value: String) -> Bool {
        guard value.count >= 6, !value.contains(where: \.isWhitespace) else { return false }
        let hasLetter = value.contains(where: \.isLetter)
        let hasDigitOrSeparator = value.contains {
            $0.isNumber || $0 == "-" || $0 == "_" || $0 == "." || $0 == ":"
        }
        return hasLetter && hasDigitOrSeparator
    }

    private static func randomHex() -> String {
        String(format: "%08X", UInt32.random(in: .min ... .max))
    }
}
