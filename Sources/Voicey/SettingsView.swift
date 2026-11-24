import AppKit
import ServiceManagement
import Speech
import SwiftUI

// MARK: - Settings screen (sidebar layout)

enum SettingsTab: String, CaseIterable, Identifiable {
    case dictation, recognition, claude, dictionary, apps, snippets, general
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dictation: return "Dictation"
        case .recognition: return "Recognition"
        case .claude: return "AI polish"
        case .dictionary: return "Dictionary"
        case .apps: return "App tones"
        case .snippets: return "Snippets"
        case .general: return "General"
        }
    }
    var symbol: String {
        switch self {
        case .dictation: return "mic"
        case .recognition: return "waveform"
        case .claude: return "sparkles"
        case .dictionary: return "character.book.closed"
        case .apps: return "app.badge"
        case .snippets: return "text.insert"
        case .general: return "gearshape"
        }
    }
}

private struct SidebarRow: View {
    let tab: SettingsTab
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: tab.symbol).font(.system(size: 13)).frame(width: 18)
                Text(tab.title).font(.system(size: 13))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(selected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SettingsView: View {
    @AppStorage(Prefs.polish) private var polish = true
    @AppStorage(Prefs.claudeModel) private var model = "haiku"
    @AppStorage(Prefs.extra) private var extra = ""
    @AppStorage(Prefs.locale) private var localeID = ""
    @AppStorage(Prefs.autoPaste) private var autoPaste = true
    @AppStorage(Prefs.mode) private var mode = DictationMode.smart.rawValue
    @AppStorage(Prefs.engine) private var engine = RecognitionEngine.whisper.rawValue
    @AppStorage(Prefs.whisperModel) private var whisperModel = "base.en"
    @AppStorage(Prefs.trimSilence) private var trimSilence = true
    @AppStorage(Prefs.overlay) private var overlay = true
    @ObservedObject private var store = ModelStore.shared
    @ObservedObject private var personal = Personalization.shared
    @ObservedObject private var tools = AIToolStore.shared
    @ObservedObject private var updater = Updater.shared
    @AppStorage(Prefs.autoUpdate) private var autoUpdate = true
    @AppStorage(Prefs.showInDock) private var showInDock = true
    @AppStorage(Prefs.updateFeed) private var updateFeed = ""
    @AppStorage(Prefs.aiTool) private var aiTool = "claude"
    @AppStorage(Prefs.codexModel) private var codexModel = ""
    @State private var tab: SettingsTab = .dictation
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError = ""

    private let localeOptions: [(value: String, label: String)] =
        [("", "System default")] + SFSpeechRecognizer.supportedLocales()
            .map { (value: $0.identifier, label: Locale.current.localizedString(forIdentifier: $0.identifier) ?? $0.identifier) }
            .sorted { $0.label < $1.label }

    // MARK: Sidebar

    private func group(_ title: String?, _ tabs: [SettingsTab]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    .padding(.leading, 8).padding(.top, 12).padding(.bottom, 3)
            }
            ForEach(tabs) { t in SidebarRow(tab: t, selected: tab == t) { tab = t } }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 22, height: 22)
                Text("Voicey").font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 8).padding(.bottom, 8)
            group(nil, [.dictation, .recognition, .claude])
            group("Personalize", [.dictionary, .apps, .snippets])
            group("App", [.general])
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 38)
        .frame(width: 176)
        .frame(maxHeight: .infinity)
        .background(Color.primary.opacity(0.045))
    }

    // MARK: Pages

    @ViewBuilder private var modelStatus: some View {
        if store.downloadingID == whisperModel {
            HStack(spacing: 8) {
                ProgressView(value: store.progress).frame(width: 90)
                Text("\(Int(store.progress * 100))%").font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary)
                Button("Cancel") { store.cancel() }.buttonStyle(.link)
            }
        } else if store.isInstalled(whisperModel) {
            Label("Installed", systemImage: "checkmark.circle.fill")
                .font(.system(size: 13)).foregroundStyle(.secondary)
        } else {
            Button("Download \(store.size(of: whisperModel))") { store.download(whisperModel) }
                .disabled(store.downloadingID != nil)
        }
    }

    private var recognitionFooter: String {
        if !store.error.isEmpty { return store.error }
        if engine == RecognitionEngine.apple.rawValue { return "Apple’s recognizer is live and needs no download. Whisper is slower but handles accents and technical words better." }
        if WhisperRunner.cliPath() == nil { return "The Whisper engine can’t run on this Mac, so Voicey will use Apple’s recognizer instead." }
        return "Whisper runs fully on your Mac. Silence is trimmed first, so pauses don’t slow it down or make it invent words."
    }

    private var modeFooter: String {
        switch mode {
        case DictationMode.toggle.rawValue: return "Press the shortcut to start, press again to stop. With paste turned off, the text is only copied to the clipboard."
        case DictationMode.hold.rawValue: return "Speak while you hold the shortcut and release to finish. With paste turned off, the text is only copied to the clipboard."
        default: return "Hold it to talk, and release to finish. Press once to start, and again to stop. Double-tap to lock hands-free recording, which keeps going until you press once more. With paste turned off, the text is only copied to the clipboard."
        }
    }

    private var dictationPage: some View {
        DetailPage(title: "Dictation") {
            Card {
                Row(symbol: "command", title: "Shortcut") { ShortcutRecorder() }
                Separator()
                Row(symbol: "hand.tap", title: "Mode") {
                    MenuPicker(selection: $mode, options: [
                        (DictationMode.smart.rawValue, "Tap, hold or double-tap"),
                        (DictationMode.toggle.rawValue, "Press to toggle"),
                        (DictationMode.hold.rawValue, "Hold to talk"),
                    ])
                }
                Separator()
                Row(symbol: "globe", title: "Language") {
                    MenuPicker(selection: $localeID, options: localeOptions)
                }
                Separator()
                SwitchRow(symbol: "text.bubble", title: "Live text pop-up", isOn: $overlay)
                Separator()
                SwitchRow(symbol: "doc.on.clipboard.fill", title: "Paste at cursor", isOn: $autoPaste)
            }
            Footer(text: modeFooter + " A single key works too: click the shortcut, then tap fn, Right \u{2325} or an F-key. If fn opens the emoji picker, set \u{201C}Press \u{1F310} key to\u{201D} to Do Nothing in System Settings \u{2192} Keyboard.")
        }
    }

    private var recognitionPage: some View {
        DetailPage(title: "Recognition") {
            Card {
                Row(symbol: "waveform", title: "Engine") {
                    MenuPicker(selection: $engine, options: [(RecognitionEngine.whisper.rawValue, "Whisper \u{2013} more accurate"), (RecognitionEngine.apple.rawValue, "Apple \u{2013} built in")])
                }
                Group {
                    Separator()
                    Row(symbol: "shippingbox", title: "Whisper model") {
                        MenuPicker(selection: $whisperModel, options: ModelStore.models.map { ($0.id, $0.label) })
                    }
                    Separator()
                    Row(symbol: "arrow.down.circle", title: "Model file") { modelStatus }
                    Separator()
                    SwitchRow(symbol: "scissors", title: "Trim silence", isOn: $trimSilence)
                }
                .disabled(engine == RecognitionEngine.apple.rawValue)
                .opacity(engine == RecognitionEngine.apple.rawValue ? 0.4 : 1)
            }
            Footer(text: recognitionFooter)
        }
    }

    private var currentToolID: AIToolID { AIToolID(rawValue: aiTool) ?? .claude }

    private var modelSelection: Binding<String> {
        switch currentToolID {
        case .claude: return $model
        default: return $codexModel
        }
    }

    @ViewBuilder private var testResult: some View {
        switch tools.tests[currentToolID] {
        case .running: ProgressView().controlSize(.small)
        case .ok(let t): Text("Works: \u{201C}\(t)\u{201D}").font(.system(size: 11)).foregroundStyle(.green).lineLimit(1)
        case .failed(let t): Text(t).font(.system(size: 11)).foregroundStyle(.orange).lineLimit(2).multilineTextAlignment(.trailing)
        case nil: EmptyView()
        }
    }

    private var claudePage: some View {
        DetailPage(title: "AI polish") {
            Card {
                SwitchRow(symbol: "sparkles", title: "Polish with AI", isOn: $polish)
                Group {
                    Separator()
                    Row(symbol: "terminal", title: "Tool") {
                        MenuPicker(selection: $aiTool, options: AITools.all.filter(\.canPolish).map { info in
                            (info.id.rawValue, info.name + (tools.status(info.id)?.usable == false || (tools.status(info.id) == nil && !tools.statuses.isEmpty) ? " \u{2013} not found" : ""))
                        })
                    }
                    Separator()
                    if !tools.statuses.isEmpty && tools.status(currentToolID)?.usable != true {
                        Row(symbol: "arrow.down.circle", title: "\(AITools.info(currentToolID).name) isn\u{2019}t installed") {
                            switch tools.installs[currentToolID] {
                            case .running: HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Installing\u{2026}").font(.system(size: 12)).foregroundStyle(.secondary) }
                            case .failed(let m)?: Button("Try again") { tools.installs[currentToolID] = nil; tools.install(currentToolID) }.help(m)
                            case nil: Button("Install") { tools.install(currentToolID) }
                            }
                        }
                        Separator()
                    }
                    Row(symbol: "cpu", title: "Model") {
                        let options = tools.modelOptions(currentToolID)
                        if options.count > 1 { MenuPicker(selection: modelSelection, options: options) }
                        else { Text(options.first?.label ?? "Default").font(.system(size: 13)).foregroundStyle(.secondary) }
                    }
                    Separator()
                    Row(symbol: "checkmark.seal", title: "Check it works") {
                        HStack(spacing: 8) {
                            testResult
                            Button("Test") { tools.test(currentToolID) }
                        }
                    }
                    Separator()
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            IconTile(symbol: "text.quote")
                            Text("Extra instructions").font(.system(size: 13))
                        }
                        TextEditor(text: $extra)
                            .font(.system(size: 13))
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .frame(height: 64)
                            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(12)
                }
                .disabled(!polish)
                .opacity(polish ? 1 : 0.4)
            }
            Footer(text: "The AI tool fixes misheard words, punctuation and filler, and only ever sees the transcript text. Voicey works with Claude Code and Codex. Extra instructions are added to every cleanup, e.g. \u{201C}formal tone\u{201D} or \u{201C}keep technical terms exactly as spoken\u{201D}.")
        }
        .onAppear { if tools.statuses.isEmpty { tools.rescan() } }
    }

    @ViewBuilder private var updateStatus: some View {
        switch updater.state {
        case .idle:
            Button("Check now") { updater.check(manual: true) }
        case .checking:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Checking\u{2026}").font(.system(size: 12)).foregroundStyle(.secondary) }
        case .upToDate:
            HStack(spacing: 8) {
                Label("Up to date", systemImage: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(.green)
                Button("Check again") { updater.check(manual: true) }
            }
        case .available(let info):
            Button("Install \(info.version) and restart") { updater.install() }.buttonStyle(.borderedProminent)
        case .downloading(let p):
            HStack(spacing: 8) {
                ProgressView(value: p).frame(width: 90)
                Text("\(Int(p * 100))%").font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary)
            }
        case .installing:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Restarting\u{2026}").font(.system(size: 12)).foregroundStyle(.secondary) }
        case .failed(let message):
            HStack(spacing: 8) {
                Text(message).font(.system(size: 11)).foregroundStyle(.orange).lineLimit(3).multilineTextAlignment(.trailing).frame(maxWidth: 220, alignment: .trailing)
                Button("Retry") { updater.check(manual: true) }
            }
        }
    }

    private var generalPage: some View {
        DetailPage(title: "General") {
            Card {
                SwitchRow(symbol: "power", title: "Open at login", isOn: $launchAtLogin)
                Separator()
                SwitchRow(symbol: "dock.rectangle", title: "Show Voicey in the Dock", isOn: $showInDock)
            }
            if !launchError.isEmpty { Footer(text: launchError).foregroundStyle(.red) }
            SectionHeader(text: "Updates")
            Card {
                Row(symbol: "number", title: "Version") {
                    Text("\(Updater.currentVersion)" + (Updater.currentBuild.isEmpty ? "" : " (\(Updater.currentBuild))"))
                        .font(.system(size: 12)).foregroundStyle(.secondary).textSelection(.enabled)
                }
                Separator()
                SwitchRow(symbol: "arrow.triangle.2.circlepath", title: "Check for updates automatically", isOn: $autoUpdate)
                Separator()
                Row(symbol: "arrow.down.app", title: "Status") { updateStatus }
                Separator()
                Row(symbol: "link", title: "Update feed") {
                    TextField(Bundle.main.object(forInfoDictionaryKey: "VoiceyFeedURL") as? String ?? "https://\u{2026}/update.json", text: $updateFeed)
                        .textFieldStyle(.plain).multilineTextAlignment(.trailing).font(.system(size: 12)).frame(maxWidth: 230)
                }
            }
            if case .available(let info) = updater.state, let notes = info.notes, !notes.isEmpty {
                Footer(text: "What\u{2019}s new in \(info.version):\n\(notes)")
            } else {
                Footer(text: "Voicey checks the update feed once a day. Updates are downloaded, checked against a checksum and signature, and installed when you click Install.")
            }
            SectionHeader(text: "Support")
            Card {
                Row(symbol: "doc.text", title: "Activity log") {
                    Button("Show") { NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/Library/Logs/Voicey.log")) }
                }
                Separator()
                Row(symbol: "folder", title: "Whisper models") {
                    Button("Show") { NSWorkspace.shared.open(ModelStore.directory) }
                }
                Separator()
                Row(symbol: "wand.and.stars", title: "Setup") {
                    Button("Run setup again\u{2026}") { OnboardingWindow.shared.show() }
                }
            }
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
            Footer(text: "Voicey \(version). Everything is stored on this Mac; only the transcript text goes to Claude.")
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            Group {
                switch tab {
                case .dictation: dictationPage
                case .recognition: recognitionPage
                case .claude: claudePage
                case .dictionary: DetailPage(title: "Dictionary") { DictionaryPage() }
                case .apps: DetailPage(title: "App tones") { AppTonesPage() }
                case .snippets: DetailPage(title: "Snippets") { SnippetsPage() }
                case .general: generalPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 640, minHeight: 420)
        .onChange(of: mode) { _ in NotificationCenter.default.post(name: .voiceyHotKeyChanged, object: nil) }
        .onChange(of: showInDock) { _ in AppPolicy.update(windowOpen: true) }
        .onChange(of: launchAtLogin) { on in
            do {
                if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                launchError = ""
            } catch {
                launchError = "Couldn\u{2019}t change the login item: \(error.localizedDescription)"
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }
}
