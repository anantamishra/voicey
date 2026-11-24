import AppKit
import SwiftUI

/// A translucent window with a transparent title bar that hosts a SwiftUI view.
/// Voicey normally has no Dock icon, so it acts like a regular app while one of these is open.
final class GlassWindowHost {
    private var window: NSWindow?
    private var closeObserver: Any?
    private let name: String
    private let title: String
    private let size: NSSize
    private let minSize: NSSize?                 // giving a minimum size also makes the window resizable
    private let keepAfterClosing: Bool           // reuse the same window next time, or start fresh
    private let content: () -> AnyView
    private let willClose: () -> Void

    init(name: String, title: String, size: NSSize, minSize: NSSize? = nil, keepAfterClosing: Bool,
         content: @escaping () -> AnyView, willClose: @escaping () -> Void = {}) {
        self.name = name
        self.title = title
        self.size = size
        self.minSize = minSize
        self.keepAfterClosing = keepAfterClosing
        self.content = content
        self.willClose = willClose
    }

    func show() {
        if window == nil { window = build() }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        vlog("\(name): shown frame=\(window?.frame ?? .zero) visible=\(window?.isVisible ?? false)")
    }

    func close() { window?.close() }

    private func build() -> NSWindow {
        let host = NSHostingView(rootView: content())
        let backdrop = NSVisualEffectView()
        backdrop.material = .underWindowBackground
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        host.translatesAutoresizingMaskIntoConstraints = false
        backdrop.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor), host.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor),
            host.topAnchor.constraint(equalTo: backdrop.topAnchor), host.bottomAnchor.constraint(equalTo: backdrop.bottomAnchor),
        ])

        var style: NSWindow.StyleMask = [.titled, .closable, .fullSizeContentView]
        if minSize != nil { style.formUnion([.miniaturizable, .resizable]) }
        let w = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: style, backing: .buffered, defer: false)
        w.contentView = backdrop
        w.title = title
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        if let minSize { w.minSize = minSize }
        w.center()

        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.willClose()
            if !self.keepAfterClosing { self.window = nil }
            NSApp.setActivationPolicy(.accessory)
        }
        return w
    }
}

enum SettingsWindow {
    static let shared: GlassWindowHost = GlassWindowHost(name: "settings", title: "Voicey Settings", size: NSSize(width: 700, height: 480),
                                        minSize: NSSize(width: 640, height: 420), keepAfterClosing: true,
                                        content: { AnyView(SettingsView()) })
}

enum OnboardingWindow {
    static let shared: GlassWindowHost = GlassWindowHost(name: "onboarding", title: "Set up Voicey", size: NSSize(width: 640, height: 620), keepAfterClosing: false,
                                        content: { AnyView(OnboardingView(finish: { OnboardingWindow.shared.close() })) },
                                        // Closing counts as finished: they've seen it, and Settings can run it again.
                                        willClose: { Prefs.d.set(true, forKey: Prefs.onboardingDone) })
}
