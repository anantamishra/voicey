import AppKit

/// Decides what a lone modifier key (fn, Right ⌥, …) means, from raw key events. Pure logic, so it can be tested.
struct ModifierKeyTracker {
    enum Action { case none, press, release, abort }

    static let abortWindow: TimeInterval = 0.6      // a key pressed this soon means the modifier was part of a shortcut

    private var down = false
    private var aborted = false
    private var pressedAt = Date.distantPast

    mutating func flagsChanged(isDown: Bool, at t: Date) -> Action {
        if isDown && !down {
            down = true; aborted = false; pressedAt = t
            return .press
        }
        if !isDown && down {
            down = false
            if aborted { aborted = false; return .none }     // the abort already ended this recording
            return .release
        }
        return .none
    }

    mutating func keyDown(at t: Date) -> Action {
        guard down, !aborted, t.timeIntervalSince(pressedAt) < Self.abortWindow else { return .none }
        aborted = true
        return .abort
    }
}

/// Watches one modifier key system-wide (needs the Accessibility permission Voicey already asks for).
final class ModifierHotKey {
    private var tracker = ModifierKeyTracker()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let keyCode: Int
    private let onPress: () -> Void
    private let onRelease: () -> Void
    private let onAbort: () -> Void

    static func flag(for keyCode: Int) -> NSEvent.ModifierFlags? {
        switch keyCode {
        case 54, 55: return .command
        case 56, 60: return .shift
        case 58, 61: return .option
        case 59, 62: return .control
        case 63: return .function
        default: return nil
        }
    }

    init(keyCode: Int, onPress: @escaping () -> Void, onRelease: @escaping () -> Void, onAbort: @escaping () -> Void) {
        self.keyCode = keyCode
        self.onPress = onPress
        self.onRelease = onRelease
        self.onAbort = onAbort
    }

    func start() {
        stop()
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] e in self?.handle(e) }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] e in self?.handle(e); return e }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        tracker = ModifierKeyTracker()
    }

    private func handle(_ e: NSEvent) {
        let action: ModifierKeyTracker.Action
        if e.type == .flagsChanged {
            guard Int(e.keyCode) == keyCode, let flag = Self.flag(for: keyCode) else { return }
            action = tracker.flagsChanged(isDown: e.modifierFlags.contains(flag), at: Date())
        } else {
            action = tracker.keyDown(at: Date())
        }
        switch action {
        case .none: break
        case .press: onPress()
        case .release: onRelease()
        case .abort: onAbort()
        }
    }
}
