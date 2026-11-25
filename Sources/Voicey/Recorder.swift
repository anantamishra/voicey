import AVFoundation
import Speech

/// Records the mic and turns speech into text.
/// Apple's on-device recognizer always runs for the live preview. With the Whisper engine selected,
/// the audio is also captured at 16 kHz, silence is trimmed, and Whisper produces the final text
/// (Apple's text is the fallback if Whisper fails).
final class Recorder {
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private var latest = ""
    private var finished = false
    private var session = 0
    private var committed = ""
    private var segment = ""

    // Whisper capture
    private var whisperMode = false
    private var converter: AVAudioConverter?
    private let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
    private var samples: [Float] = []
    private let lock = NSLock()

    var onPartial: ((String) -> Void)?
    var onFinish: ((String) -> Void)?
    var onStatus: ((String) -> Void)?
    var onLevel: ((Float) -> Void)?
    var onSilence: (() -> Void)?                 // a long pause after speaking: time to stop
    private var silence = SilenceWatcher(pause: 0)
    private var lastLevelTime = Date.distantPast

    static func requestPermissions(_ done: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return done(false) }
            AVCaptureDevice.requestAccess(for: .audio) { ok in done(ok) }
        }
    }

    private func fail(_ code: Int, _ msg: String) -> NSError {
        NSError(domain: "Voicey", code: code, userInfo: [NSLocalizedDescriptionKey: msg])
    }

    func start() throws {
        let id = Prefs.d.string(forKey: Prefs.locale) ?? ""
        recognizer = id.isEmpty ? (SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer())
                                : SFSpeechRecognizer(locale: Locale(identifier: id))
        guard let recognizer, recognizer.isAvailable else { throw fail(1, "Speech recognizer unavailable") }
        latest = ""; committed = ""; segment = ""
        finished = false
        session += 1
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { throw fail(2, "Microphone not allowed") }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else { throw fail(3, "Speech Recognition not allowed") }

        // Decide the engine.
        whisperMode = false
        if RecognitionEngine.current == .whisper {
            if WhisperRunner.cliPath() != nil && ModelStore.shared.isInstalled(ModelStore.currentID) {
                whisperMode = true
            } else {
                vlog("whisper not ready (cli or model missing); using Apple")
                onStatus?("Whisper isn’t set up yet – using Apple")
            }
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.addsPunctuation = true
        req.contextualStrings = Personalization.terms
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        request = req

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { throw fail(4, "No audio input device") }
        converter = whisperMode ? AVAudioConverter(from: format, to: target) : nil
        lock.lock(); samples = []; lock.unlock()
        silence = SilenceWatcher(pause: Prefs.d.double(forKey: Prefs.autoStop))
        vlog("start: engine=\(whisperMode ? "whisper/\(ModelStore.currentID)" : RecognitionEngine.apple.rawValue) locale=\(recognizer.locale.identifier) format=\(format)")

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self, weak req] buffer, _ in
            req?.append(buffer)
            self?.capture(buffer)
        }
        engine.prepare()
        try engine.start()

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let error { vlog("recognition error: \(error)") }
            if let result {
                let text = result.bestTranscription.formattedString
                // The recognizer restarts its text after a pause: keep the earlier segment.
                if !self.segment.isEmpty, text.count < self.segment.count, !self.segment.hasPrefix(String(text.prefix(3))) {
                    self.committed += (self.committed.isEmpty ? "" : " ") + self.segment
                }
                self.segment = text
                self.latest = self.committed.isEmpty ? text : self.committed + " " + text
                DispatchQueue.main.async { if !self.finished { self.onPartial?(self.latest) } }
                if result.isFinal && !self.whisperMode { self.finish() }
            } else if error != nil && !self.whisperMode {
                self.finish()
            }
        }
    }

    /// Audio thread: convert to 16 kHz mono and keep it for Whisper.
    private func capture(_ buffer: AVAudioPCMBuffer) {
        reportLevel(buffer)
        guard whisperMode, let converter else { return }
        let ratio = target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
        var supplied = false
        var err: NSError?
        converter.convert(to: out, error: &err) { _, status in
            if supplied { status.pointee = .noDataNow; return nil }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        guard err == nil, let ch = out.floatChannelData?[0] else { return }
        lock.lock()
        samples.append(contentsOf: UnsafeBufferPointer(start: ch, count: Int(out.frameLength)))
        lock.unlock()
    }

    /// Mic loudness 0...1 for the pop-up's meter, ~25 times a second.
    private func reportLevel(_ buffer: AVAudioPCMBuffer) {
        let now = Date()
        guard now.timeIntervalSince(lastLevelTime) > 0.04, let ch = buffer.floatChannelData?[0] else { return }
        lastLevelTime = now
        let n = Int(buffer.frameLength)
        guard n > 0 else { return }
        var sum: Float = 0
        for i in 0..<n { sum += ch[i] * ch[i] }
        let db = 10 * log10(max(sum / Float(n), 1e-10))
        let level = max(0, min(1, (db + 50) / 38))
        let stopNow = silence.feed(level: level, at: ProcessInfo.processInfo.systemUptime)
        DispatchQueue.main.async { [weak self] in
            self?.onLevel?(level)
            if stopNow { self?.onSilence?() }
        }
    }

    /// Throws the recording away without producing text (the key turned out to be part of another shortcut).
    func cancel() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        finished = true
        task?.cancel(); task = nil; request = nil
        lock.lock(); samples = []; lock.unlock()
        vlog("recording cancelled")
    }

    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        vlog("stop: \(latest.count) chars heard")
        if whisperMode { return finishWithWhisper() }
        // If the recognizer never sends a final result, fall back to what we have.
        let s = session
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.session == s else { return }
            self.finish()
        }
    }

    private func finishWithWhisper() {
        let fallback = latest
        finished = true                           // Apple's late callbacks must not deliver anything
        task?.cancel(); task = nil; request = nil
        lock.lock(); let audio = samples; samples = []; lock.unlock()

        let modelID = ModelStore.currentID
        let modelPath = ModelStore.shared.path(modelID)
        let language = ModelStore.language(for: modelID)
        let trim = Prefs.d.bool(forKey: Prefs.trimSilence)
        let prompt = Personalization.whisperPrompt
        onStatus?("Transcribing with Whisper…")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var input: [Float]? = audio
            if trim { input = SilenceTrimmer.trim(audio) }
            guard let input else {
                vlog("whisper: no speech detected in \(audio.count / 16_000)s of audio")
                DispatchQueue.main.async { self?.onFinish?("") }
                return
            }
            vlog("whisper: \(audio.count / 16_000)s recorded, \(input.count / 16_000)s after trimming (trim=\(trim))")
            let t0 = Date()
            let text = WhisperRunner.transcribe(input, modelPath: modelPath, language: language, prompt: prompt)
            vlog("whisper: \(String(format: "%.1f", Date().timeIntervalSince(t0)))s -> \(text.map { "\($0.count) chars" } ?? "FAILED")")
            DispatchQueue.main.async {
                if let text, !text.isEmpty { self?.onFinish?(text) }
                else { self?.onFinish?(fallback) }
            }
        }
    }

    private func finish() {
        DispatchQueue.main.async {
            guard !self.finished else { return }
            self.finished = true
            vlog("finish: \(self.latest.count) chars")
            self.task?.cancel()
            self.task = nil
            self.request = nil
            self.onFinish?(self.latest)
        }
    }
}
