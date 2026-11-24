import XCTest
@testable import Voicey

final class SilenceTests: XCTestCase {
    private func firstStop(_ pause: Double, talk: ClosedRange<Double>?, seconds: Double = 30) -> Double? {
        var w = SilenceWatcher(pause: pause)
        var t = 0.0
        while t < seconds {
            let loud = talk.map { $0.contains(t) } ?? false
            if w.feed(level: loud ? 0.6 : 0.02, at: t) { return t }
            t += 0.04
        }
        return nil
    }

    func testStopsAfterPauseFollowingSpeech() {
        let t = try! XCTUnwrap(firstStop(3, talk: 1...4))
        XCTAssertEqual(t, 7.0, accuracy: 0.1)
    }
    func testKeepsGoingWhileTalking() {
        XCTAssertNil(firstStop(3, talk: 0...30, seconds: 30))
    }
    func testShortBreathsBetweenWordsDoNotStop() {
        var w = SilenceWatcher(pause: 3)
        var t = 0.0
        while t < 20 {
            let loud = Int(t * 2) % 2 == 0          // talk 0.5 s, pause 0.5 s
            XCTAssertFalse(w.feed(level: loud ? 0.6 : 0.02, at: t)); t += 0.04
        }
    }
    func testNothingSaidStopsAfterEightSeconds() {
        let t = try! XCTUnwrap(firstStop(3, talk: nil))
        XCTAssertEqual(t, 8.0, accuracy: 0.1)
    }
    func testOffNeverStops() {
        XCTAssertNil(firstStop(0, talk: 1...2))
    }
    func testFiresOnlyOnce() {
        var w = SilenceWatcher(pause: 2)
        var count = 0
        var t = 0.0
        while t < 20 { if w.feed(level: t < 1 ? 0.6 : 0.0, at: t) { count += 1 }; t += 0.04 }
        XCTAssertEqual(count, 1)
    }
}
