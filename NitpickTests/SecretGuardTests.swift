import Testing
@testable import Nitpick

struct SecretGuardTests {
    @Test func allowsOrdinaryText() {
        let verdict = SecretGuard.evaluate("meeting notes from Tuesday about the launch")
        #expect(verdict == .allowed("meeting notes from Tuesday about the launch", truncated: false))
    }

    @Test func omitsStoredProviderKeyExactMatch() {
        let key = "gsk_live_abcdef1234567890abcdef1234567890"
        let verdict = SecretGuard.evaluate(key, storedKeyHashes: [SecretGuard.hash(key)])
        #expect(verdict == .omitted(reason: .matchesStoredKey))
    }

    @Test func omitsPrivateKeyHeader() {
        let pem = "-----BEGIN RSA PRIVATE KEY-----\nMIIEow...\n-----END RSA PRIVATE KEY-----"
        #expect(SecretGuard.evaluate(pem) == .omitted(reason: .privateKeyMaterial))
    }

    @Test func omitsKnownKeyPrefixToken() {
        #expect(
            SecretGuard.evaluate("sk-or-v1-9f8e7d6c5b4a39281706f5e4d3c2b1a0")
                == .omitted(reason: .credentialLike)
        )
    }

    @Test func omitsHighEntropySingleToken() {
        #expect(
            SecretGuard.evaluate("q9Zx7Kp2Vm4Rt8Wn3Yb6Hd1Fg5Js0Lc")
                == .omitted(reason: .credentialLike)
        )
    }

    @Test func allowsNormalSentenceContainingLongWord() {
        let text = "the word pneumonoultramicroscopicsilicovolcanoconiosis is long"
        #expect(SecretGuard.evaluate(text) == .allowed(text, truncated: false))
    }

    @Test func allowsShortToken() {
        #expect(SecretGuard.evaluate("hello") == .allowed("hello", truncated: false))
    }

    @Test func truncatesOverLimit() {
        let long = String(repeating: "word ", count: 3000)
        guard case let .allowed(text, truncated) = SecretGuard.evaluate(long) else {
            Issue.record("expected allowed")
            return
        }
        #expect(truncated)
        #expect(text.count == SecretGuard.maxLength)
    }

    @Test func keyEditorSourceAlwaysOmitted() {
        let verdict = SecretGuard.evaluate("anything at all", sourceIsKeyEditor: true)
        #expect(verdict == .omitted(reason: .keyEditorSource))
    }

    @Test func hashIsStableAndNotIdentity() {
        let key = "gsk_live_abcdef"
        #expect(SecretGuard.hash(key) == SecretGuard.hash(key))
        #expect(SecretGuard.hash(key) != key)
    }
}
