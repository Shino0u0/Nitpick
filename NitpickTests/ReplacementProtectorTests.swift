import Testing
@testable import Nitpick

struct ReplacementProtectorTests {
    private let emailRule = DictionaryRule(
        phrase: "my email", replacement: "myemail@personemail.com"
    )
    private let urlRule = DictionaryRule(
        phrase: "my site", replacement: "https://example.com/a?b=1"
    )
    private let plainRule = DictionaryRule(
        phrase: "teh", replacement: "the"
    )
    private let literalRule = DictionaryRule(
        phrase: "the code", replacement: "XK-42-ALPHA", isProtectedLiteral: true
    )

    @Test func protectsEmailAndRestoresRoundTrip() {
        let text = "send to myemail@personemail.com today"
        let protected = ReplacementProtector.protect(text, rules: [emailRule])
        #expect(!protected.text.contains("myemail@personemail.com"))
        #expect(protected.map.count == 1)

        let restored = ReplacementProtector.restore(protected.text, map: protected.map)
        #expect(try! restored.get() == text)
    }

    @Test func protectsURL() {
        let text = "visit https://example.com/a?b=1 now"
        let protected = ReplacementProtector.protect(text, rules: [urlRule])
        #expect(!protected.text.contains("https://example.com/a?b=1"))
    }

    @Test func protectsUserMarkedLiteral() {
        let text = "use XK-42-ALPHA here"
        let protected = ReplacementProtector.protect(text, rules: [literalRule])
        #expect(!protected.text.contains("XK-42-ALPHA"))
    }

    @Test func plainWordReplacementNotProtected() {
        let text = "the cat"
        let protected = ReplacementProtector.protect(text, rules: [plainRule])
        #expect(protected.text == text)
        #expect(protected.map.isEmpty)
    }

    @Test func valueAbsentFromTextProtectsNothing() {
        let protected = ReplacementProtector.protect("no match here", rules: [emailRule])
        #expect(protected.text == "no match here")
        #expect(protected.map.isEmpty)
    }

    @Test func multipleOccurrencesAllProtected() {
        let text = "a myemail@personemail.com b myemail@personemail.com"
        let protected = ReplacementProtector.protect(text, rules: [emailRule])
        #expect(!protected.text.contains("myemail@personemail.com"))
        let restored = try! ReplacementProtector.restore(
            protected.text, map: protected.map
        ).get()
        #expect(restored == text)
    }

    @Test func restoreSurvivesSurroundingModelEdits() {
        let protected = ReplacementProtector.protect(
            "email myemail@personemail.com ok", rules: [emailRule]
        )
        let placeholder = protected.map.keys.first!
        let modelOutput = "Please email \(placeholder.token) at your convenience."
        let restored = try! ReplacementProtector.restore(modelOutput, map: protected.map).get()
        #expect(restored == "Please email myemail@personemail.com at your convenience.")
    }

    @Test func missingPlaceholderIsCorruption() {
        let protected = ReplacementProtector.protect(
            "send to myemail@personemail.com", rules: [emailRule]
        )
        let restored = ReplacementProtector.restore("model dropped it", map: protected.map)
        #expect(throws: ProtectionError.corrupted) { try restored.get() }
    }

    @Test func mangledPlaceholderIsCorruption() {
        let protected = ReplacementProtector.protect(
            "send to myemail@personemail.com", rules: [emailRule]
        )
        let token = protected.map.keys.first!.token
        let mangled = String(token.dropLast(2)) + "XX"
        let restored = ReplacementProtector.restore("send to \(mangled)", map: protected.map)
        #expect(throws: ProtectionError.corrupted) { try restored.get() }
    }

    @Test func emptyMapRestoreIsIdentity() {
        let restored = ReplacementProtector.restore("plain text", map: [:])
        #expect(try! restored.get() == "plain text")
    }
}
