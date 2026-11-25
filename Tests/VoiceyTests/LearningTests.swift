import XCTest
@testable import Voicey

final class LearningTests: XCTestCase {
    /// Stand-in for the system spell checker: only ordinary lowercase English words are "known".
    private let common: Set<String> = ["we", "should", "move", "the", "meeting", "to", "with", "and", "send", "report", "can", "you",
                                       "thanks", "before", "then", "call", "today", "okay", "team", "dear", "please", "check", "it"]
    private func known(_ w: String) -> Bool { common.contains(w) }
    private func terms(_ s: String) -> [String] { TermMiner.candidates(in: s, isKnown: known) }

    func testFindsNamesAcronymsAndCamelCase() {
        XCTAssertEqual(terms("We should move the meeting with Marcus and Priya."), ["Marcus", "Priya"])
        XCTAssertEqual(terms("Send it to the AWS team and check GitHub and the iPhone app."), ["AWS", "GitHub", "iPhone"])
        XCTAssertEqual(terms("Deploy to k8s and S3 today."), ["k8s", "S3"])
    }
    func testKeepsMultiWordNamesTogether() {
        XCTAssertEqual(terms("Please call Acme Corp today."), ["Acme Corp"])
    }
    func testIgnoresSentenceStartsDaysAndOrdinaryWords() {
        XCTAssertEqual(terms("Thanks. Send the report on Friday. I think we should go."), [])
        XCTAssertEqual(terms("Can you check it? Okay."), [])
    }
    func testNoRepeats() {
        XCTAssertEqual(terms("Ask Marcus. Then tell Marcus again."), ["Marcus"])
    }
    func testLooksLikeTerm() {
        XCTAssertTrue(TermMiner.looksLikeTerm("Kubernetes", isKnown: known))
        XCTAssertTrue(TermMiner.looksLikeTerm("kubectl", isKnown: known))      // not an ordinary word
        XCTAssertFalse(TermMiner.looksLikeTerm("meeting", isKnown: known))
    }

    // Corrections
    func testFindsASwapInAnEditedText() {
        let r = CorrectionDiff.replacements(original: "we should deploy it on cooper nettys today", edited: "we should deploy it on Kubernetes today")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.from, "cooper nettys")
        XCTAssertEqual(r.first?.to, "Kubernetes")
    }
    func testCaseOnlyFixCounts() {
        let r = CorrectionDiff.replacements(original: "send it to marcus before friday", edited: "send it to Marcus before friday")
        XCTAssertEqual(r.first?.to, "Marcus")
    }
    func testRewritesAreNotCorrections() {
        XCTAssertTrue(CorrectionDiff.replacements(original: "move the meeting to friday because marcus is out", edited: "Friday works better since everyone else can attend").isEmpty)
    }
    func testNoChangeNoPairs() {
        XCTAssertTrue(CorrectionDiff.replacements(original: "move the meeting today", edited: "move the meeting today").isEmpty)
    }
    func testFindsThePastedPartInsideALongerField() {
        let pasted = "we should deploy it on cooper nettys today for everyone"
        let field = "Hi team.\nwe should deploy it on Kubernetes today for everyone\nThanks"
        XCTAssertEqual(CorrectionDiff.segment(in: field, pasted: pasted), "we should deploy it on Kubernetes today for everyone")
        XCTAssertEqual(CorrectionDiff.segment(in: "x " + pasted + " y", pasted: pasted), pasted)
        XCTAssertNil(CorrectionDiff.segment(in: "something else entirely", pasted: pasted))
    }

    // Tones
    func testToneNeedsEnoughDictations() {
        XCTAssertNil(ToneGuesser.suggestion(bundleID: "com.apple.mail", dictations: 4, casual: 0, formal: 5))
    }
    func testToneFromAppKindAndFromHabit() {
        XCTAssertEqual(ToneGuesser.suggestion(bundleID: "com.apple.mail", dictations: 6, casual: 0, formal: 0)?.tone, "formal")
        XCTAssertEqual(ToneGuesser.suggestion(bundleID: "com.apple.Terminal", dictations: 6, casual: 0, formal: 0)?.tone, "technical")
        XCTAssertEqual(ToneGuesser.suggestion(bundleID: "com.example.unknown", dictations: 6, casual: 5, formal: 0)?.tone, "casual")
        XCTAssertEqual(ToneGuesser.suggestion(bundleID: "com.tinyspeck.slackmacgap", dictations: 6, casual: 0, formal: 3)?.tone, "formal")   // habit beats the app's reputation
        XCTAssertNil(ToneGuesser.suggestion(bundleID: "com.example.unknown", dictations: 9, casual: 1, formal: 1))
    }
    func testMarkers() {
        let m = ToneGuesser.markers(in: "hey yeah I'm gonna send it, dear Sam, kindly check")
        XCTAssertEqual(m.casual, 3)
        XCTAssertEqual(m.formal, 2)
    }

    // Skipping the AI
    func testSkipAIOnlyForShortCleanText() {
        UserDefaults.standard.set(true, forKey: Prefs.skipShortAI)
        UserDefaults.standard.removeObject(forKey: Prefs.extra)
        XCTAssertTrue(TextPolisher.canSkipAI("Send the report today.", tone: nil))
        XCTAssertFalse(TextPolisher.canSkipAI("Um, send the report today.", tone: nil))              // filler
        XCTAssertFalse(TextPolisher.canSkipAI("send the report today", tone: nil))                    // not punctuated
        XCTAssertFalse(TextPolisher.canSkipAI("Send the report today.", tone: "Formal."))             // needs the AI
        XCTAssertFalse(TextPolisher.canSkipAI("Send it. Then call me.", tone: nil))                   // more than one sentence
        XCTAssertFalse(TextPolisher.canSkipAI("One two three four five six seven eight nine ten eleven.", tone: nil))
        UserDefaults.standard.set("Always sign off.", forKey: Prefs.extra)
        XCTAssertFalse(TextPolisher.canSkipAI("Send the report today.", tone: nil))                   // your rules need the AI
        UserDefaults.standard.removeObject(forKey: Prefs.extra)
        UserDefaults.standard.set(false, forKey: Prefs.skipShortAI)
        XCTAssertFalse(TextPolisher.canSkipAI("Send the report today.", tone: nil))                   // switched off
        UserDefaults.standard.removeObject(forKey: Prefs.skipShortAI)
    }
}
