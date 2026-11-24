import AppKit
import SwiftUI

// MARK: - Models

struct AppTone: Codable, Identifiable, Hashable {
    var id = UUID()
    var bundleID: String
    var name: String
    var tone = "casual"          // a TonePreset id
    var custom = ""
}

struct Snippet: Codable, Identifiable, Hashable {
    var id = UUID()
    var trigger = ""
    var text = ""
}

enum TonePreset {
    static let all: [(id: String, label: String, prompt: String)] = [
        ("formal", "Formal", "Formal, professional tone: complete sentences, proper capitalisation and punctuation, no slang."),
        ("casual", "Casual", "Casual, friendly tone: conversational, contractions are fine, light punctuation."),
        ("veryCasual", "Very casual", "Very casual, like a quick chat message: short sentences, lowercase is fine, minimal punctuation."),
        ("technical", "Technical / code", "Technical context (code editor or terminal): keep identifiers, commands, file names and numbers exactly as spoken, be precise and terse, no flowery wording."),
        ("custom", "Custom…", ""),
    ]
    static func prompt(for rule: AppTone) -> String {
        if rule.tone == "custom" { return rule.custom.trimmingCharacters(in: .whitespacesAndNewlines) }
        return all.first { $0.id == rule.tone }?.prompt ?? ""
    }
}

// MARK: - Store + text logic

/// Personal dictionary, per-app tones and snippets.
final class Personalization: ObservableObject {
    static let shared = Personalization()

    @Published var appTones: [AppTone] { didSet { Self.save(appTones, "appTones") } }
    @Published var snippets: [Snippet] { didSet { Self.save(snippets, "snippets") } }

    private init() {
        appTones = Self.load("appTones")
        snippets = Self.load("snippets")
    }

    private static func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { Prefs.d.set(data, forKey: key) }
    }
    private static func load<T: Decodable>(_ key: String) -> [T] {
        guard let data = Prefs.d.data(forKey: key), let v = try? JSONDecoder().decode([T].self, from: data) else { return [] }
        return v
    }

    // Dictionary ----------------------------------------------------------

    static var terms: [String] {
        DictionaryList.parse(Prefs.d.string(forKey: Prefs.dictionary) ?? "", splitOnCommas: false)
    }

    static let whisperBudget = DictionaryList.whisperBudget

    /// Prompt that nudges Whisper toward the right spellings.
    static var whisperPrompt: String {
        let list = terms.joined(separator: ", ")
        return list.isEmpty ? "" : "Vocabulary: \(String(list.prefix(whisperBudget)))."
    }

    // Per-app tone --------------------------------------------------------

    func tone(forBundleID id: String?) -> (appName: String, prompt: String)? {
        guard let id, let rule = appTones.first(where: { $0.bundleID == id }) else { return nil }
        let p = TonePreset.prompt(for: rule)
        return p.isEmpty ? nil : (rule.name, p)
    }

    // Snippets ------------------------------------------------------------

    struct Protected {
        var text: String
        var tokens: [(token: String, expansion: String)]
        /// True when the speaker said nothing except snippet triggers, so the AI tool isn't needed.
        var onlySnippets: Bool {
            guard !tokens.isEmpty else { return false }
            var rest = text
            for t in tokens { rest = rest.replacingOccurrences(of: t.token, with: "") }
            return rest.unicodeScalars.allSatisfy { CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines).contains($0) }
        }
    }

    /// Swaps spoken trigger phrases for placeholders so the AI tool can't reword the saved text.
    func protect(_ raw: String) -> Protected {
        var text = raw
        var tokens: [(String, String)] = []
        for sn in snippets.sorted(by: { $0.trigger.count > $1.trigger.count }) {
            let words = sn.trigger.split(whereSeparator: \.isWhitespace).map { NSRegularExpression.escapedPattern(for: String($0)) }
            guard !words.isEmpty, !sn.text.isEmpty else { continue }
            let pattern = "(?<![\\p{L}\\p{N}])" + words.joined(separator: "[\\s,]+") + "(?![\\p{L}\\p{N}])"
            guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            guard re.firstMatch(in: text, range: range) != nil else { continue }
            let token = "[[SNIPPET\(tokens.count + 1)]]"
            text = re.stringByReplacingMatches(in: text, range: range, withTemplate: NSRegularExpression.escapedTemplate(for: token))
            tokens.append((token, sn.text))
        }
        return Protected(text: text, tokens: tokens)
    }

    func expand(_ text: String, _ p: Protected) -> String {
        var out = text
        if p.onlySnippets {
            // Drop stray punctuation around the placeholders (but not the [[ ]] that make up the placeholders).
            let strip = CharacterSet.punctuationCharacters.subtracting(CharacterSet(charactersIn: "[]")).union(.whitespacesAndNewlines)
            out = out.trimmingCharacters(in: strip)
        }
        for t in p.tokens { out = out.replacingOccurrences(of: t.token, with: t.expansion) }
        return out
    }
}

/// Pure logic for the dictionary list (kept separate from the view so it can be tested).
enum DictionaryList {
    /// Whisper only sees the first this-many characters of the joined list.
    static let whisperBudget = 600

    /// Splits text into terms: always on new lines, and on commas too when `splitOnCommas` (typing / pasting).
    static func parse(_ text: String, splitOnCommas: Bool) -> [String] {
        let separators = splitOnCommas ? CharacterSet(charactersIn: "\n,") : CharacterSet(charactersIn: "\n")
        return text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Adds new terms, skipping ones already present (ignoring case). Returns the list and how many were skipped.
    static func merged(_ existing: [String], adding text: String) -> (list: [String], skipped: Int) {
        var list = existing
        var skipped = 0
        for t in parse(text, splitOnCommas: true) {
            if list.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) { skipped += 1 } else { list.append(t) }
        }
        return (list, skipped)
    }

    /// Terms matching a search (ignoring case and accents), each with its position in the full list.
    static func filtered(_ terms: [String], query: String) -> [(index: Int, term: String)] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return terms.enumerated().compactMap { i, t in
            q.isEmpty || t.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil ? (i, t) : nil
        }
    }

    /// The search box only appears once the list is long enough to need it.
    static let searchThreshold = 12

    /// How many leading terms fit in Whisper's prompt budget (terms are joined with ", ").
    static func fitCount(_ terms: [String], budget: Int = whisperBudget) -> Int {
        var used = 0
        for (i, t) in terms.enumerated() {
            used += t.count + (i == 0 ? 0 : 2)
            if used > budget { return i }
        }
        return terms.count
    }
}
