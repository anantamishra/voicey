import Foundation

let logURL = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Logs/Voicey.log")
private let logQueue = DispatchQueue(label: "voicey.log")
private let logLimit = 300_000          // when the file grows past this...
private let logKeep = 100_000           // ...only this much of the newest part is kept

/// Appends a timestamped line to ~/Library/Logs/Voicey.log. Safe to call from any thread.
/// Never put what the user said in here: log counts and timings instead.
func vlog(_ message: String) {
    let line = "\(Date()) \(message)\n"
    logQueue.sync {
        trimLogIfNeeded()
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: logURL, atomically: true, encoding: .utf8)
        }
    }
}

/// Empties the log.
func clearLog() {
    logQueue.sync { try? Data().write(to: logURL) }
}

/// Keeps the newest part of an oversized log, starting at a whole line.
private func trimLogIfNeeded() {
    guard let size = (try? FileManager.default.attributesOfItem(atPath: logURL.path))?[.size] as? Int, size > logLimit,
          let data = try? Data(contentsOf: logURL) else { return }
    var tail = data.suffix(logKeep)
    if let newline = tail.firstIndex(of: 0x0A) { tail = tail[tail.index(after: newline)...] }
    try? Data(tail).write(to: logURL)
}

/// Older versions wrote dictated text into the log. Wipe it once so none of that is left behind.
func scrubOldLogOnce() {
    let key = "logScrubbedV2"
    guard !UserDefaults.standard.bool(forKey: key) else { return }
    clearLog()
    UserDefaults.standard.set(true, forKey: key)
}
