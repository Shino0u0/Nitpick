import Foundation

/// A single deterministic replacement rule from the user's Dictionary.
struct DictionaryRule: Sendable, Equatable {
    var phrase: String
    var replacement: String
    var isEnabled: Bool
    var isCaseSensitive: Bool
    /// User marked the replacement as a literal that must survive cloud
    /// enhancement unchanged (see ReplacementProtector).
    var isProtectedLiteral: Bool

    init(
        phrase: String,
        replacement: String,
        isEnabled: Bool = true,
        isCaseSensitive: Bool = false,
        isProtectedLiteral: Bool = false
    ) {
        self.phrase = phrase
        self.replacement = replacement
        self.isEnabled = isEnabled
        self.isCaseSensitive = isCaseSensitive
        self.isProtectedLiteral = isProtectedLiteral
    }
}

/// Deterministic, local, whole-word longest-match phrase replacement.
///
/// Matching normalizes with Unicode compatibility mapping (NFKC), tokenizes
/// into locale-aware word tokens, and scans left to right choosing the
/// longest complete phrase at each position. Punctuation outside a matched
/// span is preserved; replacements are never rescanned. No fuzzy, phonetic,
/// substring, or edit-distance matching.
enum DictionaryEngine {
    static func apply(_ rules: [DictionaryRule], to text: String) -> String {
        let root = TrieNode(rules: rules)
        guard !root.children.isEmpty, !text.isEmpty else { return text }

        let tokens = tokenize(text)
        var output = ""
        var cursor = text.startIndex
        var i = 0
        while i < tokens.count {
            var node = root
            var best: (endToken: Int, replacement: String)?
            var j = i
            while j < tokens.count, let next = node.children[tokens[j].folded] {
                node = next
                if let match = node.completions.first(where: { completion in
                    !completion.caseSensitive
                        || exactTokens(tokens[i...j]) == completion.exactPhraseTokens
                }) {
                    best = (j, match.replacement)
                }
                j += 1
            }
            if let best {
                output += text[cursor..<tokens[i].range.lowerBound]
                output += best.replacement
                cursor = tokens[best.endToken].range.upperBound
                i = best.endToken + 1
            } else {
                i += 1
            }
        }
        output += text[cursor...]
        return output
    }

    // MARK: - Tokenization

    private struct Token {
        var range: Range<String.Index>
        /// NFKC-normalized, case-folded form used for trie lookup.
        var folded: String
        /// NFKC-normalized form used for case-sensitive verification.
        var exact: String
    }

    private static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        text.enumerateSubstrings(
            in: text.startIndex..., options: [.byWords, .localized]
        ) { substring, range, _, _ in
            guard let substring else { return }
            let exact = substring.precomposedStringWithCompatibilityMapping
            tokens.append(Token(range: range, folded: exact.lowercased(), exact: exact))
        }
        return tokens
    }

    private static func exactTokens(_ slice: ArraySlice<Token>) -> [String] {
        slice.map(\.exact)
    }

    // MARK: - Trie

    private final class TrieNode {
        struct Completion {
            var replacement: String
            var caseSensitive: Bool
            var exactPhraseTokens: [String]
        }

        var children: [String: TrieNode] = [:]
        var completions: [Completion] = []

        init() {}

        convenience init(rules: [DictionaryRule]) {
            self.init()
            for rule in rules where rule.isEnabled {
                let phraseTokens = DictionaryEngine.tokenize(rule.phrase)
                guard !phraseTokens.isEmpty else { continue }
                var node = self
                for token in phraseTokens {
                    if let child = node.children[token.folded] {
                        node = child
                    } else {
                        let child = TrieNode()
                        node.children[token.folded] = child
                        node = child
                    }
                }
                node.completions.append(
                    Completion(
                        replacement: rule.replacement,
                        caseSensitive: rule.isCaseSensitive,
                        exactPhraseTokens: phraseTokens.map(\.exact)
                    )
                )
            }
        }
    }
}
