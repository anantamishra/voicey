import AppKit
import Combine

/// Owns the menu-bar item and runs one dictation from shortcut to pasted text.
final class AppDelegate: NSObject, NSApplicationDelegate {
    // Menu bar
    private let barItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let toggleItem = NSMenuItem(title: "Start Dictation", action: #selector(toggle), keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
    private let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(updateAction), keyEquivalent: "")
    private let statusLine = NSMenuItem(title: "Ready", action: nil, keyEquivalent: "")
    private let copyItem = NSMenuItem(title: "Copy Last Transcription", action: #selector(copyLast), keyEquivalent: "c")

    // One dictation
    private let recorder = Recorder()
    private let overlay = Overlay()
    private var recording = false
    private var busy = false                     // transcribing or polishing; ignore the shortcut until done
    private var targetApp: NSRunningApplication? // where the text will be pasted
    private var lastTranscript = Prefs.d.string(forKey: Prefs.lastTranscript) ?? ""

    // Shortcut
    private var hotKey: HotKey?
    private var modifierKey: ModifierHotKey?
    private var gesture = GestureMachine()
    private var graceWork: DispatchWorkItem?
    private let clapListener = ClapListener()
    private var stopAt = Date(), heardAt = Date(), lastRaw = ""     // for the timing line in the log

    private var cancellables = Set<AnyCancellable>()

    // MARK: Launch

    func applicationDidFinishLaunching(_ note: Notification) {
        Prefs.register()
        scrubOldLogOnce()
        buildMainMenu()
        buildMenu()
        setIcon(.idle)
        wireRecorder()
        setUpShortcut()
        setUpClapListener()
        startBackgroundWork()
        showFirstRunScreens()
    }

    /// The standard Mac menu bar. Without an Edit menu, ⌘C / ⌘V would not work in Voicey's own text fields.
    private func buildMainMenu() {
        let name = "Voicey"
        let main = NSMenu()

        func add(_ title: String, to menu: NSMenu, _ action: Selector?, _ key: String = "", target: AnyObject? = nil,
                 modifiers: NSEvent.ModifierFlags = .command) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = modifiers
            item.target = target
            menu.addItem(item)
        }
        func submenu(_ title: String, fill: (NSMenu) -> Void) -> NSMenu {
            let menu = NSMenu(title: title)
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = menu
            main.addItem(item)
            fill(menu)
            return menu
        }

        _ = submenu(name) { m in
            add("About \(name)", to: m, #selector(NSApplication.orderFrontStandardAboutPanel(_:)))
            m.addItem(.separator())
            add("Settings…", to: m, #selector(openSettings), ",", target: self)
            add("Check for Updates…", to: m, #selector(updateAction), target: self)
            m.addItem(.separator())
            add("Hide \(name)", to: m, #selector(NSApplication.hide(_:)), "h")
            add("Hide Others", to: m, #selector(NSApplication.hideOtherApplications(_:)), "h", modifiers: [.command, .option])
            add("Show All", to: m, #selector(NSApplication.unhideAllApplications(_:)))
            m.addItem(.separator())
            add("Quit \(name)", to: m, #selector(NSApplication.terminate(_:)), "q")
        }
        _ = submenu("Edit") { m in
            add("Undo", to: m, Selector(("undo:")), "z")
            add("Redo", to: m, Selector(("redo:")), "z", modifiers: [.command, .shift])
            m.addItem(.separator())
            add("Cut", to: m, #selector(NSText.cut(_:)), "x")
            add("Copy", to: m, #selector(NSText.copy(_:)), "c")
            add("Paste", to: m, #selector(NSText.paste(_:)), "v")
            add("Select All", to: m, #selector(NSText.selectAll(_:)), "a")
        }
        let windows = submenu("Window") { m in
            add("Minimize", to: m, #selector(NSWindow.performMiniaturize(_:)), "m")
            add("Zoom", to: m, #selector(NSWindow.performZoom(_:)))
            add("Close", to: m, #selector(NSWindow.performClose(_:)), "w")
        }
        NSApp.mainMenu = main
        NSApp.windowsMenu = windows
    }

    /// Clicking the Dock icon (or opening the app again) brings up Settings, like any regular Mac app.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { SettingsWindow.shared.show() }
        return true
    }

    /// Closing the last window must not quit: Voicey keeps listening for its shortcut.
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { false }

    private func buildMenu() {
        [toggleItem, settingsItem, updateItem, copyItem].forEach { $0.target = self }
        statusLine.isEnabled = false
        copyItem.keyEquivalentModifierMask = [.command, .shift]
        copyItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")
        copyItem.isEnabled = !lastTranscript.isEmpty

        let menu = NSMenu()
        menu.addItem(toggleItem)
        menu.addItem(settingsItem)
        menu.addItem(updateItem)
        menu.addItem(.separator())
        menu.addItem(statusLine)
        menu.addItem(copyItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Voicey", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        barItem.menu = menu

        Updater.shared.$state.receive(on: DispatchQueue.main).sink { [weak self] in self?.showUpdate($0) }.store(in: &cancellables)
    }

    private func wireRecorder() {
        recorder.onPartial = { [weak self] text in self?.overlay.update(text: text) }      // live words go to the pop-up only
        recorder.onStatus = { [weak self] text in
            self?.setStatus(text)
            if text.hasPrefix("Transcribing") { self?.overlay.set(.transcribing) }
        }
        recorder.onLevel = { [weak self] level in self?.overlay.update(level: level) }
        recorder.onFinish = { [weak self] raw in self?.finished(raw) }
        recorder.onSilence = { [weak self] in
            guard let self, self.recording else { return }
            vlog("silence: stopping automatically")
            self.stopRecording()
        }
    }

    private func setUpShortcut() {
        hotKey = HotKey(onPress: { [weak self] in self?.hotKeyPressed() }, onRelease: { [weak self] in self?.hotKeyReleased() })
        applyHotKey()
        let center = NotificationCenter.default
        center.addObserver(forName: .voiceyHotKeyChanged, object: nil, queue: .main) { [weak self] _ in self?.applyHotKey() }
        // While the Settings recorder listens for a new shortcut, the current one must not fire.
        center.addObserver(forName: .voiceyHotKeyPause, object: nil, queue: .main) { [weak self] _ in
            self?.hotKey?.unregister()
            self?.modifierKey?.stop()
            self?.modifierKey = nil
        }
    }

    /// A double clap starts a hands-free dictation. The listener only runs while idle, because Voicey's recorder needs the mic.
    private func setUpClapListener() {
        clapListener.onDoubleClap = { [weak self] in
            guard let self, !self.recording, !self.busy else { return }
            vlog("double clap")
            self.startRecording()
            if self.recording {
                self.overlay.setLocked(true)
                self.toggleItem.title = "Stop Dictation (press \(HotKeyOption.current.label))"
            }
        }
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshClapListener()
        }
        refreshClapListener()
    }

    private func refreshClapListener() {
        let wanted = Prefs.d.bool(forKey: Prefs.clapToStart) && !recording && !busy
        if wanted { clapListener.start() } else { clapListener.stop() }
    }

    private func startBackgroundWork() {
        DispatchQueue.global().async {
            vlog("whisper engine: \(WhisperRunner.cliPath() ?? "none") (built in: \(WhisperRunner.isBundled))")
        }
        // Look for updates a little after launch, then every few hours (it only really checks once a day).
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { Updater.shared.checkIfDue() }
        Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { _ in Updater.shared.checkIfDue() }
        // The first transcription after a fresh start spends a few seconds preparing the GPU; do that now, quietly.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 6) {
            guard RecognitionEngine.current == .whisper, WhisperRunner.cliPath() != nil,
                  ModelStore.shared.isInstalled(ModelStore.currentID) else { return }
            let started = Date()
            _ = WhisperRunner.transcribe([Float](repeating: 0, count: 16_000), modelPath: ModelStore.shared.path(ModelStore.currentID),
                                         language: ModelStore.language(for: ModelStore.currentID))
            vlog("engine warm-up took \(String(format: "%.1f", Date().timeIntervalSince(started)))s")
        }
    }

    private func showFirstRunScreens() {
        if Prefs.d.bool(forKey: Prefs.onboardingDone) {
            Recorder.requestPermissions { ok in
                vlog("permissions granted: \(ok)")
                if !ok { DispatchQueue.main.async { self.setStatus("Allow Microphone + Speech Recognition in System Settings") } }
            }
        } else {
            // The setup screen asks for each permission with an explanation, so don't pre-empt it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { OnboardingWindow.shared.show() }
        }
    }

    // MARK: Shortcut

    private var idleTitle: String { "Start Dictation (\(HotKeyOption.current.label))" }

    private func hotKeyPressed() {
        let mode = DictationMode.current
        vlog("hotkey pressed (mode=\(mode.rawValue))")
        switch mode {
        case .hold: if !recording && !busy { startRecording() }
        case .toggle: toggle()
        case .smart:
            guard !busy else { return }
            apply(gesture.press(at: Date(), recording: recording))
        }
    }

    private func hotKeyReleased() {
        switch DictationMode.current {
        case .hold: if recording { vlog("hotkey released"); stopRecording() }
        case .toggle: break
        case .smart: apply(gesture.release(at: Date()))
        }
    }

    private func apply(_ action: GestureMachine.Action) {
        switch action {
        case .none: break
        case .start: startRecording()
        case .stop: stopRecording()
        case .lock:
            vlog("gesture: hands-free lock")
            overlay.setLocked(true)
            toggleItem.title = "Stop Dictation (press \(HotKeyOption.current.label))"
        case .scheduleGrace:
            graceWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.apply(self.gesture.graceExpired())
            }
            graceWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + GestureMachine.graceWindow, execute: work)
        }
    }

    /// (Re)registers the saved shortcut: a lone modifier key is watched, anything else is a system hotkey.
    private func applyHotKey() {
        let shortcut = HotKeyOption.current
        modifierKey?.stop()
        modifierKey = nil
        if shortcut.isModifierKey {
            hotKey?.unregister()
            let watcher = ModifierHotKey(keyCode: shortcut.keyCode,
                                         onPress: { [weak self] in self?.hotKeyPressed() },
                                         onRelease: { [weak self] in self?.hotKeyReleased() },
                                         onAbort: { [weak self] in self?.abortRecording() })
            watcher.start()
            modifierKey = watcher
        } else {
            hotKey?.register(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)
        }
        if !recording && !busy { toggleItem.title = idleTitle }
    }

    // MARK: One dictation

    @objc private func toggle() {
        vlog("toggle: recording=\(recording) busy=\(busy)")
        guard !busy else { return }
        recording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        let front = NSWorkspace.shared.frontmostApplication
        targetApp = front?.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : front
        clapListener.stop()
        do {
            try recorder.start()
            recording = true
            setIcon(.recording)
            let label = HotKeyOption.current.label
            toggleItem.title = DictationMode.current == .hold ? "Stop Dictation (release \(label))" : "Stop Dictation (\(label))"
            setStatus("Listening…")
            overlay.show()
        } catch {
            setStatus("Error: \(error.localizedDescription)")
            overlay.show()
            overlay.finish("Error: \(error.localizedDescription)", success: false)
            refreshClapListener()
        }
    }

    private func stopRecording() {
        endGestureState()
        recording = false
        busy = true
        stopAt = Date()
        setIcon(.working)
        toggleItem.title = "Working…"
        recorder.stop()
    }

    /// The lone modifier key was really the start of another shortcut: drop the recording.
    private func abortRecording() {
        guard recording else { return }
        vlog("recording aborted: modifier was used in another shortcut")
        endGestureState()
        recorder.cancel()
        recording = false
        overlay.hide()
        setIcon(.idle)
        toggleItem.title = idleTitle
        setStatus("Ready")
        refreshClapListener()
    }

    private func endGestureState() {
        graceWork?.cancel()
        gesture.reset()
        overlay.setLocked(false)
    }

    /// Raw transcript in, pasted text out: snippets are set aside, the AI tool polishes the rest, snippets go back in.
    private func finished(_ raw: String) {
        let personal = Personalization.shared
        guard TextPolisher.hasRealWords(raw) else { return deliver("") }
        heardAt = Date(); lastRaw = raw
        let prepared = personal.protect(raw)
        if prepared.onlySnippets || !Prefs.d.bool(forKey: Prefs.polish) || prepared.text.isEmpty {
            return deliver(personal.expand(prepared.text, prepared))
        }
        let tone = personal.tone(forBundleID: targetApp?.bundleIdentifier)
        if TextPolisher.canSkipAI(prepared.text, tone: tone?.prompt) {
            vlog("polish skipped: short and already clean")
            return deliver(personal.expand(prepared.text, prepared))
        }
        setStatus("\(TextPolisher.displayName) is polishing…")
        overlay.set(.polishing)
        vlog("polish: app=\(targetApp?.localizedName ?? "?") tone=\(tone?.prompt ?? "none")")
        TextPolisher.clean(prepared.text, appName: tone?.appName ?? targetApp?.localizedName, tone: tone?.prompt) { [weak self] cleaned in
            // If the tool dropped a placeholder, use the unpolished text rather than lose a snippet.
            let intact = prepared.tokens.allSatisfy { cleaned.contains($0.token) }
            self?.deliver(personal.expand(intact ? cleaned : prepared.text, prepared))
        }
    }

    private func deliver(_ text: String) {
        if text.isEmpty {
            setStatus("Nothing heard")
        } else {
            Paster.paste(text)
            Learning.shared.record(raw: lastRaw, final: text, app: targetApp)
            Learning.shared.watchEdits(of: text)
            lastTranscript = text
            Prefs.d.set(text, forKey: Prefs.lastTranscript)
            copyItem.isEnabled = true
            setStatus("Ready")
        }
        overlay.finish(text.isEmpty ? "Nothing heard" : text, success: !text.isEmpty)
        let now = Date()
        vlog(String(format: "timing: transcribe %.1fs, polish %.1fs, total %.1fs", heardAt.timeIntervalSince(stopAt), now.timeIntervalSince(heardAt),
                    now.timeIntervalSince(stopAt)))
        busy = false
        setIcon(.idle)
        toggleItem.title = idleTitle
        refreshClapListener()
    }

    // MARK: Menu actions and display

    @objc private func openSettings() { SettingsWindow.shared.show() }

    @objc private func copyLast() {
        guard !lastTranscript.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastTranscript, forType: .string)
        copyItem.title = "Copied"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.copyItem.title = "Copy Last Transcription" }
    }

    @objc private func updateAction() {
        if case .available = Updater.shared.state { Updater.shared.install() } else { Updater.shared.check(manual: true) }
    }

    private func showUpdate(_ state: Updater.State) {
        var enabled = true
        switch state {
        case .idle: updateItem.title = "Check for Updates…"
        case .checking: updateItem.title = "Checking for Updates…"; enabled = false
        case .upToDate: updateItem.title = "Voicey Is Up to Date (v\(Updater.currentVersion))"
        case .available(let info): updateItem.title = "Update to \(info.version)…"
        case .downloading(let p): updateItem.title = "Downloading Update… \(Int(p * 100))%"; enabled = false
        case .installing: updateItem.title = "Restarting…"; enabled = false
        case .failed: updateItem.title = "Update Failed — Try Again…"
        }
        updateItem.isEnabled = enabled
    }

    private enum BarIcon { case idle, recording, working }

    private func setIcon(_ icon: BarIcon) {
        switch icon {
        case .idle: barItem.button?.image = MenuBarIcon.make(recording: false)
        case .recording: barItem.button?.image = MenuBarIcon.make(recording: true)
        case .working:
            let image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "Voicey")
            image?.isTemplate = true
            barItem.button?.image = image
        }
    }

    /// The menu's status line shows what Voicey is doing, never what you said.
    private func setStatus(_ text: String) {
        statusLine.title = text.isEmpty ? "—" : (text.count > 80 ? "…" + text.suffix(80) : text)
    }
}
