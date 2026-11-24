import AppKit

/// A person's face in profile, facing right, drawn as a smooth silhouette.
/// Shared by the menu-bar icon and the app-icon generator.
enum FaceProfile {
    /// Outline in a 100 x 120 box, y up, clockwise from the back of the neck.
    static let outline: [CGPoint] = [
        (24, 0), (25, 22), (14, 38), (6, 58), (8, 80), (22, 102), (46, 114), (68, 106), (78, 90),
        (80, 78), (81, 70), (91, 58), (82, 53), (83, 48), (87, 45), (82, 41), (85, 37), (81, 32),
        (82, 24), (74, 15), (64, 10), (62, 0),
    ].map { CGPoint(x: $0.0, y: $0.1) }

    /// Where the sound comes out, in the same 100 x 120 box.
    static let mouth = CGPoint(x: 86, y: 41)

    /// Smooth path (Catmull-Rom spline) scaled so the face is `height` tall with its lower-left at `origin`.
    /// `closed: false` leaves the bottom of the neck open, for a line drawing.
    static func path(height: CGFloat, origin: CGPoint, closed: Bool = true) -> NSBezierPath {
        let s = height / 120
        let p = outline.map { CGPoint(x: origin.x + $0.x * s, y: origin.y + $0.y * s) }
        let n = p.count
        let path = NSBezierPath()
        path.move(to: p[0])
        let segments = closed ? n : n - 1
        for i in 0..<segments {
            let p0 = closed ? p[(i - 1 + n) % n] : p[max(i - 1, 0)]
            let p1 = p[i]
            let p2 = p[(i + 1) % n]
            let p3 = closed ? p[(i + 2) % n] : p[min(i + 2, n - 1)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.curve(to: p2, controlPoint1: c1, controlPoint2: c2)
        }
        if closed { path.close() }
        return path
    }

    static func mouthPoint(height: CGFloat, origin: CGPoint) -> CGPoint {
        let s = height / 120
        return CGPoint(x: origin.x + mouth.x * s, y: origin.y + mouth.y * s)
    }
}
