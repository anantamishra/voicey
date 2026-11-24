import Foundation

private let logURL = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Logs/Voicey.log")
private let logQueue = DispatchQueue(label: "voicey.log")

/// Appends a timestamped line to ~/Library/Logs/Voicey.log. Safe to call from any thread.
/// The file is cut back to its newest part when it grows past 1 MB.
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

private func trimLogIfNeeded() {
    guard let size = (try? FileManager.default.attributesOfItem(atPath: logURL.path))?[.size] as? Int, size > 1_000_000,
          let data = try? Data(contentsOf: logURL) else { return }
    try? data.suffix(200_000).write(to: logURL)
}
