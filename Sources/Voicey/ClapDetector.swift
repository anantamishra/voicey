import AVFoundation

/// Recognises two quick claps in a stream of loudness readings. Pure logic, so it can be tested without a microphone.
///
/// A clap is a short, sharp burst well above the room's background level. Longer loud sounds (speech, music,
/// a door slam that rings on) are ignored, and so are two bursts that are too close or too far apart.
struct ClapPattern {
    static let minLevel: Float = 0.2           // peak amplitude (0...1) a burst must reach
    static let aboveBackground: Float = 8      // ...and this many times the room's noise floor
    static let maxBurst: TimeInterval = 0.25   // a longer loud stretch is not a clap
    static let minGap: TimeInterval = 0.12     // two claps closer than this are one clap
    static let maxGap: TimeInterval = 0.7      // ...and further apart than this are two single claps
    static let cooldown: TimeInterval = 1.5    // quiet period after a double clap fires

    private var floor: Float = 0.01
    private var burstStart: TimeInterval?
    private var burstTooLong = false
    private var firstClap: TimeInterval?
    private var lastFire: TimeInterval = -.infinity

    /// Feed one reading (the loudest sample in a short slice of audio). Returns true when a double clap just ended.
    mutating func feed(peak: Float, at t: TimeInterval) -> Bool {
        let threshold = max(Self.minLevel, floor * Self.aboveBackground)
        if peak > threshold {
            if burstStart == nil { burstStart = t }
            if let s = burstStart, t - s > Self.maxBurst { burstTooLong = true }
            return false
        }
        guard peak < threshold * 0.5 else { return false }      // still ringing down

        // Quiet again: the room's background level drifts slowly, and a finished burst may have been a clap.
        floor = min(0.05, max(0.002, floor * 0.98 + peak * 0.02))
        defer { burstStart = nil; burstTooLong = false }
        guard let start = burstStart, !burstTooLong else { return false }
        return registerClap(at: start)
    }

    private mutating func registerClap(at t: TimeInterval) -> Bool {
        if let first = firstClap {
            let gap = t - first
            if gap < Self.minGap { return false }
            if gap <= Self.maxGap {
                firstClap = nil
                guard t - lastFire > Self.cooldown else { return false }
                lastFire = t
                return true
            }
        }
        firstClap = t
        return false
    }

    mutating func reset() { burstStart = nil; burstTooLong = false; firstClap = nil }
}

/// Listens to the microphone for a double clap. Uses its own audio engine, so it must be stopped while Voicey records.
final class ClapListener {
    var onDoubleClap: (() -> Void)?
    private let engine = AVAudioEngine()
    private var pattern = ClapPattern()
    private(set) var running = false

    func start() {
        guard !running, AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }
        pattern.reset()
        input.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, time in
            guard let self, let ch = buffer.floatChannelData?[0] else { return }
            var peak: Float = 0
            for i in 0..<Int(buffer.frameLength) { peak = max(peak, abs(ch[i])) }
            let t = ProcessInfo.processInfo.systemUptime
            if self.pattern.feed(peak: peak, at: t) {
                DispatchQueue.main.async { self.onDoubleClap?() }
            }
        }
        do {
            engine.prepare()
            try engine.start()
            running = true
            vlog("clap listener on")
        } catch {
            input.removeTap(onBus: 0)
            vlog("clap listener failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard running else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        running = false
        vlog("clap listener off")
    }
}
