import AppKit

/// Menu-bar glyph that matches the app icon: a person in profile talking, with sound waves.
/// Idle is a template image (macOS tints it for light/dark menu bars); recording draws it in red.
enum MenuBarIcon {
    static func make(recording: Bool) -> NSImage {
        let tint: NSColor = recording ? .systemRed : .black
        let height: CGFloat = 15
        let origin = CGPoint(x: 1, y: 1.5)
        let img = NSImage(size: NSSize(width: 27, height: 18), flipped: false) { _ in
            tint.setStroke()
            let face = FaceProfile.path(height: height, origin: origin, closed: false)
            face.lineWidth = 1.4
            face.lineCapStyle = .round
            face.lineJoinStyle = .round
            face.stroke()

            let m = FaceProfile.mouthPoint(height: height, origin: origin)
            let center = NSPoint(x: m.x + 0.8, y: m.y)
            for (r, a) in [(CGFloat(3.0), CGFloat(1.0)), (CGFloat(5.4), CGFloat(0.6))] {
                tint.withAlphaComponent(recording ? 1 : a).setStroke()
                let arc = NSBezierPath()
                arc.appendArc(withCenter: center, radius: r, startAngle: -38, endAngle: 38)
                arc.lineWidth = 1.4
                arc.lineCapStyle = .round
                arc.stroke()
            }
            return true
        }
        img.isTemplate = !recording
        img.accessibilityDescription = "Voicey"
        return img
    }
}
