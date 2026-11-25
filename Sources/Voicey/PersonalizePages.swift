import AppKit
import SwiftUI

private struct FieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(6)
            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Lays chips out left to right and wraps to new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    private func arrange(_ width: CGFloat, _ subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for v in subviews {
            let size = v.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal.width ?? 400, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(bounds.width, subviews)
        for (v, o) in zip(subviews, result.origins) {
            v.place(at: CGPoint(x: bounds.minX + o.x, y: bounds.minY + o.y), proposal: .unspecified)
        }
    }
}

private struct Chip: View {
    let text: String
    let dimmed: Bool
    let edit: () -> Void
    let remove: () -> Void
    var body: some View {
        HStack(spacing: 4) {
            Button(action: edit) { Text(text).font(.system(size: 12.5)) }
                .buttonStyle(.plain)
                .help("Click to edit")
            Button(action: remove) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
        .padding(.leading, 10).padding(.trailing, 8).padding(.vertical, 5)
        .background(Color.primary.opacity(0.08), in: Capsule())
        .opacity(dimmed ? 0.45 : 1)
    }
}

/// A suggestion the user can accept or dismiss.
private struct SuggestionChip: View {
    let title: String
    let detail: String?
    let accept: () -> Void
    let dismiss: () -> Void
    var body: some View {
        HStack(spacing: 6) {
            Button(action: accept) {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 9, weight: .bold))
                    Text(title).font(.system(size: 12.5))
                    if let detail { Text(detail).font(.system(size: 11)).foregroundStyle(.secondary) }
                }
            }
            .buttonStyle(.plain)
            .help("Add to your dictionary")
            Button(action: dismiss) { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary) }
                .buttonStyle(.plain)
                .help("Not this one")
        }
        .padding(.leading, 10).padding(.trailing, 8).padding(.vertical, 5)
        .background(Color.accentColor.opacity(0.14), in: Capsule())
    }
}

struct DictionaryPage: View {
    @AppStorage(Prefs.dictionary) private var raw = ""
    @AppStorage(Prefs.learn) private var learn = false
    @ObservedObject private var learning = Learning.shared
    @State private var draft = ""
    @State private var notice = ""
    @State private var editingText = false
    @State private var query = ""
    @FocusState private var fieldFocused: Bool

    private var terms: [String] { DictionaryList.parse(raw, splitOnCommas: false) }
    private func save(_ list: [String]) { raw = list.joined(separator: "\n") }

    private func add(_ text: String) {
        let result = DictionaryList.merged(terms, adding: text)
        save(result.list)
        notice = result.skipped > 0 ? "\(result.skipped == 1 ? "That one is" : "\(result.skipped) were") already in your list." : ""
    }

