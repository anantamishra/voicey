import AVFoundation
import Foundation

// MARK: - Voice-activity trimming

/// Cuts silence out of a 16 kHz mono recording before it goes to Whisper.
/// Keeps speech plus a short pad on each side, collapses long pauses, and returns nil if nobody spoke
/// (Whisper tends to invent text like "Thank you." when it is fed silence).
enum SilenceTrimmer {
    static func trim(_ x: [Float]) -> [Float]? {
        let frame = 320                       // 20 ms
        let n = x.count / frame
        guard n > 12 else { return nil }

        var db = [Float](repeating: -120, count: n)
        for i in 0..<n {
            var sum: Float = 0
            for j in (i * frame)..<((i + 1) * frame) { sum += x[j] * x[j] }
            db[i] = 10 * log10(max(sum / Float(frame), 1e-12))
        }
        // Threshold sits above the room's noise floor, but never so high that it clips quiet speech.
        let floor = db.sorted()[n / 10]
        let threshold = min(max(floor + 10, -48), -35)

        var speech = db.map { $0 > threshold }
        var i = 0
        while i < n {                          // ignore blips shorter than 60 ms
            guard speech[i] else { i += 1; continue }
            var j = i
            while j < n && speech[j] { j += 1 }
            if j - i < 3 { for k in i..<j { speech[k] = false } }
            i = j
        }
        guard speech.filter({ $0 }).count >= 25 else { return nil }   // < 0.5 s of speech: too short to trust (Whisper makes up words)

        let pad = 12                           // 240 ms either side keeps natural pauses
        var keep = [Bool](repeating: false, count: n)
        for i in 0..<n where speech[i] {
            for k in max(0, i - pad)...min(n - 1, i + pad) { keep[k] = true }
        }

        var out = [Float]()
        out.reserveCapacity(x.count)
        let gap = [Float](repeating: 0, count: 1_600)   // 100 ms between kept chunks
        var previousKept = false
        for i in 0..<n {
            if keep[i] {
                if !previousKept && !out.isEmpty { out += gap }
                out += x[(i * frame)..<((i + 1) * frame)]
            }
            previousKept = keep[i]
        }
        return out
    }
}

// MARK: - Running whisper.cpp

enum WhisperRunner {
    /// The engine shipped inside Voicey.app (so nothing has to be installed).
    static var bundledPath: String? {
        let p = Bundle.main.resourceURL?.appendingPathComponent("whisper/whisper-cli").path
        return p.flatMap { FileManager.default.isExecutableFile(atPath: $0) ? $0 : nil }
    }

    private static let runsLock = NSLock()
    private static var runsCache: [String: Bool] = [:]

    /// Checks once that a program really starts on this Mac (an engine built for a newer macOS won't).
    private static func runs(_ path: String) -> Bool {
        runsLock.lock(); defer { runsLock.unlock() }
        if let known = runsCache[path] { return known }
        let r = Shell.run(path, ["-h"], timeout: 10)
        let ok = (r.out + r.err).lowercased().contains("usage")
        runsCache[path] = ok
        if !ok { vlog("whisper engine at \(path) doesn’t run on this Mac") }
        return ok
    }

    /// The engine to use: the one inside the app first, then a Homebrew copy.
    static func cliPath() -> String? {
        [bundledPath, "/opt/homebrew/bin/whisper-cli", "/usr/local/bin/whisper-cli"]
            .compactMap { $0 }
            .first { FileManager.default.isExecutableFile(atPath: $0) && runs($0) }
    }

    static var isBundled: Bool { bundledPath != nil && cliPath() == bundledPath }

    private static func wav(_ samples: [Float]) -> Data {
        var d = Data()
        func u32(_ v: UInt32) { var v = v.littleEndian; d.append(Data(bytes: &v, count: 4)) }
        func u16(_ v: UInt16) { var v = v.littleEndian; d.append(Data(bytes: &v, count: 2)) }
        let bytes = UInt32(samples.count * 2)
        d.append("RIFF".data(using: .ascii)!); u32(36 + bytes)
        d.append("WAVEfmt ".data(using: .ascii)!); u32(16); u16(1); u16(1)
        u32(16_000); u32(32_000); u16(2); u16(16)
        d.append("data".data(using: .ascii)!); u32(bytes)
        var pcm = [Int16](); pcm.reserveCapacity(samples.count)
        for s in samples { pcm.append(Int16(max(-1, min(1, s)) * 32767)) }
        pcm.withUnsafeBytes { d.append(contentsOf: $0) }
        return d
    }

