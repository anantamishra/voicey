import Foundation

/// Turns raw key down/up events from one shortcut into dictation actions.
///
/// - Hold (>= 0.3 s): talk while held, stops on release.
/// - Single press: starts recording; the next press stops it.
/// - Double tap (two quick presses, or hold, release, press again quickly): hands-free lock.
///   Recording continues until the next press.
struct GestureMachine {
    enum Action { case none, start, stop, lock, scheduleGrace }
    private enum State { case idle, pending(pressedAt: Date), toggled(releasedAt: Date), grace, locked }

    static let holdThreshold: TimeInterval = 0.3
    static let doubleTapWindow: TimeInterval = 0.4
    static let graceWindow: TimeInterval = 0.3     // after a hold ends, how long a second press can still lock it

    private var state = State.idle
    private var ignoreRelease = false

    mutating func reset() { state = .idle; ignoreRelease = false }

    /// `recording` lets a recording that was started elsewhere (the menu) be stopped by the key.
    mutating func press(at t: Date, recording: Bool) -> Action {
        switch state {
        case .idle:
            if recording { ignoreRelease = true; return .stop }
            state = .pending(pressedAt: t)
            return .start
        case .pending:
            return .none
        case .toggled(let released):
            ignoreRelease = true
            if t.timeIntervalSince(released) < Self.doubleTapWindow {
                state = .locked
                return .lock
            }
            state = .idle
            return .stop
        case .grace:
            state = .locked
            ignoreRelease = true
            return .lock
        case .locked:
            state = .idle
            ignoreRelease = true
            return .stop
        }
    }

    mutating func release(at t: Date) -> Action {
        if ignoreRelease { ignoreRelease = false; return .none }
        guard case .pending(let pressed) = state else { return .none }
        if t.timeIntervalSince(pressed) >= Self.holdThreshold {
            state = .grace
            return .scheduleGrace
        }
        state = .toggled(releasedAt: t)
        return .none
    }

    /// Called when the grace window after a hold runs out without a second press.
    mutating func graceExpired() -> Action {
        guard case .grace = state else { return .none }
        state = .idle
        return .stop
    }
}
