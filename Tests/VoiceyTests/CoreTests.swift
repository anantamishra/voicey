import XCTest
import Carbon.HIToolbox
@testable import Voicey

final class HotKeyOptionTests: XCTestCase {
    override func setUp() { HotKeyOption.reset() }
    override func tearDown() { HotKeyOption.reset() }

    func testLabels() {
        XCTAssertEqual(HotKeyOption.label(keyCode: 49, modifiers: controlKey | optionKey, characters: " "), "⌃⌥ Space")
        XCTAssertEqual(HotKeyOption.label(keyCode: 2, modifiers: controlKey | cmdKey, characters: "d"), "⌃⌘ D")
        XCTAssertEqual(HotKeyOption.label(keyCode: 126, modifiers: shiftKey | cmdKey, characters: nil), "⇧⌘ ↑")
        XCTAssertEqual(HotKeyOption.label(keyCode: 96, modifiers: 0, characters: nil), "F5")
    }

    func testSaveCurrentAndReset() {
        XCTAssertTrue(HotKeyOption.current.isDefault)
        HotKeyOption.save(HotKeyOption(id: "custom", label: "⌃⌘ D", keyCode: 2, modifiers: controlKey | cmdKey))
        XCTAssertEqual(HotKeyOption.current.label, "⌃⌘ D")
        XCTAssertFalse(HotKeyOption.current.isDefault)
        HotKeyOption.reset()
        XCTAssertTrue(HotKeyOption.current.isDefault)
    }

    func testSingleModifierKeysAreRecognised() {
        HotKeyOption.save(HotKeyOption(id: "custom", label: "Right ⌥", keyCode: 61, modifiers: 0))
        XCTAssertTrue(HotKeyOption.current.isModifierKey)
        HotKeyOption.save(HotKeyOption(id: "custom", label: "F5", keyCode: 96, modifiers: 0))
        XCTAssertFalse(HotKeyOption.current.isModifierKey)
    }

    func testFlagsForModifierKeys() {
        XCTAssertEqual(ModifierHotKey.flag(for: 63), .function)
        XCTAssertEqual(ModifierHotKey.flag(for: 61), .option)
        XCTAssertNil(ModifierHotKey.flag(for: 57), "Caps Lock isn't supported")
    }
}

final class SilenceTrimmerTests: XCTestCase {
    private func quiet(_ seconds: Double) -> [Float] { (0..<Int(16_000 * seconds)).map { _ in Float.random(in: -0.002...0.002) } }
    private func tone(_ seconds: Double) -> [Float] { (0..<Int(16_000 * seconds)).map { 0.3 * sin(Float($0) * 0.2) } }

    func testSilenceAloneIsDroppedSoWhisperIsNotAskedToInventText() {
        XCTAssertNil(SilenceTrimmer.trim(quiet(4)))
    }

    func testTooLittleSpeechIsDropped() {
        XCTAssertNil(SilenceTrimmer.trim(quiet(2) + tone(0.3) + quiet(2)))
    }

    func testLongPausesAreCutDown() throws {
        let audio = quiet(2) + tone(1.5) + quiet(3) + tone(1.5) + quiet(2)       // 10 s
        let trimmed = try XCTUnwrap(SilenceTrimmer.trim(audio))
        XCTAssertLessThan(trimmed.count, audio.count * 6 / 10)
        XCTAssertGreaterThan(trimmed.count, 16_000 * 3)                          // all the speech is still there
    }
}

final class ToolInstallerTests: XCTestCase {
    func testInstallCommandsAreTheVendorsOwn() {
        XCTAssertEqual(ToolInstaller.command(for: .claude)?.shell, "set -o pipefail; curl -fsSL https://claude.ai/install.sh | bash")
        XCTAssertEqual(ToolInstaller.command(for: .codex)?.shell, "set -o pipefail; curl -fsSL https://chatgpt.com/codex/install.sh | sh")
        XCTAssertNil(ToolInstaller.command(for: .openai))
        XCTAssertNil(ToolInstaller.command(for: .antigravity))
    }

    func testSignInProblemsAreToldApartFromBrokenTools() {
        XCTAssertTrue(ToolInstaller.looksLikeAuthProblem("Not logged in · Please run /login"))
        XCTAssertTrue(ToolInstaller.looksLikeAuthProblem("API Error: 401 unauthorized"))
        XCTAssertFalse(ToolInstaller.looksLikeAuthProblem("No reply (exit 124)."))
    }

    func testAnAnswerIsNotMistakenForAnEdit() {
        XCTAssertTrue(TextPolisher.looksLikeEdit("Hi, how are you?", of: "hi how are you"))
        XCTAssertFalse(TextPolisher.looksLikeEdit(String(repeating: "a long reply ", count: 20), of: "hi how are you"))
    }
}

final class WhisperOutputTests: XCTestCase {
    func testNonSpeechMarkersAreRemoved() {
        XCTAssertEqual(WhisperRunner.cleanOutput(" Hello there. [BLANK_AUDIO]\n"), "Hello there.")
        XCTAssertEqual(WhisperRunner.cleanOutput("(music) and then (Silence)"), "and then")
        XCTAssertEqual(WhisperRunner.cleanOutput("[BLANK_AUDIO]"), "")
    }

    func testLinesAreJoinedIntoOne() {
        XCTAssertEqual(WhisperRunner.cleanOutput(" First line.\n\n Second line.\n"), "First line. Second line.")
    }
}

final class AppPolicyTests: XCTestCase {
    func testDockIconWhenWantedOrWhenAWindowIsOpen() {
        XCTAssertEqual(AppPolicy.policy(showInDock: true, windowOpen: false), .regular)
        XCTAssertEqual(AppPolicy.policy(showInDock: true, windowOpen: true), .regular)
        XCTAssertEqual(AppPolicy.policy(showInDock: false, windowOpen: true), .regular, "a window needs a Dock icon to come to the front")
        XCTAssertEqual(AppPolicy.policy(showInDock: false, windowOpen: false), .accessory)
    }
}
