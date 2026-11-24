import AppKit
import CryptoKit

// MARK: - Versions

/// “1.2.3”, “v1.2”, “1.3.0-beta.1”. A pre-release sorts below the same release.
struct AppVersion: Comparable, CustomStringConvertible {
    let parts: [Int]
    let isPrerelease: Bool

    init?(_ text: String) {
        var t = text.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("v") || t.hasPrefix("V") { t.removeFirst() }
        isPrerelease = t.contains("-")
        let core = t.split(separator: "-", maxSplits: 1).first.map(String.init) ?? t
        let numbers = core.split(separator: ".").map { Int($0) }
        guard !numbers.isEmpty, !numbers.contains(where: { $0 == nil }) else { return nil }
        parts = numbers.compactMap { $0 }
    }

    var description: String { parts.map(String.init).joined(separator: ".") + (isPrerelease ? "-pre" : "") }

    static func < (a: AppVersion, b: AppVersion) -> Bool {
        let n = max(a.parts.count, b.parts.count)
        for i in 0..<n {
            let x = i < a.parts.count ? a.parts[i] : 0, y = i < b.parts.count ? b.parts[i] : 0
            if x != y { return x < y }
        }
        return a.isPrerelease && !b.isPrerelease
    }
    static func == (a: AppVersion, b: AppVersion) -> Bool { !(a < b) && !(b < a) }
}

/// What `update.json` on your server says about the newest release.
struct UpdateInfo: Decodable, Equatable {
    let version: String
    let build: String?
    let url: String
    let sha256: String
    let notes: String?
    let minMacOS: String?
}

// MARK: - Updater

final class Updater: NSObject, ObservableObject {
    static let shared = Updater()

    enum State: Equatable {
        case idle, checking, upToDate
        case available(UpdateInfo)
        case downloading(Double)
        case installing
        case failed(String)
    }

    @Published var state: State = .idle
    private var progressObservation: NSKeyValueObservation?

