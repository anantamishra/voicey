import AppKit
import ApplicationServices

// MARK: - Pure logic (no windows, no microphone: tested directly)

/// Finds words worth adding to the dictionary: names, products, acronyms, CamelCase and words with digits.
enum TermMiner {
    private static let skip: Set<String> = [
        "I", "I'm", "I'll", "I'd", "I've", "OK", "Okay", "Mr", "Mrs", "Ms", "Dr", "AM", "PM",
        "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
        "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December",
    ]

    static func isKnownWord(_ word: String) -> Bool {
        NSSpellChecker.shared.checkSpelling(of: word, startingAt: 0).location == NSNotFound
    }

    private static func trimmed(_ token: String) -> String {
        var w = Substring(token)
        while let f = w.first, !f.isLetter && !f.isNumber { w = w.dropFirst() }
        while let l = w.last, !l.isLetter && !l.isNumber { w = w.dropLast() }
        var s = String(w)
        for suffix in ["'s", "\u{2019}s"] where s.hasSuffix(suffix) { s = String(s.dropLast(suffix.count)) }
        return s
    }

    private enum Kind { case standalone, proper }

    private static func classify(_ w: String, atSentenceStart: Bool, known: (String) -> Bool) -> Kind? {
        guard w.count >= 2, !skip.contains(w) else { return nil }
        let letters = w.filter(\.isLetter)
        guard !letters.isEmpty else { return nil }
        let chars = Array(w)
        let hasDigit = chars.contains(where: \.isNumber)
        let allowed = chars.allSatisfy { $0.isLetter || $0.isNumber || ".-_+#".contains($0) }
        guard allowed else { return nil }
        if hasDigit { return .standalone }                                              // S3, GPT-4, k8s
        let upper = letters.filter(\.isUppercase).count
        if letters.count >= 2 && letters.count <= 6 && upper == letters.count { return .standalone }   // API, AWS
        for i in 1..<chars.count where chars[i].isUppercase && chars[i - 1].isLowercase { return .standalone }   // iPhone, GitHub
        if chars[0].isUppercase && upper == 1 && !atSentenceStart && letters.count == chars.count && !known(w.lowercased()) {
            return .proper                                                              // Marcus, Priya, Zürich
        }
        return nil
    }

    /// Terms in `text`, in order, without repeats. A name made of several capitalised words ("Acme Corp") stays together.
    static func candidates(in text: String, isKnown: (String) -> Bool = isKnownWord) -> [String] {
        var out: [String] = []
        var run: [String] = []
        func flush() { if !run.isEmpty { out.append(run.joined(separator: " ")); run = [] } }
        var atStart = true
        for token in text.split(whereSeparator: \.isWhitespace).map(String.init) {
            let w = trimmed(token)
            switch classify(w, atSentenceStart: atStart, known: isKnown) {
            case .standalone?: flush(); out.append(w)
            case .proper?: if run.count < 3 { run.append(w) } else { flush(); run.append(w) }
            case nil: flush()
            }
            if let last = token.last, ",;:.?!)\"".contains(last) { flush() }
            atStart = token.last.map { ".?!".contains($0) } ?? false
        }
        flush()
        var seen = Set<String>()
        return out.filter { seen.insert($0.lowercased()).inserted }
    }

    /// Does this look like something worth teaching (rather than an ordinary word)?
    static func looksLikeTerm(_ phrase: String, isKnown: (String) -> Bool = isKnownWord) -> Bool {
        phrase.split(separator: " ").contains { word in
            let w = String(word)
            return classify(w, atSentenceStart: false, known: isKnown) != nil || !isKnown(w.lowercased())
        }
    }
}

/// Works out what the user changed after Voicey pasted: "cooper nettys" became "Kubernetes".
enum CorrectionDiff {
    static func words(_ s: String) -> [String] {
        s.split(whereSeparator: \.isWhitespace).compactMap { token in
            var w = Substring(token)
            while let f = w.first, !f.isLetter && !f.isNumber { w = w.dropFirst() }
            while let l = w.last, !l.isLetter && !l.isNumber { w = w.dropLast() }
            return w.isEmpty ? nil : String(w)
        }
    }

    /// The part of the field that Voicey pasted, even if it has been edited since. Nil when it can't be found.
    static func segment(in value: String, pasted: String) -> String? {
        if value.contains(pasted) { return pasted }
        let w = words(pasted)
        guard w.count >= 5 else { return nil }
        let head = w.prefix(2).joined(separator: " "), tail = w.suffix(2).joined(separator: " ")
        guard let h = value.range(of: head, options: .caseInsensitive),
              let t = value.range(of: tail, options: [.caseInsensitive, .backwards]), t.upperBound > h.lowerBound,
              h.lowerBound < t.lowerBound else { return nil }
        let seg = String(value[h.lowerBound..<t.upperBound])
        return seg.count <= pasted.count * 2 + 100 ? seg : nil
    }

