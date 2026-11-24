import XCTest
@testable import Voicey

final class VersionTests: XCTestCase {
    private func v(_ s: String) -> AppVersion { AppVersion(s)! }

    func testOrdering() {
        XCTAssertTrue(v("1.0.1") > v("1.0.0"))
        XCTAssertTrue(v("1.10.0") > v("1.9.9"), "compared as numbers, not text")
        XCTAssertTrue(v("2.0") > v("1.99.99"))
        XCTAssertEqual(v("1.0"), v("1.0.0"))
        XCTAssertEqual(v("v1.2.3"), v("1.2.3"))
    }

    func testPrereleaseSortsBelowItsRelease() {
        XCTAssertTrue(v("1.1.0-beta.1") < v("1.1.0"))
        XCTAssertTrue(v("1.1.0-beta.1") > v("1.0.9"))
    }

    func testGarbageIsRejected() { XCTAssertNil(AppVersion("abc")) }
}

final class UpdaterTests: XCTestCase {
    private let mac27 = OperatingSystemVersion(majorVersion: 27, minorVersion: 2, patchVersion: 1)
    private let mac13 = OperatingSystemVersion(majorVersion: 13, minorVersion: 0, patchVersion: 0)
    private func info(_ version: String, minMacOS: String? = nil) -> UpdateInfo {
        UpdateInfo(version: version, build: nil, url: "https://x/y.zip", sha256: "00", notes: nil, minMacOS: minMacOS)
    }

    func testNewerVersionIsOffered() {
        XCTAssertEqual(Updater.decide(current: "1.0.0", info: info("1.0.1"), osVersion: mac27), .available(info("1.0.1")))
    }

    func testSameOrOlderIsUpToDate() {
        XCTAssertEqual(Updater.decide(current: "1.0.0", info: info("1.0.0"), osVersion: mac27), .upToDate)
        XCTAssertEqual(Updater.decide(current: "1.2.0", info: info("1.1.0"), osVersion: mac27), .upToDate, "never downgrade")
    }

    func testUpdateThatNeedsANewerMacIsNotOffered() {
        XCTAssertEqual(Updater.decide(current: "1.0.0", info: info("1.1.0", minMacOS: "14.0"), osVersion: mac13),
                       .failed("Version 1.1.0 needs macOS 14.0 or later."))
        XCTAssertEqual(Updater.decide(current: "1.0.0", info: info("1.1.0", minMacOS: "14.0"), osVersion: mac27), .available(info("1.1.0", minMacOS: "14.0")))
    }

    func testUnreadableVersionFails() {
        XCTAssertEqual(Updater.decide(current: "1.0.0", info: info("soon"), osVersion: mac27), .failed("The update feed has an unreadable version."))
    }

    func testOnlyHTTPSOrLocalhostIsAllowed() {
        XCTAssertNotNil(Updater.validated("https://example.com/update.json"))
        XCTAssertNotNil(Updater.validated("http://127.0.0.1:8123/update.json"))
        XCTAssertNil(Updater.validated("http://example.com/update.json"))
        XCTAssertNil(Updater.validated("file:///etc/passwd"))
        XCTAssertNil(Updater.validated(""))
    }

    func testFeedParsing() throws {
        let full = #"{"version":"1.2.0","build":"2026","url":"https://h/V.zip","sha256":"ab","notes":"- fixed","minMacOS":"13.0"}"#
        XCTAssertEqual(try JSONDecoder().decode(UpdateInfo.self, from: Data(full.utf8)).version, "1.2.0")
        let minimal = #"{"version":"1.2.0","url":"https://h/V.zip","sha256":"ab"}"#
        XCTAssertNil(try JSONDecoder().decode(UpdateInfo.self, from: Data(minimal.utf8)).notes)
        XCTAssertThrowsError(try JSONDecoder().decode(UpdateInfo.self, from: Data(#"{"version":"1.2.0","url":"https://h/V.zip"}"#.utf8)),
                             "a feed without a checksum must be rejected")
    }
}
