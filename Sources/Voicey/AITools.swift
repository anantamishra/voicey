import AppKit

// MARK: - The tools Voicey knows about

enum AIToolID: String, CaseIterable, Identifiable {
    case claude, codex, openai, antigravity
    var id: String { rawValue }
}

struct AIToolInfo {
    let id: AIToolID
    let name: String
    let maker: String
    let symbol: String
    let canPolish: Bool            // can Voicey send text through it?
    let knownModels: [String]
    let helpURL: String
    let limitation: String         // shown when it's installed but can't be used
}

enum AITools {
    static let all: [AIToolInfo] = [
        AIToolInfo(id: .claude, name: "Claude Code", maker: "Anthropic", symbol: "sparkles", canPolish: true,
                   knownModels: ["haiku", "sonnet", "opus"],
                   helpURL: "https://docs.claude.com/en/docs/claude-code/overview", limitation: ""),
        AIToolInfo(id: .codex, name: "Codex", maker: "OpenAI", symbol: "chevron.left.forwardslash.chevron.right", canPolish: true,
                   knownModels: [], helpURL: "https://github.com/openai/codex", limitation: ""),
        AIToolInfo(id: .openai, name: "OpenAI", maker: "API and CLI", symbol: "cloud", canPolish: false,
                   knownModels: [], helpURL: "https://platform.openai.com/docs/quickstart",
                   limitation: "Found, but Voicey can’t use a bare API key for polishing yet. Use Codex for OpenAI models."),
        AIToolInfo(id: .antigravity, name: "Antigravity", maker: "Google", symbol: "arrow.up.forward.app", canPolish: false,
                   knownModels: [], helpURL: "https://antigravity.google",
                   limitation: "An IDE without a command-line text mode, so Voicey can’t polish through it. Its models are chosen inside the app."),
    ]
    static func info(_ id: AIToolID) -> AIToolInfo { all.first { $0.id == id }! }

    static func modelLabel(_ tool: AIToolID, _ model: String) -> String {
        switch model {
        case "haiku": return "Haiku \u{2013} fastest"
        case "sonnet": return "Sonnet \u{2013} balanced"
        case "opus": return "Opus \u{2013} most capable"
        default: return model
        }
    }
}

struct ToolStatus: Identifiable {
    let info: AIToolInfo
    var id: AIToolID { info.id }
    var path: String?              // command-line program
    var appPath: String?           // desktop app, if that's how it's installed
    var version: String?
    var models: [String] = []
    var detail = ""                // e.g. “API key found in your shell”
    var found: Bool { path != nil || appPath != nil || !detail.isEmpty }
    var usable: Bool { info.canPolish && path != nil }
}

// MARK: - Running programs

enum Shell {
    private final class Box { var data = Data() }