    /// Small word-for-word swaps (one to three words each way). A rewrite of the whole text is not a correction.
    static func replacements(original: String, edited: String) -> [(from: String, to: String)] {
        let a = words(original), b = words(edited)
        guard a.count >= 2, b.count >= 2, a.count <= 400, b.count <= 400 else { return [] }
        // longest common subsequence of the two word lists
        var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            for j in stride(from: b.count - 1, through: 0, by: -1) {
                table[i][j] = a[i] == b[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
            }
        }
        var pairs: [(String, String)] = []
        var removed: [String] = [], added: [String] = []
        func close() {
            if !removed.isEmpty, !added.isEmpty, removed.count <= 3, added.count <= 3 {
                pairs.append((removed.joined(separator: " "), added.joined(separator: " ")))
            }
            removed = []; added = []
        }
        var i = 0, j = 0, changed = 0
        while i < a.count || j < b.count {
            if i < a.count, j < b.count, a[i] == b[j] { close(); i += 1; j += 1 }
            else if j < b.count, i == a.count || table[i][j + 1] >= table[i + 1][j] { added.append(b[j]); j += 1; changed += 1 }
            else { removed.append(a[i]); i += 1; changed += 1 }
        }
        close()
        // Mostly rewritten, or a long list of edits: that is editing, not correcting a misheard word.
        guard pairs.count <= 4, changed * 10 <= max(a.count, b.count) * 4 else { return [] }
        return pairs
    }
}

/// A guess at the right tone for an app, from the kind of app and from how you talk in it.
enum ToneGuesser {
    static let casualWords: Set<String> = ["hey", "hi", "gonna", "wanna", "gotta", "kinda", "yeah", "yep", "nope", "lol", "btw", "cool",
                                           "awesome", "haha", "thx", "dude", "ok", "okay", "yo"]
    static let formalWords: Set<String> = ["dear", "regards", "sincerely", "kindly", "attached", "hereby", "furthermore", "pursuant",
                                           "respectfully", "accordingly", "therefore"]

    static func markers(in raw: String) -> (casual: Int, formal: Int) {
        var c = 0, f = 0
        for w in CorrectionDiff.words(raw.lowercased()) {
            if casualWords.contains(w) { c += 1 }
            if formalWords.contains(w) { f += 1 }
        }
        return (c, f)
    }

    /// The app's usual style, from its bundle id.
    static func category(for bundleID: String) -> String? {
        let id = bundleID.lowercased()
        let technical = ["com.apple.dt.xcode", "com.microsoft.vscode", "com.apple.terminal", "com.googlecode.iterm2", "dev.warp",
                         "com.todesktop", "com.jetbrains", "com.sublimetext", "com.github", "com.mitchellh.ghostty", "org.vim"]
        let casual = ["com.apple.mobilesms", "com.tinyspeck.slackmacgap", "com.hnc.discord", "ru.keepcoder.telegram", "net.whatsapp",
                      "com.facebook.archon", "org.whispersystems.signal"]
        let formal = ["com.apple.mail", "com.microsoft.outlook", "com.readdle.smartemail", "com.apple.iwork.pages", "com.microsoft.word"]
        if technical.contains(where: id.hasPrefix) { return "technical" }
        if casual.contains(where: id.hasPrefix) { return "casual" }
        if formal.contains(where: id.hasPrefix) { return "formal" }
        return nil
    }

    static let minimumDictations = 5

    /// A tone preset id worth suggesting, with a short reason, or nil when there isn't enough to go on.
    static func suggestion(bundleID: String, dictations n: Int, casual: Int, formal: Int) -> (tone: String, reason: String)? {
        guard n >= minimumDictations else { return nil }
        if casual >= 3 && casual > 2 * formal { return ("casual", "you usually talk casually here") }
        if formal >= 2 && formal > casual { return ("formal", "you usually write formally here") }
        if let kind = category(for: bundleID) {
            switch kind {
            case "technical": return ("technical", "it looks like a code or terminal app")
            case "casual": return ("casual", "it looks like a chat app")
            default: return ("formal", "it looks like an email or document app")
            }
        }
        return nil
    }
}

// MARK: - What it remembers, and the suggestions built from it

struct TermStat: Codable { var count: Int; var hint: String? }
struct AppStat: Codable { var name: String; var n = 0; var casual = 0; var formal = 0 }
struct LearnedData: Codable {
    var terms: [String: TermStat] = [:]          // candidate word -> how many dictations it showed up in
    var apps: [String: AppStat] = [:]            // bundle id -> counts only, never text
    var dismissedTerms: [String] = []
    var dismissedTones: [String] = []
}

struct TermSuggestion: Identifiable { var id: String { term }; let term: String; let hint: String? }
struct ToneSuggestion: Identifiable { var id: String { bundleID }; let bundleID: String; let name: String; let tone: String; let reason: String }

/// Opt-in learning. It keeps only candidate words and counts (never the text you dictated), and only ever makes
/// suggestions: nothing is added to your dictionary or app tones until you approve it.
final class Learning: ObservableObject {
    static let shared = Learning()
    static let minSeen = 2                       // a word must show up in this many dictations before it is suggested
    private static let key = "learnedData"

