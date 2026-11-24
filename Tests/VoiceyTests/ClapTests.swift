import XCTest
@testable import Voicey

final class ClapTests: XCTestCase {
    /// Plays a list of (start time, length) bursts as 10 ms readings; returns the times a double clap fired.
    private func run(_ bursts: [(Double, Double)], loud: Float = 0.6, background: Float = 0.01, seconds: Double = 5) -> [Double] {
        var p = ClapPattern()
        var fired: [Double] = []
        var t = 0.0
        while t < seconds {
            let inBurst = bursts.contains { t >= $0.0 && t < $0.0 + $0.1 }
            if p.feed(peak: inBurst ? loud : background, at: t) { fired.append(t) }
            t += 0.01
        }
        return fired
    }

    func testTwoQuickClapsFireOnce() {
        XCTAssertEqual(run([(1.0, 0.04), (1.3, 0.04)]).count, 1)
    }
    func testOneClapDoesNothing() {
        XCTAssertTrue(run([(1.0, 0.04)]).isEmpty)
    }
    func testClapsTooFarApartDoNothing() {
        XCTAssertTrue(run([(1.0, 0.04), (2.5, 0.04)]).isEmpty)
    }
    func testClapsTooCloseCountAsOne() {
        XCTAssertTrue(run([(1.0, 0.04), (1.07, 0.04)]).isEmpty)
    }
    func testLongLoudSoundIsNotAClap() {
        XCTAssertTrue(run([(1.0, 0.6), (1.9, 0.6)]).isEmpty)
    }
    func testQuietNoiseIsIgnored() {
        XCTAssertTrue(run([(1.0, 0.04), (1.3, 0.04)], loud: 0.1).isEmpty)
    }
    func testThreeClapsFireOnlyOnce() {
        XCTAssertEqual(run([(1.0, 0.04), (1.3, 0.04), (1.6, 0.04)]).count, 1)
    }
    func testSecondDoubleClapAfterCooldownFiresAgain() {
        XCTAssertEqual(run([(1.0, 0.04), (1.3, 0.04), (4.0, 0.04), (4.3, 0.04)], seconds: 7).count, 2)
    }
}
