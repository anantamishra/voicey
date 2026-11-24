import Foundation

/// Decides when a dictation has gone quiet for long enough to stop by itself. Pure logic, fed with mic levels (0...1).
struct SilenceWatcher {
    static let speechLevel: Float = 0.2          // about -42 dB: above room noise, below normal speech
    static let nothingHeardTimeout: TimeInterval = 8

    /// Seconds of quiet, after speech, before stopping. 0 turns the feature off.
    var pause: TimeInterval
    private var heardSpeech = false
    private var lastSound: TimeInterval?
    private var startedAt: TimeInterval?
    private var fired = false

    init(pause: TimeInterval) { self.pause = pause }

    /// Returns true once, when it is time to stop.
    mutating func feed(level: Float, at t: TimeInterval) -> Bool {
        guard pause > 0, !fired else { return false }
        if startedAt == nil { startedAt = t; lastSound = t }
        if level > Self.speechLevel { heardSpeech = true; lastSound = t; return false }
        let quiet = t - (lastSound ?? t)
        let limit = heardSpeech ? pause : max(Self.nothingHeardTimeout, pause)
        guard quiet >= limit else { return false }
        fired = true
        return true
    }
}
