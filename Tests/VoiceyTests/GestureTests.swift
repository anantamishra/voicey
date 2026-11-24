import XCTest
@testable import Voicey

final class GestureTests: XCTestCase {
    private let t0 = Date()
    private func at(_ s: Double) -> Date { t0.addingTimeInterval(s) }

    func testHoldTalksWhileHeldAndStopsAfterGrace() {
        var m = GestureMachine()
        XCTAssertEqual(m.press(at: at(0), recording: false), .start)
        XCTAssertEqual(m.release(at: at(1.0)), .scheduleGrace)
        XCTAssertEqual(m.graceExpired(), .stop)
    }

    func testSinglePressStartsAndLaterPressStops() {
        var m = GestureMachine()
        XCTAssertEqual(m.press(at: at(0), recording: false), .start)
        XCTAssertEqual(m.release(at: at(0.1)), .none)
        XCTAssertEqual(m.press(at: at(2.0), recording: true), .stop)
        XCTAssertEqual(m.release(at: at(2.1)), .none)
    }

    func testDoubleTapLocksUntilNextPress() {
        var m = GestureMachine()
        XCTAssertEqual(m.press(at: at(0), recording: false), .start)
        XCTAssertEqual(m.release(at: at(0.1)), .none)
        XCTAssertEqual(m.press(at: at(0.3), recording: true), .lock)
        XCTAssertEqual(m.release(at: at(0.4)), .none)
        XCTAssertEqual(m.press(at: at(5), recording: true), .stop)
        XCTAssertEqual(m.release(at: at(5.1)), .none)
    }

    func testHoldReleaseThenQuickPressLocks() {
        var m = GestureMachine()
        XCTAssertEqual(m.press(at: at(0), recording: false), .start)
        XCTAssertEqual(m.release(at: at(1.0)), .scheduleGrace)
        XCTAssertEqual(m.press(at: at(1.2), recording: true), .lock)
        XCTAssertEqual(m.release(at: at(1.3)), .none)
        XCTAssertEqual(m.graceExpired(), .none, "the grace timer must not stop a locked recording")
        XCTAssertEqual(m.press(at: at(9), recording: true), .stop)
    }

    func testRecordingStartedFromTheMenuCanBeStoppedWithTheKey() {
        var m = GestureMachine()
        XCTAssertEqual(m.press(at: at(0), recording: true), .stop)
        XCTAssertEqual(m.release(at: at(0.1)), .none)
    }

    func testNewDictationWorksAfterALockedOne() {
        var m = GestureMachine()
        _ = m.press(at: at(0), recording: false); _ = m.release(at: at(0.1))
        _ = m.press(at: at(0.3), recording: true); _ = m.release(at: at(0.35))
        _ = m.press(at: at(4), recording: true); _ = m.release(at: at(4.1))
        XCTAssertEqual(m.press(at: at(10), recording: false), .start)
        XCTAssertEqual(m.release(at: at(11)), .scheduleGrace)
        XCTAssertEqual(m.graceExpired(), .stop)
    }
}

final class ModifierKeyTrackerTests: XCTestCase {
    private let t0 = Date()
    private func at(_ s: Double) -> Date { t0.addingTimeInterval(s) }

    func testPressThenRelease() {
        var t = ModifierKeyTracker()
        XCTAssertEqual(t.flagsChanged(isDown: true, at: at(0)), .press)
        XCTAssertEqual(t.flagsChanged(isDown: false, at: at(1)), .release)
    }

    func testUsedAsPartOfAnotherShortcutAbortsAndSwallowsTheRelease() {
        var t = ModifierKeyTracker()
        XCTAssertEqual(t.flagsChanged(isDown: true, at: at(0)), .press)
        XCTAssertEqual(t.keyDown(at: at(0.2)), .abort)
        XCTAssertEqual(t.flagsChanged(isDown: false, at: at(0.4)), .none)
    }

    func testAKeyTypedLateWhileTalkingDoesNotAbort() {
        var t = ModifierKeyTracker()
        _ = t.flagsChanged(isDown: true, at: at(0))
        XCTAssertEqual(t.keyDown(at: at(2.0)), .none)
        XCTAssertEqual(t.flagsChanged(isDown: false, at: at(3)), .release)
    }

    func testKeyWithoutTheModifierHeldIsIgnored() {
        var t = ModifierKeyTracker()
        XCTAssertEqual(t.keyDown(at: at(0)), .none)
        XCTAssertEqual(t.flagsChanged(isDown: false, at: at(0.1)), .none)
    }

    func testRepeatedDownEventsAreIgnored() {
        var t = ModifierKeyTracker()
        XCTAssertEqual(t.flagsChanged(isDown: true, at: at(0)), .press)
        XCTAssertEqual(t.flagsChanged(isDown: true, at: at(0.1)), .none)
        XCTAssertEqual(t.flagsChanged(isDown: false, at: at(0.5)), .release)
    }

    func testWorksAgainAfterAnAbort() {
        var t = ModifierKeyTracker()
        _ = t.flagsChanged(isDown: true, at: at(0)); _ = t.keyDown(at: at(0.1)); _ = t.flagsChanged(isDown: false, at: at(0.3))
        XCTAssertEqual(t.flagsChanged(isDown: true, at: at(5)), .press)
        XCTAssertEqual(t.flagsChanged(isDown: false, at: at(6)), .release)
    }
}
