import Testing
@testable import Nitpick

struct DictionaryEngineTests {
    private func rule(
        _ phrase: String,
        _ replacement: String,
        enabled: Bool = true,
        caseSensitive: Bool = false
    ) -> DictionaryRule {
        DictionaryRule(
            phrase: phrase,
            replacement: replacement,
            isEnabled: enabled,
            isCaseSensitive: caseSensitive
        )
    }

    @Test func replacesSingleWord() {
        let out = DictionaryEngine.apply([rule("teh", "the")], to: "teh cat")
        #expect(out == "the cat")
    }

    @Test func replacesMultiWordPhrase() {
        let out = DictionaryEngine.apply(
            [rule("nit pick", "Nitpick")],
            to: "I use nit pick daily"
        )
        #expect(out == "I use Nitpick daily")
    }

    @Test func longestMatchWins() {
        let rules = [
            rule("my email", "WRONG"),
            rule("my email address", "myemail@personemail.com"),
        ]
        let out = DictionaryEngine.apply(rules, to: "send it to my email address please")
        #expect(out == "send it to myemail@personemail.com please")
    }

    @Test func shorterPhraseStillMatchesElsewhere() {
        let rules = [
            rule("my email", "myemail@personemail.com"),
            rule("my email address", "ADDR"),
        ]
        let out = DictionaryEngine.apply(rules, to: "my email is old")
        #expect(out == "myemail@personemail.com is old")
    }

    @Test func neverMatchesInsideWord() {
        let out = DictionaryEngine.apply([rule("art", "ART")], to: "partial art class")
        #expect(out == "partial ART class")
    }

    @Test func preservesPunctuationAroundMatch() {
        let out = DictionaryEngine.apply(
            [rule("nit pick", "Nitpick")],
            to: "Have you tried nit pick? It's great."
        )
        #expect(out == "Have you tried Nitpick? It's great.")
    }

    @Test func caseInsensitiveByDefault() {
        let out = DictionaryEngine.apply([rule("nit pick", "Nitpick")], to: "Nit Pick rocks")
        #expect(out == "Nitpick rocks")
    }

    @Test func caseSensitiveWhenFlagged() {
        let r = rule("API", "Application Programming Interface", caseSensitive: true)
        #expect(DictionaryEngine.apply([r], to: "the api is down") == "the api is down")
        #expect(
            DictionaryEngine.apply([r], to: "the API is down")
                == "the Application Programming Interface is down"
        )
    }

    @Test func disabledRuleIgnored() {
        let out = DictionaryEngine.apply([rule("teh", "the", enabled: false)], to: "teh cat")
        #expect(out == "teh cat")
    }

    @Test func unicodeCompatibilityNormalization() {
        // Full-width "ｅｍａｉｌ" should match a plain "email" phrase.
        let out = DictionaryEngine.apply(
            [rule("my email", "myemail@personemail.com")],
            to: "my ｅｍａｉｌ please"
        )
        #expect(out == "myemail@personemail.com please")
    }

    @Test func repeatedWhitespaceInPhraseAndText() {
        let out = DictionaryEngine.apply(
            [rule("nit  pick", "Nitpick")],
            to: "nit   pick is here"
        )
        #expect(out == "Nitpick is here")
    }

    @Test func consecutiveMatches() {
        let out = DictionaryEngine.apply(
            [rule("foo", "X"), rule("bar", "Y")],
            to: "foo bar"
        )
        #expect(out == "X Y")
    }

    @Test func replacementNotRescanned() {
        // A replacement value must not itself be replaced by another rule.
        let out = DictionaryEngine.apply(
            [rule("a", "b"), rule("b", "c")],
            to: "a b"
        )
        #expect(out == "b c")
    }

    @Test func emptyInputsAreSafe() {
        #expect(DictionaryEngine.apply([], to: "hello") == "hello")
        #expect(DictionaryEngine.apply([rule("a", "b")], to: "") == "")
    }
}
