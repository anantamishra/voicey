import AppKit
import AVFoundation
import Combine
import Speech
import SwiftUI

private enum Access { case granted, notAsked, denied }

struct OnboardingView: View {
    enum Step: Int, CaseIterable { case welcome, access, ai, transcription, done }

    @State private var step: Step = .welcome
    @ObservedObject private var tools = AIToolStore.shared
    @ObservedObject private var whisper = ModelStore.shared
    @AppStorage(Prefs.aiTool) private var aiTool = "claude"
    @AppStorage(Prefs.claudeModel) private var claudeModel = "haiku"
    @AppStorage(Prefs.codexModel) private var codexModel = ""
    @AppStorage(Prefs.polish) private var polish = true
    @AppStorage(Prefs.engine) private var engine = RecognitionEngine.whisper.rawValue
    @AppStorage(Prefs.whisperModel) private var whisperModel = "base.en"
    @State private var mic = Access.notAsked
    @State private var speech = Access.notAsked
    @State private var accessibility = Access.notAsked
    @State private var installing = false
    @State private var installNote = ""
    @State private var refresh = 0                       // bump to re-read things that aren't observable
    let finish: () -> Void

    init(startStep: Step = .welcome, finish: @escaping () -> Void) {
        _step = State(initialValue: startStep)
        self.finish = finish
    }

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: Frame

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                ForEach(Step.allCases, id: \.rawValue) { s in
                    Capsule().fill(s.rawValue <= step.rawValue ? Color.accentColor : Color.primary.opacity(0.15))
                        .frame(width: s == step ? 22 : 8, height: 6)
                }
            }
            .padding(.top, 38).padding(.bottom, 6)
            .animation(.easeOut(duration: 0.2), value: step)

            ScrollView {
                Group {
                    switch step {
                    case .welcome: welcome
                    case .access: access
                    case .ai: aiTools
                    case .transcription: transcription
                    case .done: done
                    }
                }
                .padding(.horizontal, 30).padding(.top, 14).padding(.bottom, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                if step != .welcome { Button("Back") { go(-1) } }
                Spacer()
                if step == .done {
                    Button("Start using Voicey") { finish() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                } else {
                    Button(step == .welcome ? "Get started" : "Continue") { go(1) }
                        .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                }
            }
            .controlSize(.large)
            .padding(.horizontal, 30).padding(.vertical, 16)
        }
        .frame(width: 640, height: 620)
        .onAppear {
            refreshAccess()
            if tools.statuses.isEmpty { tools.rescan { autoSelectTool() } }
        }
        .onReceive(timer) { _ in refreshAccess() }
        .onChange(of: step) { newStep in
            // Fetch the speech model for them the moment they reach this step.
            if newStep == .transcription, engine == RecognitionEngine.whisper.rawValue, whisperInstalled, !whisper.isInstalled(whisperModel), whisper.downloadingID == nil {
                whisper.download(whisperModel)
            }
        }
    }

    private func go(_ d: Int) {
        if let next = Step(rawValue: step.rawValue + d) { withAnimation { step = next } }
    }

    private func heading(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 24, weight: .bold))
            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 14)
    }

    // MARK: 1. Welcome

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 84, height: 84).padding(.top, 14)
            heading("Welcome to Voicey", "Talk instead of typing, in any app. Voicey turns your speech into text on this Mac, polishes it with an AI tool you already have, and types it where your cursor is.")
            Card {
                Row(symbol: "mic", title: "Speak") { Text("hold, tap or double-tap a key").font(.system(size: 12)).foregroundStyle(.secondary) }
                Separator()
                Row(symbol: "waveform", title: "Transcribe") { Text("on your Mac, nothing uploaded").font(.system(size: 12)).foregroundStyle(.secondary) }
                Separator()
                Row(symbol: "sparkles", title: "Polish") { Text("with Claude or Codex").font(.system(size: 12)).foregroundStyle(.secondary) }
                Separator()
                Row(symbol: "text.cursor", title: "Paste") { Text("right at your cursor").font(.system(size: 12)).foregroundStyle(.secondary) }
            }
            Footer(text: "Setup takes about a minute. You can change everything later in Settings.")
        }
    }

    // MARK: 2. Permissions

    private func map(_ s: AVAuthorizationStatus) -> Access { s == .authorized ? .granted : (s == .notDetermined ? .notAsked : .denied) }

    private func refreshAccess() {
        mic = map(AVCaptureDevice.authorizationStatus(for: .audio))
        let sp = SFSpeechRecognizer.authorizationStatus()
        speech = sp == .authorized ? .granted : (sp == .notDetermined ? .notAsked : .denied)
        accessibility = AXIsProcessTrusted() ? .granted : .notAsked
        refresh += 1
    }

    private func openPane(_ name: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(name)")!)
    }

    @ViewBuilder private func accessRow(_ symbol: String, _ title: String, _ why: String, _ state: Access, _ action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            IconTile(symbol: symbol)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13))
                Text(why).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if state == .granted {
                Label("Allowed", systemImage: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(.green)
            } else {
                Button(state == .denied ? "Open Settings" : "Allow", action: action)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8).frame(minHeight: 44)
    }

    private var access: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("Allow access", "Voicey needs three permissions. macOS asks for each one, and you can change them later in System Settings.")
            Card {
                accessRow("mic", "Microphone", "To hear you while you dictate.", mic) {
                    if mic == .notAsked { AVCaptureDevice.requestAccess(for: .audio) { _ in } } else { openPane("Privacy_Microphone") }
                }
                Separator()
                accessRow("ear", "Speech Recognition", "For the live preview while you talk.", speech) {
                    if speech == .notAsked { SFSpeechRecognizer.requestAuthorization { _ in } } else { openPane("Privacy_SpeechRecognition") }
                }
                Separator()
                accessRow("keyboard", "Accessibility", "To paste the text at your cursor and watch your shortcut.", accessibility) {
                    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                    _ = AXIsProcessTrustedWithOptions(opts)
                    openPane("Privacy_Accessibility")
                }
            }
            Footer(text: "Without Accessibility, Voicey can still transcribe, but it can only copy the text, and you have to paste it yourself. After you switch it on, you may need to reopen Voicey.")
        }
    }

    // MARK: 3. AI tools

    private func autoSelectTool() {
        if tools.status(AIToolID(rawValue: aiTool) ?? .claude)?.usable == true { return }
        if let first = [AIToolID.claude, .codex].first(where: { tools.status($0)?.usable == true }) {
            aiTool = first.rawValue
        } else if !tools.statuses.isEmpty {
            polish = false                                   // nothing to polish with yet
        }
    }

    private func modelBinding(_ id: AIToolID) -> Binding<String> {
        switch id {
        case .claude: return $claudeModel
        default: return $codexModel
        }
    }

    private func badge(_ text: String, _ good: Bool) -> some View {
        Text(text).font(.system(size: 10.5, weight: .medium))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .foregroundStyle(good ? Color.green : Color.secondary)
            .background((good ? Color.green : Color.primary).opacity(0.12), in: Capsule())
    }

    @ViewBuilder private func toolIcon(_ s: ToolStatus) -> some View {
        if let app = s.appPath {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app)).resizable().frame(width: 30, height: 30)
        } else if s.path?.contains(".app/") == true, let app = s.path.flatMap({ $0.components(separatedBy: ".app/").first.map { $0 + ".app" } }) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app)).resizable().frame(width: 30, height: 30)
        } else {
            Image(systemName: s.info.symbol).font(.system(size: 15)).foregroundStyle(.secondary).frame(width: 30, height: 30)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }

    @ViewBuilder private func testLine(_ id: AIToolID) -> some View {
        switch tools.tests[id] {
        case .running: HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Testing…").font(.system(size: 11)).foregroundStyle(.secondary) }
        case .ok(let t): Label("Works: \u{201C}\(t)\u{201D}", systemImage: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(.green).lineLimit(2)
        case .failed(let t): Label(t, systemImage: "exclamationmark.triangle.fill").font(.system(size: 11)).foregroundStyle(.orange).lineLimit(3)
        case nil: EmptyView()
        }
    }

    private func needsSignIn(_ id: AIToolID) -> Bool {
        if case .failed(let m)? = tools.tests[id] { return ToolInstaller.looksLikeAuthProblem(m) }
        return false
    }

    @ViewBuilder private func installControl(_ s: ToolStatus) -> some View {
        switch tools.installs[s.id] {
        case .running:
            VStack(alignment: .trailing, spacing: 4) {
                ProgressView().controlSize(.small)
                Text("Installing…").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        case .failed(let message)?:
            VStack(alignment: .trailing, spacing: 4) {
                Button("Try again") { tools.installs[s.id] = nil; tools.install(s.id) }.controlSize(.small)
                Text(message).font(.system(size: 10.5)).foregroundStyle(.orange).lineLimit(3).multilineTextAlignment(.trailing).frame(maxWidth: 190, alignment: .trailing)
            }
        case nil:
            Button("Install") { tools.install(s.id) }.controlSize(.small).buttonStyle(.borderedProminent)
        }
    }

    private func toolCard(_ s: ToolStatus) -> some View {
        let selected = aiTool == s.id.rawValue && s.usable
        return HStack(alignment: .top, spacing: 12) {
            toolIcon(s)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(s.info.name).font(.system(size: 13.5, weight: .semibold))
                    Text(s.info.maker).font(.system(size: 12)).foregroundStyle(.secondary)
                    badge(s.found ? "Detected" : "Not installed", s.found)
                }
                if s.found, let v = s.version { Text(v).font(.system(size: 11)).foregroundStyle(.secondary) }
                if !s.detail.isEmpty { Text(s.detail).font(.system(size: 11)).foregroundStyle(.secondary) }
                if s.found && !s.models.isEmpty && s.detail.isEmpty {
                    Text("Models: " + s.models.map { AITools.modelLabel(s.id, $0).components(separatedBy: " \u{2013} ")[0] }.joined(separator: ", "))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                if s.found && !s.info.canPolish { Text(s.info.limitation).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                if !s.found, s.info.canPolish, let src = ToolInstaller.command(for: s.id)?.source {
                    Text("Installs in the background from \(src). No password needed.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                if s.usable { testLine(s.id) }
            }
            Spacer(minLength: 8)
            if s.usable {
                VStack(alignment: .trailing, spacing: 8) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18)).foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    if tools.signingIn.contains(s.id) {
                        HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Finish in your browser").font(.system(size: 11)).foregroundStyle(.secondary) }
                    } else if needsSignIn(s.id) {
                        Button("Sign in") { tools.signIn(s.id) }.controlSize(.small).buttonStyle(.borderedProminent)
                    } else {
                        Button("Test") { tools.test(s.id) }.controlSize(.small)
                    }
                }
            } else if !s.found && s.info.canPolish {
                installControl(s)
            }
        }
        .padding(12)
        .contentShape(Rectangle())
        .onTapGesture { if s.usable { aiTool = s.id.rawValue; polish = true } }
    }

    private var aiTools: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("Choose an AI tool", "Voicey uses a tool you already have to fix punctuation, filler words and misheard names. Only the transcript text is sent to it.")
            if tools.statuses.isEmpty {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Looking for AI tools…").font(.system(size: 13)).foregroundStyle(.secondary) }.padding(.vertical, 20)
            } else {
                Card {
                    ForEach(Array(tools.statuses.enumerated()), id: \.element.id) { i, s in
                        toolCard(s)
                        if i < tools.statuses.count - 1 { Separator() }
                    }
                }
                if let sel = tools.status(AIToolID(rawValue: aiTool) ?? .claude), sel.usable {
                    SectionHeader(text: "\(sel.info.name) model")
                    Card {
                        let options = tools.modelOptions(sel.id)
                        Row(symbol: "cpu", title: "Model") {
                            if options.count > 1 { MenuPicker(selection: modelBinding(sel.id), options: options) }
                            else { Text(options.first?.label ?? "Default").font(.system(size: 13)).foregroundStyle(.secondary) }
                        }
                        Separator()
                        SwitchRow(symbol: "sparkles", title: "Polish transcripts with AI", isOn: $polish)
                    }
                } else if tools.statuses.contains(where: { $0.found }) || !tools.statuses.isEmpty {
                    Footer(text: "No usable tool found yet. Voicey will paste the raw transcript until you install Claude Code or Codex.")
                }
                HStack {
                    Button { tools.rescan { autoSelectTool() } } label: { Label("Scan again", systemImage: "arrow.clockwise") }
                        .buttonStyle(.link).font(.system(size: 12)).disabled(tools.scanning)
                    if tools.scanning { ProgressView().controlSize(.small) }
                    Spacer()
                }
                .padding(.horizontal, 4).padding(.top, 10)
            }
        }
    }

    // MARK: 4. Transcription model

    private var whisperInstalled: Bool { _ = refresh; return WhisperRunner.cliPath() != nil }

    private func installWhisper() {
        guard let brew = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            installNote = "Homebrew isn’t installed. Get it from brew.sh, then come back and press Install."
            return
        }
        installing = true
        installNote = "Installing… this can take a minute."
        DispatchQueue.global(qos: .userInitiated).async {
            let r = Shell.run(brew, ["install", "whisper-cpp"], env: ["HOMEBREW_NO_AUTO_UPDATE": "1", "HOMEBREW_NO_ENV_HINTS": "1"], timeout: 900)
            DispatchQueue.main.async {
                installing = false
                let last = r.err.split(whereSeparator: \.isNewline).last.map(String.init) ?? ""
                installNote = r.code == 0 ? "Installed." : "Install failed: \(last)"
                refresh += 1
            }
        }
    }

    @ViewBuilder private var modelStatus: some View {
        if whisper.downloadingID == whisperModel {
            HStack(spacing: 8) {
                ProgressView(value: whisper.progress).frame(width: 90)
                Text("\(Int(whisper.progress * 100))%").font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary)
                Button("Cancel") { whisper.cancel() }.buttonStyle(.link).font(.system(size: 12))
            }
        } else if whisper.isInstalled(whisperModel) {
            Label("Downloaded", systemImage: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(.green)
        } else {
            Button("Download \(whisper.size(of: whisperModel))") { whisper.download(whisperModel) }.disabled(whisper.downloadingID != nil)
        }
    }

    private var transcription: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("Set up transcription", WhisperRunner.isBundled
                    ? "Whisper turns your voice into text right on this Mac. The engine is already built into Voicey; it only needs a speech model, which downloads automatically. Prefer no download? Apple’s built-in recognizer works instantly."
                    : "Whisper turns your voice into text right on this Mac. It needs a small program and a speech model. If you’d rather skip it, Apple’s built-in recognizer works with no download.")
            Card {
                Row(symbol: "terminal", title: "Whisper engine") {
                    if whisperInstalled {
                        Label(WhisperRunner.isBundled ? "Built in" : "Installed", systemImage: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(.green)
                    } else if installing {
                        HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Installing…").font(.system(size: 12)).foregroundStyle(.secondary) }
                    } else {
                        Button("Install") { installWhisper() }
                    }
                }
                if !whisperInstalled {
                    Text("Runs: brew install whisper-cpp").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                        .padding(.horizontal, 12).padding(.bottom, 8)
                }
                Separator()
                Row(symbol: "shippingbox", title: "Speech model") { MenuPicker(selection: $whisperModel, options: ModelStore.models.map { ($0.id, $0.label) }) }
                Separator()
                Row(symbol: "arrow.down.circle", title: "Model file") { modelStatus }
            }
            if !installNote.isEmpty { Footer(text: installNote) }
            if !whisper.error.isEmpty { Footer(text: whisper.error).foregroundStyle(.red) }
            SectionHeader(text: "Or skip Whisper")
            Card {
                SwitchRow(symbol: "apple.logo", title: "Use Apple’s recognizer instead", isOn: Binding(get: { engine == RecognitionEngine.apple.rawValue }, set: { engine = ($0 ? RecognitionEngine.apple : .whisper).rawValue }))
            }
            Footer(text: "Base (English) is a 148 MB download and fast. Choose Large Turbo if you speak another language. Whisper is more accurate with accents and technical words; Apple’s is instant and needs no setup.")
        }
    }

    // MARK: 5. Done

    private var transcriptionSummary: String {
        if engine == RecognitionEngine.apple.rawValue { return "Apple’s recognizer" }
        let model = ModelStore.models.first { $0.id == whisperModel }?.label.components(separatedBy: " \u{2013} ")[0] ?? whisperModel
        if whisperInstalled && whisper.isInstalled(whisperModel) { return "Whisper \u{00B7} \(model)" }
        return "Whisper isn’t ready, so Apple’s recognizer will be used"
    }

    private var polishSummary: String {
        guard polish, let id = AIToolID(rawValue: aiTool), tools.status(id)?.usable == true else { return "Off (raw transcript)" }
        let m = modelBinding(id).wrappedValue
        return AITools.info(id).name + (m.isEmpty ? "" : " \u{00B7} " + AITools.modelLabel(id, m).components(separatedBy: " \u{2013} ")[0])
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("You’re all set", "Here’s what Voicey will use. Everything can be changed in Settings.")
            Card {
                Row(symbol: "waveform", title: "Transcription") { Text(transcriptionSummary).font(.system(size: 12)).foregroundStyle(.secondary) }
                Separator()
                Row(symbol: "sparkles", title: "Polish") { Text(polishSummary).font(.system(size: 12)).foregroundStyle(.secondary) }
                Separator()
                Row(symbol: "command", title: "Shortcut") { Text(HotKeyOption.current.label).font(.system(size: 12)).foregroundStyle(.secondary) }
                Separator()
                Row(symbol: "keyboard", title: "Paste at cursor") {
                    Text(accessibility == .granted ? "Ready" : "Needs Accessibility").font(.system(size: 12))
                        .foregroundStyle(accessibility == .granted ? Color.secondary : Color.orange)
                }
            }
            SectionHeader(text: "How to use it")
            Card {
                Row(symbol: "hand.tap", title: "Hold the shortcut") { Text("talk, release to finish").font(.system(size: 12)).foregroundStyle(.secondary) }
                Separator()
                Row(symbol: "1.circle", title: "Press once") { Text("start, press again to stop").font(.system(size: 12)).foregroundStyle(.secondary) }
                Separator()
                Row(symbol: "lock", title: "Double-tap") { Text("hands-free until you press again").font(.system(size: 12)).foregroundStyle(.secondary) }
            }
        }
    }
}
