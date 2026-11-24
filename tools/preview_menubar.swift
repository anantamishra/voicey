import AppKit
// Renders the menu-bar icon (idle on light/dark bar, and recording) enlarged to a PNG.
let scale: CGFloat = 12
let w = 27 * scale, h = 18 * scale
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w * 3), pixelsHigh: Int(h * 2), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let cells: [(NSColor, NSColor, Bool)] = [(.white, .black, false), (NSColor(white: 0.15, alpha: 1), .white, false), (.white, .black, true)]
for (i, c) in cells.enumerated() {
    let r = NSRect(x: CGFloat(i) * w, y: 0, width: w, height: h * 2)
    c.0.setFill(); r.fill()
    let img = MenuBarIcon.make(recording: c.2)
    let dst = NSRect(x: r.minX, y: h / 2, width: w, height: h)
    if c.2 { img.draw(in: dst) } else {
        // template images are black; tint to the bar's text colour
        let t = NSImage(size: img.size, flipped: false) { rr in img.draw(in: rr); c.1.set(); rr.fill(using: .sourceAtop); return true }
        t.draw(in: dst)
    }
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "Resources/menubar-preview.png"))
