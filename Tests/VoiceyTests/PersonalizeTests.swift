import XCTest
@testable import Voicey

final class DictionaryListTests: XCTestCase {
    func testParseSplitsOnLinesAndOptionallyCommas() {
        XCTAssertEqual(DictionaryList.parse("Alpha, Beta\nGamma ,, \n  Delta  ", splitOnCommas: true), ["Alpha", "Beta", "Gamma", "Delta"])
        XCTAssertEqual(DictionaryList.parse("Smith, John\nAcme", splitOnCommas: false), ["Smith, John", "Acme"])
    }

    func testMergeSkipsDuplicatesIgnoringCase() {
        let r = DictionaryList.merged(["Alpha"], adding: "beta, ALPHA, Gamma")
        XCTAssertEqual(r.list, ["Alpha", "beta", "Gamma"])
        XCTAssertEqual(r.skipped, 1)
        XCTAssertEqual(DictionaryList.merged([], adding: "  ").list, [])
    }

    func testFitCountStopsAtTheWhisperBudget() {
        XCTAssertEqual(DictionaryList.fitCount(["one", "two", "three"]), 3)
        let long = (0..<100).map { _ in String(repeating: "x", count: 18) }     // 20 characters each once joined
        XCTAssertEqual(DictionaryList.fitCount(long, budget: 600), 30)
        XCTAssertEqual(DictionaryList.fitCount([]), 0)
    }

    func testFilterKeepsOriginalPositionsAndIgnoresCaseAndAccents() {
        let terms = ["Alpha", "Beta", "Café Noir", "alphabet", "Gamma"]
        XCTAssertEqual(DictionaryList.filtered(terms, query: "ALPHA").map(\.index), [0, 3])
        XCTAssertEqual(DictionaryList.filtered(terms, query: "cafe").map(\.term), ["Café Noir"])
        XCTAssertEqual(DictionaryList.filtered(terms, query: "  ").count, 5)
        XCTAssertTrue(DictionaryList.filtered(terms, query: "zzz").isEmpty)
    }
}

final class SnippetTests: XCTestCase {
    private var saved: [Snippet] = []
    override func setUp() {
        saved = Personalization.shared.snippets
        Personalization.shared.snippets = [Snippet(trigger: "my address", text: "42 Wallaby Way, Sydney"),
                                           Snippet(trigger: "my signature", text: "Best regards,\nA")]
    }
    override func tearDown() { Personalization.shared.snippets = saved }

    func testOnlyATriggerIsExpandedWithoutNeedingPolish() {
        let p = Personalization.shared.protect("My address.")
        XCTAssertTrue(p.onlySnippets)
        XCTAssertEqual(Personalization.shared.expand(p.text, p), "42 Wallaby Way, Sydney")
    }

    func testTriggerInsideASentenceIsProtectedThenExpanded() {
        let p = Personalization.shared.protect("Please send it to my address, thanks.")
        XCTAssertFalse(p.onlySnippets)
        XCTAssertTrue(p.text.contains("[[SNIPPET1]]"))
        XCTAssertEqual(Personalization.shared.expand("Please send it to [[SNIPPET1]], thanks.", p), "Please send it to 42 Wallaby Way, Sydney, thanks.")
    }

    func testTextWithoutTriggersIsUntouched() {
        let p = Personalization.shared.protect("nothing special here")
        XCTAssertTrue(p.tokens.isEmpty)
        XCTAssertEqual(p.text, "nothing special here")
    }
}

final class ToneTests: XCTestCase {
    func testEveryPresetHasAPromptExceptCustom() {
        for preset in TonePreset.all where preset.id != "custom" { XCTAssertFalse(preset.prompt.isEmpty, preset.id) }
    }

    func testCustomToneUsesTheUsersText() {
        XCTAssertEqual(TonePreset.prompt(for: AppTone(bundleID: "x", name: "X", tone: "custom", custom: "  warm but brief ")), "warm but brief")
    }
}