    static var currentVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }
    static var currentBuild: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "" }

    /// The feed to check: Settings override first, then the address baked in at build time.
    var feedURL: URL? {
        let override = (Prefs.d.string(forKey: Prefs.updateFeed) ?? "").trimmingCharacters(in: .whitespaces)
        let baked = Bundle.main.object(forInfoDictionaryKey: "VoiceyFeedURL") as? String ?? ""
        return Self.validated(override.isEmpty ? baked : override)
    }

    /// https only, except for a server on this Mac (used for testing a release before uploading it).
    static func validated(_ text: String) -> URL? {
        guard !text.isEmpty, let url = URL(string: text), let scheme = url.scheme?.lowercased() else { return nil }
        if scheme == "https" { return url }
        if scheme == "http", ["localhost", "127.0.0.1"].contains(url.host ?? "") { return url }
        return nil
    }

    /// Pure decision, so it can be tested: is `info` something we should offer?
    static func decide(current: String, info: UpdateInfo, osVersion: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion) -> State {
        guard let cur = AppVersion(current), let new = AppVersion(info.version) else { return .failed("The update feed has an unreadable version.") }
        guard new > cur else { return .upToDate }
        if let min = info.minMacOS, let need = AppVersion(min) {
            let have = AppVersion("\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)")!
            if have < need { return .failed("Version \(info.version) needs macOS \(min) or later.") }
        }
        return .available(info)
    }

    // MARK: Checking

    func check(manual: Bool) {
        guard let url = feedURL else {
            if manual { state = .failed("No update feed is set. Add one in Settings → General → Updates.") }
            return
        }
        if case .downloading = state { return }
        if case .installing = state { return }
        state = .checking
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("Voicey/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, response, error in
            let result: State
            if let error {
                result = .failed("Couldn’t reach the update server: \(error.localizedDescription)")
            } else if (response as? HTTPURLResponse).map({ $0.statusCode != 200 }) ?? false {
                result = .failed("The update server answered \((response as? HTTPURLResponse)?.statusCode ?? 0).")
            } else if let data, let info = try? JSONDecoder().decode(UpdateInfo.self, from: data) {
                result = Self.decide(current: Self.currentVersion, info: info)
            } else {
                result = .failed("The update feed isn’t in the expected format.")
            }
            vlog("update check: \(result)")
            Prefs.d.set(Date().timeIntervalSince1970, forKey: Prefs.lastUpdateCheck)
            DispatchQueue.main.async { self.state = result }
        }.resume()
    }

    /// Checks at most once a day, quietly.
    func checkIfDue() {
        guard Prefs.d.bool(forKey: Prefs.autoUpdate), feedURL != nil else { return }
        let last = Prefs.d.double(forKey: Prefs.lastUpdateCheck)
        if Date().timeIntervalSince1970 - last > 20 * 3600 { check(manual: false) }
    }

    // MARK: Installing

    private func fail(_ message: String) {
        vlog("update failed: \(message)")
        DispatchQueue.main.async { self.state = .failed(message) }
    }

    /// Downloads, verifies and swaps in the new version, then relaunches.
    func install() {
        guard case .available(let info) = state, let url = Updater.validated(info.url) else {
            if case .available = state { fail("The download address in the update feed isn’t allowed.") }
            return
        }
        let destination = Bundle.main.bundleURL
        guard FileManager.default.isWritableFile(atPath: destination.deletingLastPathComponent().path) else {
            return fail("Voicey can’t replace itself where it is. Move it to your Applications folder and try again.")
        }
        state = .downloading(0)
        let task = URLSession.shared.downloadTask(with: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)) { [weak self] tmp, response, error in
            guard let self else { return }
            self.progressObservation = nil
            if let error { return self.fail("Download failed: \(error.localizedDescription)") }
            guard (response as? HTTPURLResponse)?.statusCode == 200, let tmp else { return self.fail("The download server returned an error.") }
            let work = FileManager.default.temporaryDirectory.appendingPathComponent("voicey-update-\(UUID().uuidString)")
            do {
                try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
                let zip = work.appendingPathComponent("update.zip")
                try FileManager.default.moveItem(at: tmp, to: zip)
                try self.verifyAndStage(zip: zip, work: work, info: info, destination: destination)
            } catch let e as UpdateError {
                try? FileManager.default.removeItem(at: work)
                self.fail(e.message)
            } catch {
                try? FileManager.default.removeItem(at: work)
                self.fail("Couldn’t prepare the update: \(error.localizedDescription)")
            }
        }
        progressObservation = task.progress.observe(\.fractionCompleted) { p, _ in
            DispatchQueue.main.async { if case .downloading = self.state { self.state = .downloading(p.fractionCompleted) } }
        }
        task.resume()
    }

    struct UpdateError: Error { let message: String }

    private func verifyAndStage(zip: URL, work: URL, info: UpdateInfo, destination: URL) throws {
        // 1. the file is exactly what the feed promised
        let digest = SHA256.hash(data: try Data(contentsOf: zip)).map { String(format: "%02x", $0) }.joined()
        guard digest == info.sha256.lowercased() else { throw UpdateError(message: "The download doesn’t match its checksum, so it was discarded.") }

        // 2. unpack and make sure it is really a newer Voicey
        let unpacked = work.appendingPathComponent("new")
        let unzip = Shell.run("/usr/bin/ditto", ["-xk", zip.path, unpacked.path], timeout: 120)
        guard unzip.code == 0 else { throw UpdateError(message: "Couldn’t unpack the update.") }
        let apps = (try? FileManager.default.contentsOfDirectory(atPath: unpacked.path))?.filter { $0.hasSuffix(".app") } ?? []
        guard let name = apps.first else { throw UpdateError(message: "The update didn’t contain the app.") }
        let newApp = unpacked.appendingPathComponent(name)
        let bundle = Bundle(url: newApp)
        guard bundle?.bundleIdentifier == Bundle.main.bundleIdentifier else { throw UpdateError(message: "The update is for a different app.") }
        let newVersion = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        guard let nv = AppVersion(newVersion), let cv = AppVersion(Self.currentVersion), nv > cv, newVersion == info.version else {
            throw UpdateError(message: "The update’s version (\(newVersion)) isn’t what the feed said.")
        }
        guard Shell.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", newApp.path], timeout: 60).code == 0 else {
            throw UpdateError(message: "The update’s signature is damaged, so it was discarded.")
        }

        // 3. a helper waits for this app to quit, swaps the folders (keeping a backup until the swap works) and reopens it
        let script = work.appendingPathComponent("swap.sh")
        let body = """
        #!/bin/sh
        PID="$1"; NEW="$2"; DEST="$3"; WORK="$4"
        while kill -0 "$PID" 2>/dev/null; do sleep 0.2; done
        BACKUP="$DEST.previous"
        rm -rf "$BACKUP"
        if mv "$DEST" "$BACKUP"; then
          if mv "$NEW" "$DEST"; then rm -rf "$BACKUP"; else mv "$BACKUP" "$DEST"; fi
        fi
        /usr/bin/open -n "$DEST"
        rm -rf "$WORK"
        """
        try body.write(to: script, atomically: true, encoding: .utf8)
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = [script.path, String(ProcessInfo.processInfo.processIdentifier), newApp.path, destination.path, work.path]
        helper.standardOutput = FileHandle.nullDevice
        helper.standardError = FileHandle.nullDevice
        try helper.run()
        vlog("update: handing over to the swap helper, version \(newVersion)")
        DispatchQueue.main.async {
            self.state = .installing
            NSApp.terminate(nil)
        }
    }
}
