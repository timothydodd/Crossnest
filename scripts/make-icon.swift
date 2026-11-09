// Renders Crossnest's app icon at 1024×1024: an arrow arcing over into a warm nest.
// Usage: swift scripts/make-icon.swift <output.png>
// (scripts/make-icon.sh turns it into Resources/AppIcon.icns)
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.dropFirst().first ?? "AppIcon-1024.png"

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
    let ns = NSGraphicsContext(bitmapImageRep: rep)
else { fatalError("Could not create bitmap") }

NSGraphicsContext.current = ns
let ctx = ns.cgContext
let space = CGColorSpaceCreateDeviceRGB()

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

func fillGradient(_ path: CGPath, top: CGColor, bottom: CGColor, in rect: CGRect) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: rect.minY), options: [])
    ctx.restoreGState()
}

ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

// 1. Tile: macOS icon grid, 824pt body centred in 1024, with a soft drop shadow. Teal.
let tileRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let tile = CGPath(roundedRect: tileRect, cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0, 0, 0, 0.35))
ctx.addPath(tile)
ctx.setFillColor(color(0.08, 0.42, 0.43))
ctx.fillPath()
ctx.restoreGState()
fillGradient(tile, top: color(0.22, 0.74, 0.69), bottom: color(0.06, 0.38, 0.42), in: tileRect)

// 2. Nest: a wide bowl with a gently domed rim.
let nest = CGMutablePath()
nest.move(to: CGPoint(x: 232, y: 470))
nest.addCurve(to: CGPoint(x: 792, y: 470), control1: CGPoint(x: 250, y: 205), control2: CGPoint(x: 774, y: 205))
nest.addCurve(to: CGPoint(x: 232, y: 470), control1: CGPoint(x: 640, y: 512), control2: CGPoint(x: 384, y: 512))
nest.closeSubpath()
let nestRect = CGRect(x: 232, y: 270, width: 560, height: 240)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0, 0.12, 0.14, 0.40))
ctx.addPath(nest)
ctx.setFillColor(color(0.86, 0.50, 0.22))
ctx.fillPath()
ctx.restoreGState()
fillGradient(nest, top: color(1.00, 0.78, 0.46), bottom: color(0.84, 0.47, 0.20), in: nestRect)

// Woven twigs across the bowl, clipped to its shape.
ctx.saveGState()
ctx.addPath(nest)
ctx.clip()
ctx.setLineCap(.round)
ctx.setLineWidth(14)
ctx.setStrokeColor(color(0.62, 0.32, 0.12, 0.55))
for (i, y) in [430.0, 380.0, 330.0, 285.0].enumerated() {
    let tilt: CGFloat = i.isMultiple(of: 2) ? 26 : -26
    ctx.move(to: CGPoint(x: 200, y: y - tilt))
    ctx.addQuadCurve(to: CGPoint(x: 824, y: y + tilt), control: CGPoint(x: 512, y: y - 48))
}
ctx.strokePath()
ctx.restoreGState()

// Rim highlight.
ctx.setLineWidth(10)
ctx.setStrokeColor(color(1, 0.90, 0.70, 0.9))
ctx.move(to: CGPoint(x: 252, y: 472))
ctx.addCurve(to: CGPoint(x: 772, y: 472), control1: CGPoint(x: 392, y: 508), control2: CGPoint(x: 632, y: 508))
ctx.strokePath()

// 3. The crossing: a white arrow arcing over from the left and landing in the nest.
let start = CGPoint(x: 268, y: 560)
let control = CGPoint(x: 560, y: 930)
let end = CGPoint(x: 646, y: 606)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 16, color: color(0, 0.15, 0.18, 0.35))
ctx.beginTransparencyLayer(auxiliaryInfo: nil)  // one shadow for line + head
ctx.setStrokeColor(color(1, 1, 1))
ctx.setLineWidth(52)
ctx.setLineCap(.round)
ctx.move(to: start)
ctx.addQuadCurve(to: end, control: control)
ctx.strokePath()

// Arrowhead along the curve's end tangent.
let dx = end.x - control.x, dy = end.y - control.y
let length = (dx * dx + dy * dy).squareRoot()
let dir = CGPoint(x: dx / length, y: dy / length)
let perp = CGPoint(x: -dir.y, y: dir.x)
let tip = CGPoint(x: end.x + dir.x * 92, y: end.y + dir.y * 92)
let baseCentre = CGPoint(x: end.x - dir.x * 14, y: end.y - dir.y * 14)
let head = CGMutablePath()
head.move(to: tip)
head.addLine(to: CGPoint(x: baseCentre.x + perp.x * 78, y: baseCentre.y + perp.y * 78))
head.addLine(to: CGPoint(x: baseCentre.x - perp.x * 78, y: baseCentre.y - perp.y * 78))
head.closeSubpath()
ctx.addPath(head)
ctx.setFillColor(color(1, 1, 1))
ctx.setLineJoin(.round)
ctx.setLineWidth(18)
ctx.drawPath(using: .fillStroke)
ctx.endTransparencyLayer()
ctx.restoreGState()

NSGraphicsContext.current = nil
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("PNG encode failed") }
try png.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
