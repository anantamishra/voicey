import AppKit
import SwiftUI

/// Click, then press the keys you want. Esc cancels.
struct ShortcutRecorder: View {
    @State private var current = HotKeyOption.current
    @State private var capturing = false
    @State private var monitor: Any?
    @State private var message = ""
    @State private var pendingModifier: Int?

    var body: some View {
        HStack(spacing: 8) {
            if !message.isEmpty {
                Text(message).font(.system(size: 11)).foregroundStyle(.red).lineLimit(2).multilineTextAlignment(.trailing)
            }
            Button(action: { capturing ? stop() : begin() }) {
                Text(capturing ? "Press shortcut\u{2026}" : current.label)
                    .font(.system(size: 13, weight: .medium))
                    .frame(minWidth: 104)
            }
            .tint(capturing ? Color.accentColor : nil)
            .help("Click, then press the key combination you want")
            if !current.isDefault && !capturing {
                Button {
                    HotKeyOption.reset()
                    current = HotKeyOption.current
                    message = ""
                    NotificationCenter.default.post(name: .voiceyHotKeyChanged, object: nil)
                } label: { Image(systemName: "arrow.counterclockwise") }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Reset to \(HotKeyOption.default.label)")
            }
        }
        .onDisappear { if capturing { stop() } }
    }

    private func begin() {
        message = ""
        capturing = true
        // Let go of the live shortcut so pressing it is captured here instead of starting a dictation.
        NotificationCenter.default.post(name: .voiceyHotKeyPause, object: nil)
        pendingModifier = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handle(event)
            return nil                                  // swallow the key while recording a shortcut
        }
    }

    private func handle(_ e: NSEvent) {
        if e.type == .flagsChanged { return handleModifier(e) }
        pendingModifier = nil                                                  // a real key came in: this is a combination
        let flags = e.modifierFlags.intersection([.command, .option, .control, .shift])
        let code = Int(e.keyCode)
        if code == 53 && flags.isEmpty { stop(); return }                     // Esc cancels
        let isFunctionKey = HotKeyOption.functionKeys.contains(code)
        if !isFunctionKey && (flags.isEmpty || flags == [.shift]) {
            message = "Add \u{2303}, \u{2325} or \u{2318}, or use fn / F-key"
            return
        }
        let mods = HotKeyOption.carbonModifiers(flags)
        guard HotKey.canRegister(keyCode: code, modifiers: mods) else {
            message = "macOS already uses that one"
            return
        }
        let option = HotKeyOption(id: "custom", label: HotKeyOption.label(keyCode: code, modifiers: mods, characters: e.charactersIgnoringModifiers),
                                  keyCode: code, modifiers: mods)
        HotKeyOption.save(option)
        current = option
        message = ""
        stop()
    }

    /// A modifier pressed and released on its own (no other key between) becomes a one-button shortcut.
    private func handleModifier(_ e: NSEvent) {
        let code = Int(e.keyCode)
        guard let flag = ModifierHotKey.flag(for: code) else { return }
        let held = e.modifierFlags.intersection([.command, .option, .control, .shift, .function])
        if held.contains(flag) {
            pendingModifier = code
        } else if pendingModifier == code && held.isEmpty {
            guard let name = HotKeyOption.modifierNames[code] else { return }
            let option = HotKeyOption(id: "custom", label: name, keyCode: code, modifiers: 0)
            HotKeyOption.save(option)
            current = option
            message = ""
            pendingModifier = nil
            stop()
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        capturing = false
        NotificationCenter.default.post(name: .voiceyHotKeyChanged, object: nil)   // re-register the (possibly new) shortcut
    }
}