    var body: some View {
        VStack(spacing: 0) {
            if learn, !learning.termSuggestions.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Suggested from your dictation", systemImage: "lightbulb").font(.system(size: 12, weight: .semibold))
                        FlowLayout(spacing: 6) {
                            ForEach(learning.termSuggestions) { s in
                                SuggestionChip(title: s.term, detail: s.hint, accept: { learning.accept(s) }, dismiss: { learning.dismiss(s) })
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                }
                .padding(.bottom, 10)
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    if editingText {
                        TextEditor(text: $raw)
                            .font(.system(size: 13))
                            .scrollContentBackground(.hidden)
                            .frame(height: 170)
                            .modifier(FieldBackground())
                    } else {
                        TextField("Add a name or term, then press Return", text: $draft)
                            .textFieldStyle(.plain)
                            .focused($fieldFocused)
                            .modifier(FieldBackground())
                            .onSubmit { add(draft); draft = ""; fieldFocused = true }
                            // Pasting "A, B, C" (or a column of names) splits into separate terms.
                            .onChange(of: draft) { value in
                                if value.contains(",") || value.contains("\n") { add(value); draft = "" }
                            }
                        if terms.isEmpty {
                            Text("Nothing here yet. Add the names, products and jargon you say often, and Voicey will spell them your way.")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        } else {
                            let fit = DictionaryList.fitCount(terms)
                            let shown = DictionaryList.filtered(terms, query: query)
                            if terms.count > DictionaryList.searchThreshold {
                                HStack(spacing: 6) {
                                    Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(.secondary)
                                    TextField("Search your terms", text: $query).textFieldStyle(.plain).font(.system(size: 12))
                                    if !query.isEmpty {
                                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                                            .buttonStyle(.plain)
                                    }
                                }
                                .modifier(FieldBackground())
                            }
                            if shown.isEmpty {
                                Text("No terms match \u{201C}\(query)\u{201D}.").font(.system(size: 12)).foregroundStyle(.secondary)
                            }
                            FlowLayout(spacing: 6) {
                                ForEach(shown, id: \.index) { item in
                                    Chip(text: item.term, dimmed: item.index >= fit,
                                         edit: { var l = terms; l.remove(at: item.index); save(l); draft = item.term; fieldFocused = true },
                                         remove: { var l = terms; l.remove(at: item.index); save(l) })
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    HStack(spacing: 8) {
                        let fit = DictionaryList.fitCount(terms)
                        if !notice.isEmpty {
                            Text(notice).font(.system(size: 11)).foregroundStyle(.orange)
                        } else if fit < terms.count {
                            Text("Only the first \(fit) of \(terms.count) terms reach Whisper (faded ones are cut off).")
                                .font(.system(size: 11)).foregroundStyle(.orange)
                        } else {
                            Text("\(terms.count) \(terms.count == 1 ? "term" : "terms")")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(editingText ? "Done" : "Edit as text") {
                            if editingText { save(DictionaryList.parse(raw, splitOnCommas: true)) }   // tidy commas into lines
                            editingText.toggle()
                        }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                    }
                }
                .padding(12)
            }
            Footer(text: "Whisper, Apple’s recognizer and your AI tool all use this list to spell your terms correctly. Paste a comma-separated list to add many at once. Click a term to edit it." + (learn ? "" : " Turn on \u{201C}Learn from my dictation\u{201D} in General to get suggestions."))
        }
    }
}

struct AppTonesPage: View {
    @ObservedObject private var store = Personalization.shared
    @ObservedObject private var learning = Learning.shared
    @AppStorage(Prefs.learn) private var learn = false

    private var candidates: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { app in
                guard app.activationPolicy == .regular, let id = app.bundleIdentifier,
                      id != Bundle.main.bundleIdentifier else { return false }
                return !store.appTones.contains { $0.bundleID == id }
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func icon(_ bundleID: String) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) { return NSWorkspace.shared.icon(forFile: url.path) }
        return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
    }

    private func add(bundleID: String, name: String) {
        guard !store.appTones.contains(where: { $0.bundleID == bundleID }) else { return }
        store.appTones.append(AppTone(bundleID: bundleID, name: name))
    }

    private func chooseFromDisk() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, let b = Bundle(url: url), let id = b.bundleIdentifier {
            add(bundleID: id, name: FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if learn, !learning.toneSuggestions.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 0) {
                        Label("Suggested from your dictation", systemImage: "lightbulb").font(.system(size: 12, weight: .semibold)).padding(12)
                        ForEach(learning.toneSuggestions) { s in
                            Separator()
                            HStack(spacing: 12) {
                                Image(nsImage: icon(s.bundleID)).resizable().frame(width: 22, height: 22)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(s.name): \(TonePreset.all.first { $0.id == s.tone }?.label ?? s.tone)").font(.system(size: 13))
                                    Text(s.reason).font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                Button("Add") { learning.accept(s) }
                                Button { learning.dismiss(s) } label: { Image(systemName: "xmark").foregroundStyle(.secondary) }.buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12).frame(minHeight: 40)
                        }
                    }
                }
                .padding(.bottom, 10)
            }
            Card {
                ForEach($store.appTones) { $rule in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(nsImage: icon(rule.bundleID)).resizable().frame(width: 22, height: 22)
                            Text(rule.name).font(.system(size: 13)).lineLimit(1)
                            Spacer(minLength: 8)
                            MenuPicker(selection: $rule.tone, options: TonePreset.all.map { ($0.id, $0.label) })
                            Button { store.appTones.removeAll { $0.id == rule.id } } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12).frame(minHeight: 34)
                        if rule.tone == "custom" {
                            TextField("Describe the style, e.g. “warm but brief”", text: $rule.custom, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(1...3)
                                .modifier(FieldBackground())
                                .padding(.horizontal, 14).padding(.bottom, 10)
                        }
                        Separator()
                    }
                }
                HStack {
                    Menu {
                        ForEach(candidates, id: \.bundleIdentifier) { app in
                            Button(app.localizedName ?? app.bundleIdentifier ?? "App") {
                                add(bundleID: app.bundleIdentifier ?? "", name: app.localizedName ?? "App")
                            }
                        }
                        if !candidates.isEmpty { Divider() }
                        Button("Choose from Applications…") { chooseFromDisk() }
                    } label: {
                        Label("Add app", systemImage: "plus.circle.fill").font(.system(size: 13))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    Spacer()
                }
                .padding(.horizontal, 12).frame(minHeight: 34)
            }
            Footer(text: "When you dictate into one of these apps, your AI tool writes in that style, for example formal in Mail and casual in Slack. Apps that aren’t listed use the default (and your extra instructions). This needs “Polish with AI” turned on." + (learn ? "" : " Turn on “Learn from my dictation” in General to get suggestions."))
        }
    }
}

struct SnippetsPage: View {
    @ObservedObject private var store = Personalization.shared
    var body: some View {
        VStack(spacing: 0) {
            Card {
                ForEach($store.snippets) { $sn in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("Say").font(.system(size: 13)).foregroundStyle(.secondary)
                            TextField("my address", text: $sn.trigger)
                                .textFieldStyle(.plain)
                                .modifier(FieldBackground())
                            Button { store.snippets.removeAll { $0.id == sn.id } } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        TextEditor(text: $sn.text)
                            .font(.system(size: 13))
                            .scrollContentBackground(.hidden)
                            .frame(height: 54)
                            .modifier(FieldBackground())
                    }
                    .padding(12)
                    Separator()
                }
                HStack {
                    Button { store.snippets.append(Snippet()) } label: {
                        Label("Add snippet", systemImage: "plus.circle.fill").font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    Spacer()
                }
                .padding(.horizontal, 12).frame(minHeight: 34)
            }
            Footer(text: "Say the trigger phrase anywhere in a sentence and it’s replaced with the saved text, exactly as written. The AI tool never rewords it.")
        }
    }
}