    /// Blocking: call from a background queue.
    static func transcribe(_ samples: [Float], modelPath: String, language: String, prompt: String = "") -> String? {
        guard let cli = cliPath() else { return nil }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("voicey-\(UUID().uuidString).wav")
        do { try wav(samples).write(to: file) } catch { return nil }
        defer { try? FileManager.default.removeItem(at: file) }

        var args = ["-m", modelPath, "-f", file.path, "-nt", "-np", "-l", language,
                    "-t", String(max(4, ProcessInfo.processInfo.activeProcessorCount / 2))]
        if !prompt.isEmpty { args += ["--prompt", prompt] }
        let result = Shell.run(cli, args, timeout: 120)
        return result.code == 0 ? cleanOutput(result.out) : nil
    }

    /// Drops non-speech markers such as [BLANK_AUDIO] or (music) and joins what is left into one line.
    static func cleanOutput(_ raw: String) -> String {
        let text = raw.replacingOccurrences(of: "\\[[A-Z_ ]+\\]|\\((?:music|silence|noise)\\)", with: "",
                                            options: [.regularExpression, .caseInsensitive])
        return text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: " ")
    }
}

// MARK: - Model downloads

final class ModelStore: NSObject, ObservableObject, URLSessionDownloadDelegate {
    struct Info: Identifiable { let id: String; let label: String; let size: String }

    static let shared = ModelStore()
    static let models = [
        Info(id: "base.en", label: "Base – English, fast", size: "148 MB"),
        Info(id: "small.en", label: "Small – English, accurate", size: "488 MB"),
        Info(id: "large-v3-turbo-q5_0", label: "Large Turbo – multilingual, best", size: "574 MB"),
        Info(id: "base", label: "Base – multilingual", size: "148 MB"),
    ]

    @Published var downloadingID: String?
    @Published var progress = 0.0
    @Published var error = ""
    @Published var tick = 0                      // bumps when files change so views refresh

    private var task: URLSessionDownloadTask?
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    static var directory: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Voicey/models", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    static var currentID: String { Prefs.d.string(forKey: Prefs.whisperModel) ?? "base.en" }

    func path(_ id: String) -> String { Self.directory.appendingPathComponent("ggml-\(id).bin").path }
    func isInstalled(_ id: String) -> Bool {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path(id))
        return (attributes?[.size] as? Int ?? 0) > 1_000_000
    }
    func size(of id: String) -> String { Self.models.first { $0.id == id }?.size ?? "" }

    /// Whisper language code for a model: English-only models need "en"; multilingual ones follow Settings.
    static func language(for id: String) -> String {
        if id.hasSuffix(".en") { return "en" }
        let locale = Prefs.d.string(forKey: Prefs.locale) ?? ""
        return locale.isEmpty ? "auto" : String(locale.prefix(2))
    }

    func download(_ id: String) {
        guard downloadingID == nil,
              let url = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-\(id).bin") else { return }
        error = ""
        progress = 0
        downloadingID = id
        task = session.downloadTask(with: url)
        task?.taskDescription = id
        task?.resume()
    }

    func cancel() { task?.cancel() }

    func urlSession(_ s: URLSession, downloadTask t: URLSessionDownloadTask, didWriteData _: Int64,
                    totalBytesWritten written: Int64, totalBytesExpectedToWrite total: Int64) {
        guard total > 0 else { return }
        DispatchQueue.main.async { self.progress = Double(written) / Double(total) }
    }

    func urlSession(_ s: URLSession, downloadTask t: URLSessionDownloadTask, didFinishDownloadingTo tmp: URL) {
        guard let id = t.taskDescription else { return }
        guard (t.response as? HTTPURLResponse)?.statusCode == 200 else {
            DispatchQueue.main.async { self.error = "Download failed (server error)." }
            return
        }
        let dest = URL(fileURLWithPath: path(id))
        try? FileManager.default.removeItem(at: dest)
        do { try FileManager.default.moveItem(at: tmp, to: dest) }
        catch { DispatchQueue.main.async { self.error = "Couldn’t save the model: \(error.localizedDescription)" } }
    }

    func urlSession(_ s: URLSession, task t: URLSessionTask, didCompleteWithError e: Error?) {
        DispatchQueue.main.async {
            if let e, (e as NSError).code != NSURLErrorCancelled { self.error = "Download failed: \(e.localizedDescription)" }
            self.downloadingID = nil
            self.task = nil
            self.tick += 1
        }
    }
}
