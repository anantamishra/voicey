import AppKit
import Carbon.HIToolbox

/// UserDefaults keys and their defaults. The key *strings* are what is stored on disk, so they stay as they were
/// even where a constant has been renamed (`polish` is still saved as "useClaude").
enum Prefs {
    // Dictation
    static let hotkey = "hotkey"                     // legacy preset id, only read to migrate an old choice
    static let hotkeyCode = "hotkeyCode"
    static let hotkeyMods = "hotkeyMods"
    static let hotkeyLabel = "hotkeyLabel"
    static let mode = "hotkeyMode"                   // a DictationMode
    static let locale = "localeID"
    static let overlay = "liveOverlay"
    static let autoPaste = "autoPaste"
    static let showInDock = "showInDock"
    static let autoStop = "autoStopSeconds"          // pause length that ends a dictation by itself; 0 = off
    static let clapToStart = "clapToStart"           // a double clap starts hands-free dictation

    // Recognition
    static let engine = "engine"                     // a RecognitionEngine
    static let whisperModel = "whisperModel"
    static let trimSilence = "trimSilence"

    // AI polish
    static let polish = "useClaude"
    static let aiTool = "aiTool"                     // "claude" or "codex"
    static let claudeModel = "claudeModel"
    static let codexModel = "codexModel"
    static let extra = "extraInstructions"

    // Personalize
    static let dictionary = "dictionary"

    // App
    static let onboardingDone = "onboardingDone"
    static let autoUpdate = "autoUpdate"
    static let updateFeed = "updateFeedURL"

    // Remembered between launches
    static let lastTranscript = "lastTranscript"
    static let lastUpdateCheck = "lastUpdateCheck"

    static let defaults: [String: Any] = [
        hotkey: "ctrlOptSpace", mode: DictationMode.smart.rawValue, locale: "", overlay: true, autoPaste: true, showInDock: true, clapToStart: false, autoStop: 3.0,
        engine: RecognitionEngine.whisper.rawValue, whisperModel: "base.en", trimSilence: true,
        polish: true, aiTool: "claude", claudeModel: "haiku", codexModel: "", extra: "",
        dictionary: "",
        onboardingDone: false, autoUpdate: true, updateFeed: "",
    ]

    static func register() { d.register(defaults: defaults) }
    static var d: UserDefaults { .standard }
}

/// Which speech recognizer produces the final text.
enum RecognitionEngine: String {
    case whisper, apple
    static var current: RecognitionEngine { RecognitionEngine(rawValue: Prefs.d.string(forKey: Prefs.engine) ?? "") ?? .whisper }
}

/// How the shortcut behaves.
enum DictationMode: String {
    case smart       // hold to talk, press to start/stop, double-tap for hands-free
    case toggle      // press to start, press to stop
    case hold        // talk while it is held

    static var current: DictationMode { DictationMode(rawValue: Prefs.d.string(forKey: Prefs.mode) ?? "") ?? .smart }
}

struct HotKeyOption: Identifiable, Equatable {
    let id: String
    let label: String
    let keyCode: Int
    let modifiers: Int          // Carbon modifier mask

    static let `default` = HotKeyOption(id: "default", label: "\u{2303}\u{2325} Space", keyCode: kVK_Space, modifiers: controlKey | optionKey)

    /// Old preset ids, kept so a shortcut chosen before the recorder existed still works.
    private static let legacy: [String: HotKeyOption] = [
        "ctrlOptSpace": .default,
        "optSpace": HotKeyOption(id: "optSpace", label: "\u{2325} Space", keyCode: kVK_Space, modifiers: optionKey),
        "cmdShiftSpace": HotKeyOption(id: "cmdShiftSpace", label: "\u{21E7}\u{2318} Space", keyCode: kVK_Space, modifiers: cmdKey | shiftKey),
        "ctrlOptCmdSpace": HotKeyOption(id: "ctrlOptCmdSpace", label: "\u{2303}\u{2325}\u{2318} Space", keyCode: kVK_Space, modifiers: controlKey | optionKey | cmdKey),
        "ctrlOptD": HotKeyOption(id: "ctrlOptD", label: "\u{2303}\u{2325} D", keyCode: kVK_ANSI_D, modifiers: controlKey | optionKey),
    ]

    static var current: HotKeyOption {
        let d = Prefs.d
        if d.object(forKey: Prefs.hotkeyCode) != nil {
            return HotKeyOption(id: "custom", label: d.string(forKey: Prefs.hotkeyLabel) ?? "?",
                                keyCode: d.integer(forKey: Prefs.hotkeyCode), modifiers: d.integer(forKey: Prefs.hotkeyMods))
        }
        return legacy[d.string(forKey: Prefs.hotkey) ?? ""] ?? .default
    }

    /// fn, Right ⌥ and friends used on their own as the shortcut.
    static let modifierNames: [Int: String] = [
        63: "fn", 61: "Right \u{2325}", 58: "Left \u{2325}", 54: "Right \u{2318}", 55: "Left \u{2318}",
        60: "Right \u{21E7}", 56: "Left \u{21E7}", 62: "Right \u{2303}", 59: "Left \u{2303}",
    ]
    var isModifierKey: Bool { modifiers == 0 && Self.modifierNames[keyCode] != nil }

    var isDefault: Bool { keyCode == Self.default.keyCode && modifiers == Self.default.modifiers }

    static func save(_ o: HotKeyOption) {
        Prefs.d.set(o.keyCode, forKey: Prefs.hotkeyCode)
        Prefs.d.set(o.modifiers, forKey: Prefs.hotkeyMods)
        Prefs.d.set(o.label, forKey: Prefs.hotkeyLabel)
    }

    static func reset() {
        for k in [Prefs.hotkeyCode, Prefs.hotkeyMods, Prefs.hotkeyLabel, Prefs.hotkey] { Prefs.d.removeObject(forKey: k) }
    }

    // MARK: Building a shortcut from a key press

    static let functionKeys: Set<Int> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90]
    private static let keyNames: [Int: String] = [
        49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 117: "Fwd Delete", 123: "\u{2190}", 124: "\u{2192}", 125: "\u{2193}", 126: "\u{2191}",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20",
    ]

    static func carbonModifiers(_ f: NSEvent.ModifierFlags) -> Int {
        var m = 0
        if f.contains(.control) { m |= controlKey }
        if f.contains(.option) { m |= optionKey }
        if f.contains(.shift) { m |= shiftKey }
        if f.contains(.command) { m |= cmdKey }
        return m
    }

    static func label(keyCode: Int, modifiers: Int, characters: String?) -> String {
        var s = ""
        if modifiers & controlKey != 0 { s += "\u{2303}" }
        if modifiers & optionKey != 0 { s += "\u{2325}" }
        if modifiers & shiftKey != 0 { s += "\u{21E7}" }
        if modifiers & cmdKey != 0 { s += "\u{2318}" }
        let key = keyNames[keyCode] ?? (characters ?? "").uppercased()
        return s + (s.isEmpty ? "" : " ") + (key.isEmpty ? "Key \(keyCode)" : key)
    }
}

extension Notification.Name {
    static let voiceyHotKeyChanged = Notification.Name("voiceyHotKeyChanged")
    static let voiceyHotKeyPause = Notification.Name("voiceyHotKeyPause")
}