    /// Runs a program, optionally feeding it stdin, and kills it after `timeout` seconds.
    static func run(_ path: String, _ args: [String], input: String? = nil, env: [String: String] = [:],
                    timeout: TimeInterval, cwd: URL? = nil) -> (code: Int32, out: String, err: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.currentDirectoryURL = cwd ?? FileManager.default.temporaryDirectory
        if !env.isEmpty { p.environment = ProcessInfo.processInfo.environment.merging(env) { $1 } }
        let out = Pipe(), err = Pipe(), inPipe = Pipe()
        p.standardOutput = out
        p.standardError = err
        p.standardInput = input == nil ? FileHandle.nullDevice : inPipe
        do { try p.run() } catch { return (-1, "", error.localizedDescription) }
        if let input {
            inPipe.fileHandleForWriting.write(Data(input.utf8))
            try? inPipe.fileHandleForWriting.close()
        }
        let errBox = Box()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async { errBox.data = err.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        let killer = DispatchWorkItem { if p.isRunning { p.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        group.wait()
        killer.cancel()
        return (p.terminationStatus, String(decoding: outData, as: UTF8.self), String(decoding: errBox.data, as: UTF8.self))
    }
}

// MARK: - Finding them

enum AIToolScanner {
    private static let home = NSHomeDirectory()

    /// Programs found through the user's login shell (this is how nvm, pnpm, etc. installs are seen).
    private static func shellLookup() -> (bins: [String: String], hasOpenAIKey: Bool) {
        let script = """
        for n in claude codex openai agy antigravity; do p=$(command -v "$n" 2>/dev/null); case "$p" in /*) echo "VOICEY_BIN $n $p";; esac; done
        [ -n "$OPENAI_API_KEY" ] && echo "VOICEY_ENV OPENAI_API_KEY"
        """
        let r = Shell.run("/bin/zsh", ["-lc", script], timeout: 8)
        var bins: [String: String] = [:]
        var key = false
        for line in r.out.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: " ", maxSplits: 2).map(String.init)
            if parts.count == 3, parts[0] == "VOICEY_BIN" { bins[parts[1]] = parts[2] }
            if parts.count == 2, parts[0] == "VOICEY_ENV" { key = true }     // only whether it exists, never its value
        }
        return (bins, key)
    }

    private static func nvmBins(_ name: String) -> [String] {
        let root = "\(home)/.nvm/versions/node"
        let versions = (try? FileManager.default.contentsOfDirectory(atPath: root)) ?? []
        return versions.sorted(by: >).map { "\(root)/\($0)/bin/\(name)" }
    }

    private static func firstExecutable(_ paths: [String?]) -> String? {
        paths.compactMap { $0 }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func candidates(_ id: AIToolID, _ shell: [String: String]) -> [String?] {
        switch id {
        case .claude:
            return [shell["claude"], "\(home)/.local/bin/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude", "\(home)/.claude/local/claude"]
        case .codex:
            return [shell["codex"], "/opt/homebrew/bin/codex", "/usr/local/bin/codex", "\(home)/.local/bin/codex",
                    "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex",
                    "/Applications/Codex.app/Contents/Resources/codex-cli/bin/codex"] + nvmBins("codex")
        case .openai:
            return [shell["openai"], "/opt/homebrew/bin/openai", "/usr/local/bin/openai"]
        case .antigravity:
            return [shell["agy"], shell["antigravity"]]
        }
    }

    /// The program to run for a tool. Remembers the last good path so dictation never waits on a scan.
    static func binary(for id: AIToolID) -> String? {
        let key = "toolPath.\(id.rawValue)"
        if let cached = Prefs.d.string(forKey: key), FileManager.default.isExecutableFile(atPath: cached) { return cached }
        let found = firstExecutable(candidates(id, [:])) ?? firstExecutable(candidates(id, shellLookup().bins))
        if let found { Prefs.d.set(found, forKey: key) }
        return found
    }

    private static func appBundle(_ names: [String]) -> (path: String, version: String?)? {
        for dir in ["/Applications", "\(home)/Applications"] {
            for n in names {
                let p = "\(dir)/\(n).app"
                if FileManager.default.fileExists(atPath: p) {
                    let v = Bundle(url: URL(fileURLWithPath: p))?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                    return (p, v)
                }
            }
        }
        return nil
    }

    /// `model = "..."` from Codex's own config; nothing else in that file is read.
    private static func codexConfiguredModel() -> String? {
        guard let text = try? String(contentsOfFile: "\(home)/.codex/config.toml", encoding: .utf8) else { return nil }
        for line in text.split(whereSeparator: \.isNewline) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("[") { break }                       // only top-level keys
            if t.hasPrefix("model"), !t.hasPrefix("model_"),
               let q1 = t.firstIndex(of: "\""), let q2 = t[t.index(after: q1)...].firstIndex(of: "\"") {
                return String(t[t.index(after: q1)..<q2])
            }
        }
        return nil
    }

    private static func version(of path: String) -> String? {
        let r = Shell.run(path, ["--version"], timeout: 8)
        let line = r.out.split(whereSeparator: \.isNewline).first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        return line.isEmpty ? nil : String(line.prefix(48))
    }

    static func scan() -> [ToolStatus] {
        let shell = shellLookup()
        var results = [ToolStatus?](repeating: nil, count: AITools.all.count)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: AITools.all.count) { i in
            let info = AITools.all[i]
            var s = ToolStatus(info: info, models: info.knownModels)
            s.path = firstExecutable(candidates(info.id, shell.bins))
            if let p = s.path { s.version = version(of: p); Prefs.d.set(p, forKey: "toolPath.\(info.id.rawValue)") }
            switch info.id {
            case .codex:
                if let m = codexConfiguredModel() { s.models = [m]; s.detail = "Your Codex default is \(m)" }
            case .openai:
                if shell.hasOpenAIKey { s.detail = "API key found in your shell" }
            case .antigravity:
                let apps = ["Antigravity", "Antigravity IDE"].compactMap { n in appBundle([n]).map { (n, $0) } }
                if let first = apps.first {
                    s.appPath = first.1.path
                    s.version = apps.map { "\($0.0) \($0.1.version ?? "")" }.joined(separator: " · ")
                }
            default: break
            }
            lock.lock(); results[i] = s; lock.unlock()
        }
        return results.compactMap { $0 }
    }
}

enum ToolTest { case running, ok(String), failed(String) }

final class AIToolStore: ObservableObject {
    static let shared = AIToolStore()
    @Published var statuses: [ToolStatus] = []
    @Published var scanning = false
    @Published var tests: [AIToolID: ToolTest] = [:]
    @Published var installs: [AIToolID: InstallState] = [:]
    @Published var signingIn: Set<AIToolID> = []

    func status(_ id: AIToolID) -> ToolStatus? { statuses.first { $0.id == id } }

    func rescan(done: (() -> Void)? = nil) {
        guard !scanning else { return }
        scanning = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = AIToolScanner.scan()
            DispatchQueue.main.async {
                self.statuses = result
                self.scanning = false
                done?()
            }
        }
    }

    func test(_ id: AIToolID) {
        tests[id] = .running
        TextPolisher.test(tool: id, model: TextPolisher.model(for: id)) { ok, message in
            self.tests[id] = ok ? .ok(message) : .failed(message)
        }
    }
}

extension AIToolStore {
    /// Models Voicey offers for a tool. Codex uses whatever you have configured, so it has a single "default" entry.
    func modelOptions(_ id: AIToolID) -> [(value: String, label: String)] {
        if id == .codex {
            return [("", status(.codex)?.models.first.map { "Default (\($0))" } ?? "Default")]
        }
        let known = status(id)?.models ?? []
        let list = known.isEmpty ? AITools.info(id).knownModels : known
        return list.map { ($0, AITools.modelLabel(id, $0)) }
    }
}
