import AppKit
import ApplicationServices

enum Paster {
    /// Puts text on the clipboard and types ⌘V into the app that has focus (needs Accessibility permission).
    static func paste(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)

        guard Prefs.d.bool(forKey: Prefs.autoPaste) else { vlog("paste: auto-paste off, clipboard only"); return }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        vlog("paste: trusted=\(trusted) chars=\(text.count)")
        guard trusted else { return } // text stays on the clipboard

        // Give the pasteboard a moment, then send a real key sequence: ⌘ down, V down, V up, ⌘ up.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let src = CGEventSource(stateID: .hidSystemState)
            let cmd: CGKeyCode = 55, v: CGKeyCode = 9
            let steps: [(CGKeyCode, Bool, CGEventFlags)] = [
                (cmd, true, .maskCommand), (v, true, .maskCommand),
                (v, false, .maskCommand), (cmd, false, []),
            ]
            for (i, step) in steps.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01 * Double(i)) {
                    let e = CGEvent(keyboardEventSource: src, virtualKey: step.0, keyDown: step.1)
                    e?.flags = step.2
                    e?.post(tap: .cghidEventTap)
                }
            }
            vlog("paste: ⌘V sent to \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "?")")
        }
    }
}
