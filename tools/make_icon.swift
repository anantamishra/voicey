import AppKit

// Usage: swift make_icon.swift <output.png>   (renders a 1024x1024 app icon)
let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
let cg = ctx.cgContext

func color(_ hex: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: a)
}

// Icon body: macOS grid leaves ~100px margin.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: body, xRadius: 186, yRadius: 186)

// Soft drop shadow under the body.
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor.black.withAlphaComponent(0.35).cgColor)
color(0xE8365D).setFill()
squircle.fill()
cg.restoreGState()

// Gradient fill.
cg.saveGState()
squircle.addClip()
NSGradient(colors: [color(0xFF8A4C), color(0xE8365D)])!.draw(in: body, angle: -65)
// Gentle top highlight.
NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
    .draw(in: NSRect(x: 100, y: 520, width: 824, height: 404), angle: -90)
cg.restoreGState()

// Tinted SF Symbol helper.
func symbol(_ name: String, height: CGFloat, color: NSColor) -> NSImage {
    let cfg = NSImage.SymbolConfiguration(pointSize: height, weight: .semibold)
    let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(cfg)!
    let scale = height / base.size.height
    let size = NSSize(width: base.size.width * scale, height: height)
    return NSImage(size: size, flipped: false) { r in
        base.draw(in: r); color.set(); r.fill(using: .sourceAtop); return true
    }
}

// A person in profile, talking: sound waves leave the mouth.
let faceHeight: CGFloat = 540
let faceOrigin = CGPoint(x: 215, y: 250)
let face = FaceProfile.path(height: faceHeight, origin: faceOrigin, closed: false)
let mouthPt = FaceProfile.mouthPoint(height: faceHeight, origin: faceOrigin)

cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -8), blur: 16, color: NSColor.black.withAlphaComponent(0.25).cgColor)
NSColor.white.setStroke()
face.lineWidth = 28
face.lineCapStyle = .round
face.lineJoinStyle = .round
face.stroke()
cg.restoreGState()

let waveCenter = NSPoint(x: mouthPt.x + 8, y: mouthPt.y)
for (r, alpha) in [(CGFloat(78), CGFloat(0.95)), (CGFloat(142), CGFloat(0.65)), (CGFloat(206), CGFloat(0.38))] {
    NSColor.white.withAlphaComponent(alpha).setStroke()
    let arc = NSBezierPath()
    arc.appendArc(withCenter: waveCenter, radius: r, startAngle: -34, endAngle: 34)
    arc.lineWidth = 28
    arc.lineCapStyle = .round
    arc.stroke()
}

NSGraphicsContext.restoreGraphicsState()
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
