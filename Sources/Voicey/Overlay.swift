import AppKit
import Combine
import SwiftUI

/// State shown in the floating pop-up.
final class OverlayModel: ObservableObject {
    enum Phase { case listening, transcribing, polishing, done, failed }
    @Published var phase: Phase = .listening
    @Published var text = ""
    @Published var level: CGFloat = 0          // 0...1, smoothed mic level
    @Published var locked = false              // hands-free: keeps recording until the next press
}

private struct LevelBars: View {
    let level: CGFloat
    private let weights: [CGFloat] = [0.45, 0.8, 1.0, 0.7, 0.5]
    var body: some View {
        HStack(spacing: 3) {
            ForEach(weights.indices, id: \.self) { i in
                Capsule()
                    .fill(Color.red.gradient)
                    .frame(width: 4, height: 5 + 23 * level * weights[i])
            }
        }
        .frame(width: 32, height: 28)
        .animation(.easeOut(duration: 0.08), value: level)
    }
}

private struct OverlayView: View {
    @ObservedObject var model: OverlayModel

    private var message: (String, Bool) {       // text, isPlaceholder
        switch model.phase {
        case .listening: return model.text.isEmpty ? (model.locked ? "Listening hands-free… press to stop" : "Listening…", true) : (model.text, false)
        case .transcribing: return ("Transcribing with Whisper…", true)
        case .polishing: return ("Polishing with \(TextPolisher.displayName)…", true)
        case .done, .failed: return (model.text, model.phase == .failed)
        }
    }

    @ViewBuilder private var indicator: some View {
        switch model.phase {
        case .listening:
            HStack(spacing: 6) {
                LevelBars(level: model.level)
                if model.locked { Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(.secondary) }
            }
            .frame(width: model.locked ? 52 : 32, height: 28)
        case .transcribing, .polishing: ProgressView().controlSize(.small).frame(width: 32, height: 28)
        case .done: Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(.green).frame(width: 32, height: 28)
        case .failed: Image(systemName: "mic.slash").font(.system(size: 18)).foregroundStyle(.secondary).frame(width: 32, height: 28)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            indicator
            Text(message.0)
                .font(.system(size: 15))
                .foregroundStyle(message.1 ? .secondary : .primary)
                .lineLimit(3)
                .truncationMode(.head)             // newest words stay visible
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 440)
        .glassCard(radius: 22)
        .padding(20)                                // room for the shadow
    }
}

/// A floating, click-through panel that never takes focus, so the text still pastes where your cursor is.
final class Overlay {
    let model = OverlayModel()
    private var panel: NSPanel?
    private var host: NSHostingView<OverlayView>?
    private var sub: AnyCancellable?
    private var hideWork: DispatchWorkItem?
    private var smoothed: CGFloat = 0

    private var enabled: Bool { Prefs.d.bool(forKey: Prefs.overlay) }

    private func build() {
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 90),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.level = .statusBar
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let h = NSHostingView(rootView: OverlayView(model: model))
        h.wantsLayer = true
        h.layer?.backgroundColor = .clear
        p.contentView = h
        panel = p
        host = h
        sub = model.objectWillChange.sink { [weak self] _ in DispatchQueue.main.async { self?.relayout() } }
    }

    /// Resize to fit the text, keeping the bottom edge where it is.
    private func relayout() {
        guard let panel, let host, panel.isVisible else { return }
        let size = host.fittingSize
        var f = panel.frame
        f.size = size
        f.origin.x = anchor.x - size.width / 2
        f.origin.y = anchor.y
        panel.setFrame(f, display: true)
    }

    private var anchor = CGPoint.zero      // bottom-centre of the pop-up

    func show() {
        guard enabled else { return }
        if panel == nil { build() }
        hideWork?.cancel()
        model.phase = .listening
        model.text = ""
        model.level = 0
        model.locked = false
        smoothed = 0

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let area = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        anchor = CGPoint(x: area.midX, y: area.minY + 40)

        guard let panel else { return }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        relayout()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.18; panel.animator().alphaValue = 1 }
    }

    func update(text: String) { if enabled { model.text = text } }

    func update(level raw: Float) {
        guard enabled else { return }
        smoothed = smoothed * 0.55 + CGFloat(raw) * 0.45
        model.level = smoothed
    }

    func set(_ phase: OverlayModel.Phase) { if enabled { model.phase = phase } }

    func setLocked(_ on: Bool) { model.locked = on }

    /// Show the result briefly, then fade out.
    func finish(_ text: String, success: Bool) {
        guard enabled, panel?.isVisible == true else { return }
        model.text = text
        model.phase = success ? .done : .failed
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (success ? 0.9 : 1.4), execute: work)
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.25; panel.animator().alphaValue = 0 },
                                             completionHandler: { panel.orderOut(nil) })
    }
}