    @Published private(set) var data: LearnedData

    private init() {
        if let raw = Prefs.d.data(forKey: Self.key), let d = try? JSONDecoder().decode(LearnedData.self, from: raw) { data = d } else { data = LearnedData() }
    }

    static var enabled: Bool { Prefs.d.bool(forKey: Prefs.learn) }

    private func save() { if let raw = try? JSONEncoder().encode(data) { Prefs.d.set(raw, forKey: Self.key) } }

    // Suggestions ---------------------------------------------------------

    var termSuggestions: [TermSuggestion] {
        let have = Set(Personalization.terms.map { $0.lowercased() })
        let dismissed = Set(data.dismissedTerms.map { $0.lowercased() })
        return data.terms
            .filter { $0.value.count >= Self.minSeen && !have.contains($0.key.lowercased()) && !dismissed.contains($0.key.lowercased()) }
            .sorted { ($0.value.count, $1.key) > ($1.value.count, $0.key) }
            .prefix(8).map { TermSuggestion(term: $0.key, hint: $0.value.hint) }
    }

    var toneSuggestions: [ToneSuggestion] {
        let ruled = Set(Personalization.shared.appTones.map(\.bundleID))
        return data.apps.compactMap { id, stat in
            guard !ruled.contains(id), !data.dismissedTones.contains(id),
                  let s = ToneGuesser.suggestion(bundleID: id, dictations: stat.n, casual: stat.casual, formal: stat.formal) else { return nil }
            return ToneSuggestion(bundleID: id, name: stat.name, tone: s.tone, reason: s.reason)
        }.sorted { $0.name < $1.name }
    }

    func accept(_ s: TermSuggestion) {
        var list = Personalization.terms
        guard !list.contains(where: { $0.caseInsensitiveCompare(s.term) == .orderedSame }) else { return }
        list.append(s.term)
        Prefs.d.set(list.joined(separator: "\n"), forKey: Prefs.dictionary)
        data.terms[s.term] = nil
        objectWillChange.send(); save()
    }
    func dismiss(_ s: TermSuggestion) { data.dismissedTerms.append(s.term); save(); objectWillChange.send() }

    func accept(_ s: ToneSuggestion) {
        Personalization.shared.appTones.append(AppTone(bundleID: s.bundleID, name: s.name, tone: s.tone))
        data.apps[s.bundleID] = nil
        save(); objectWillChange.send()
    }
    func dismiss(_ s: ToneSuggestion) { data.dismissedTones.append(s.bundleID); save(); objectWillChange.send() }

    /// Forget everything learned so far.
    func reset() { data = LearnedData(); save() }

    // Learning from a dictation -------------------------------------------

    /// Called after every dictation. `raw` is what you said, `final` is what was pasted.
    func record(raw: String, final: String, app: NSRunningApplication?) {
        guard Self.enabled else { return }
        for term in TermMiner.candidates(in: final) { data.terms[term, default: TermStat(count: 0)].count += 1 }
        if let id = app?.bundleIdentifier, id != Bundle.main.bundleIdentifier {
            var stat = data.apps[id] ?? AppStat(name: app?.localizedName ?? id)
            let m = ToneGuesser.markers(in: raw)
            stat.n += 1; stat.casual += m.casual; stat.formal += m.formal
            data.apps[id] = stat
        }
        prune(); save(); objectWillChange.send()
        vlog("learn: tracking \(data.terms.count) candidate terms, \(data.apps.count) apps")
    }

    private func prune() {
        guard data.terms.count > 300 else { return }
        for (k, v) in data.terms where v.count < Self.minSeen { data.terms[k] = nil; if data.terms.count <= 250 { break } }
    }

    // Learning from your corrections --------------------------------------

    /// After pasting, look at the same text field a little later. If you fixed a misheard word, offer it as a dictionary term.
    func watchEdits(of pasted: String) {
        guard Self.enabled, AXIsProcessTrusted() else { return }
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &ref) == .success,
              let ref, CFGetTypeID(ref) == AXUIElementGetTypeID() else { return }
        let element = unsafeBitCast(ref, to: AXUIElement.self)
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in self?.checkEdits(element, pasted: pasted) }
    }

    private func checkEdits(_ element: AXUIElement, pasted: String) {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success, let text = value as? String,
              let segment = CorrectionDiff.segment(in: text, pasted: pasted), segment != pasted else { return }
        var learned = 0
        for pair in CorrectionDiff.replacements(original: pasted, edited: segment) where TermMiner.looksLikeTerm(pair.to) {
            data.terms[pair.to, default: TermStat(count: 0)].count = max(Self.minSeen, data.terms[pair.to]?.count ?? 0)
            data.terms[pair.to]?.hint = "you changed \u{201C}\(pair.from)\u{201D}"
            learned += 1
        }
        if learned > 0 { save(); objectWillChange.send(); vlog("learn: \(learned) correction(s) noticed") }
    }
}
