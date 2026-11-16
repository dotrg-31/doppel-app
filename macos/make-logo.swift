// Doppel logo: dark tile with glowing glass knot forms in blue/indigo. Original artwork;
// the "double" idea is two interlocked or echoed forms.
// Usage: swift make-logo.swift <size> <output.png> [variant 1-5]
import AppKit
import CoreText

let px = Int(CommandLine.arguments[1])!
let out = CommandLine.arguments[2]
let variant = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "5"  // 5 is the chosen Doppel logo

let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }
func with(_ c: CGColor, alpha: CGFloat) -> CGColor { c.copy(alpha: alpha)! }
func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

struct Theme { let top: CGColor, bottom: CGColor, glow: CGColor, nebula: [CGColor] }

var seed: UInt64 = 0x2545F4914F6CDD1D
func rnd() -> CGFloat { seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17; return CGFloat(seed % 10_000) / 10_000 }

func linear(_ colors: [CGColor], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}
func radial(_ color: CGColor, at c: CGPoint, radius: CGFloat) {
    let g = CGGradient(colorsSpace: cs, colors: [color, with(color, alpha: 0)] as CFArray, locations: nil)!
    ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [])
}

// MARK: Tile
func drawTile(_ theme: Theme) {
    let tile = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.addPath(tile); ctx.clip()
    linear([rgb(0.11, 0.11, 0.15), rgb(0.015, 0.015, 0.03)], from: pt(512, 924), to: pt(512, 100))
    ctx.setBlendMode(.plusLighter)
    radial(with(theme.glow, alpha: 0.22), at: pt(512, 520), radius: 470)
    radial(with(theme.nebula[0], alpha: 0.12), at: pt(300, 800), radius: 380)
    ctx.setBlendMode(.normal)
    // faint background stars
    for _ in 0..<70 {
        let r = 0.8 + rnd() * 1.6
        ctx.setFillColor(rgb(1, 1, 1, 0.15 + rnd() * 0.35))
        ctx.fillEllipse(in: CGRect(x: 110 + rnd() * 800, y: 110 + rnd() * 800, width: r * 2, height: r * 2))
    }
    // top sheen
    linear([rgb(1, 1, 1, 0.10), rgb(1, 1, 1, 0)], from: pt(512, 924), to: pt(512, 700))
    ctx.restoreGState()
    ctx.addPath(tile); ctx.setStrokeColor(rgb(1, 1, 1, 0.14)); ctx.setLineWidth(3); ctx.strokePath()
}

// MARK: Glass body
func drawGlass(_ shape: CGPath, _ theme: Theme, glow: CGFloat = 70, stars: Int = 55) {
    let box = shape.boundingBoxOfPath
    // outer glow
    for i in 0..<2 {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: i == 0 ? glow * 1.6 : glow * 0.5, color: with(theme.glow, alpha: 0.9))
        ctx.addPath(shape); ctx.setFillColor(theme.glow); ctx.fillPath()
        ctx.restoreGState()
    }
    ctx.saveGState()
    ctx.addPath(shape); ctx.clip()
    linear([theme.top, theme.bottom], from: pt(box.midX, box.maxY), to: pt(box.midX, box.minY))
    // nebula clouds
    ctx.setBlendMode(.plusLighter)
    for i in 0..<9 {
        let c = theme.nebula[i % theme.nebula.count]
        radial(with(c, alpha: 0.55), at: pt(box.minX + rnd() * box.width, box.minY + rnd() * box.height), radius: box.width * (0.18 + rnd() * 0.22))
    }
    ctx.setBlendMode(.multiply)
    for _ in 0..<5 {
        radial(rgb(0.05, 0.02, 0.2, 0.55), at: pt(box.minX + rnd() * box.width, box.minY + rnd() * box.height), radius: box.width * (0.12 + rnd() * 0.16))
    }
    ctx.setBlendMode(.normal)
    // stars inside the glass
    for _ in 0..<stars {
        let r = 1.2 + rnd() * 2.6
        let p = pt(box.minX + rnd() * box.width, box.minY + rnd() * box.height)
        ctx.saveGState()
        if r > 3 { ctx.setShadow(offset: .zero, blur: 10, color: rgb(1, 1, 1, 0.9)) }
        ctx.setFillColor(rgb(1, 1, 1, 0.55 + rnd() * 0.45))
        ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        ctx.restoreGState()
    }
    // inner shading: light from the top edge, dark toward the bottom edge
    let inverse = CGMutablePath()
    inverse.addRect(box.insetBy(dx: -300, dy: -300)); inverse.addPath(shape)
    for (off, blur, color) in [(CGSize(width: 0, height: 22), CGFloat(34), rgb(0, 0, 0.1, 0.75)),
                               (CGSize(width: 0, height: -10), CGFloat(12), rgb(1, 1, 1, 0.85)),
                               (CGSize(width: 0, height: 0), CGFloat(16), with(theme.top, alpha: 0.8))] {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: off.width * CGFloat(px) / 1024, height: off.height * CGFloat(px) / 1024),
                      blur: blur * CGFloat(px) / 1024, color: color)
        ctx.addPath(inverse); ctx.setFillColor(rgb(0, 0, 0)); ctx.fillPath(using: .evenOdd)
        ctx.restoreGState()
    }
    // gloss on the upper part
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: box.minX - box.width * 0.2, y: box.midY + box.height * 0.05, width: box.width * 1.4, height: box.height * 0.8))
    ctx.clip()
    linear([rgb(1, 1, 1, 0.30), rgb(1, 1, 1, 0.02)], from: pt(box.midX, box.maxY), to: pt(box.midX, box.midY))
    ctx.restoreGState()
    ctx.restoreGState()
    ctx.addPath(shape); ctx.setStrokeColor(rgb(1, 1, 1, 0.45)); ctx.setLineWidth(2.5); ctx.strokePath()
}

/// Dark openings cut into the glass (eyes, mouth), with a lit rim.
func drawHoles(_ holes: CGPath, _ theme: Theme) {
    ctx.saveGState()
    ctx.addPath(holes); ctx.clip()
    ctx.setFillColor(rgb(0.02, 0.02, 0.05)); ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    let box = holes.boundingBoxOfPath
    let inverse = CGMutablePath(); inverse.addRect(box.insetBy(dx: -200, dy: -200)); inverse.addPath(holes)
    ctx.setShadow(offset: .zero, blur: 18 * CGFloat(px) / 1024, color: with(theme.glow, alpha: 0.9))
    ctx.addPath(inverse); ctx.setFillColor(rgb(0, 0, 0)); ctx.fillPath(using: .evenOdd)
    ctx.restoreGState()
    ctx.addPath(holes); ctx.setStrokeColor(rgb(1, 1, 1, 0.35)); ctx.setLineWidth(2); ctx.strokePath()
}

func sparkle(_ c: CGPoint, _ r: CGFloat) {
    let p = CGMutablePath()
    let k = r * 0.12
    p.move(to: pt(c.x, c.y + r))
    p.addQuadCurve(to: pt(c.x + r, c.y), control: pt(c.x + k, c.y + k))
    p.addQuadCurve(to: pt(c.x, c.y - r), control: pt(c.x + k, c.y - k))
    p.addQuadCurve(to: pt(c.x - r, c.y), control: pt(c.x - k, c.y - k))
    p.addQuadCurve(to: pt(c.x, c.y + r), control: pt(c.x - k, c.y + k))
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: r * 0.9 * CGFloat(px) / 1024, color: rgb(1, 1, 1, 1))
    ctx.addPath(p); ctx.setFillColor(rgb(1, 1, 1)); ctx.fillPath()
    ctx.restoreGState()
}

// MARK: Shapes
func stroked(_ p: CGPath, _ w: CGFloat) -> CGPath { p.copy(strokingWithWidth: w, lineCap: .round, lineJoin: .round, miterLimit: 10).normalized(using: .winding) }

func head(cx: CGFloat, top: CGFloat, bottom: CGFloat, halfWidth w: CGFloat) -> CGPath {
    let p = CGMutablePath(); let mid = top - (top - bottom) * 0.38
    p.move(to: pt(cx, top))
    p.addCurve(to: pt(cx + w, mid), control1: pt(cx + w * 0.75, top), control2: pt(cx + w, top - (top - mid) * 0.45))
    p.addCurve(to: pt(cx, bottom), control1: pt(cx + w, mid - (mid - bottom) * 0.55), control2: pt(cx + w * 0.45, bottom))
    p.addCurve(to: pt(cx - w, mid), control1: pt(cx - w * 0.45, bottom), control2: pt(cx - w, mid - (mid - bottom) * 0.55))
    p.addCurve(to: pt(cx, top), control1: pt(cx - w, top - (top - mid) * 0.45), control2: pt(cx - w * 0.75, top))
    p.closeSubpath(); return p
}
func eye(cx: CGFloat, cy: CGFloat, side: CGFloat, scale s: CGFloat = 1) -> CGPath {
    let p = CGMutablePath()
    p.move(to: pt(cx - side * 52 * s, cy + 58 * s))
    p.addCurve(to: pt(cx + side * 58 * s, cy - 10 * s), control1: pt(cx + side * 10 * s, cy + 78 * s), control2: pt(cx + side * 60 * s, cy + 40 * s))
    p.addCurve(to: pt(cx + side * 30 * s, cy - 92 * s), control1: pt(cx + side * 58 * s, cy - 50 * s), control2: pt(cx + side * 48 * s, cy - 84 * s))
    p.addCurve(to: pt(cx - side * 52 * s, cy + 58 * s), control1: pt(cx - side * 12 * s, cy - 70 * s), control2: pt(cx - side * 62 * s, cy + 0 * s))
    p.closeSubpath(); return p
}
func glyph(_ ch: String, height: CGFloat, center: CGPoint, stretchY: CGFloat = 1) -> CGPath {
    let base = NSFont.systemFont(ofSize: 400, weight: .black)
    let font = NSFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: 400)! as CTFont
    var chars = Array(ch.utf16); var g = CGGlyph(0)
    CTFontGetGlyphsForCharacters(font, &chars, &g, 1)
    let raw = CTFontCreatePathForGlyph(font, g, nil)!
    let b = raw.boundingBoxOfPath
    let k = height / b.height
    var t = CGAffineTransform(translationX: center.x, y: center.y).scaledBy(x: k / stretchY, y: k).translatedBy(x: -b.midX, y: -b.midY)
    return raw.copy(using: &t)!
}
func tail(from: CGPoint, c1: CGPoint, c2: CGPoint, corner: CGPoint, end: CGPoint) -> CGPath {
    let p = CGMutablePath(); p.move(to: from); p.addCurve(to: corner, control1: c1, control2: c2); p.addLine(to: end); return p
}
func union(_ paths: [CGPath]) -> CGPath { paths.dropFirst().reduce(paths[0].normalized(using: .winding)) { $0.union($1, using: .winding) } }

// MARK: Variants
let blue = Theme(top: rgb(0.16, 0.38, 1), bottom: rgb(0.27, 0.12, 0.72), glow: rgb(0.2, 0.42, 1),
                 nebula: [rgb(0.1, 0.5, 1), rgb(0.45, 0.25, 1), rgb(0.55, 0.9, 1), rgb(0.1, 0.3, 0.95)])
let cyan = Theme(top: rgb(0.6, 0.95, 1), bottom: rgb(0.2, 0.5, 1), glow: rgb(0.3, 0.8, 1),
                 nebula: [rgb(0.5, 1, 1), rgb(0.3, 0.6, 1), rgb(1, 1, 1)])
let violet = Theme(top: rgb(0.78, 0.5, 1), bottom: rgb(0.38, 0.14, 0.8), glow: rgb(0.6, 0.3, 1),
                   nebula: [rgb(0.8, 0.5, 1), rgb(0.4, 0.3, 1), rgb(1, 0.7, 1)])

func circle(_ c: CGPoint, _ r: CGFloat) -> CGPath { CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2), transform: nil) }
/// Three elongated loops 120 degrees apart, meeting at the centre.
func trefoil(center c: CGPoint, reach: CGFloat, width w: CGFloat, rotation: CGFloat, stroke: CGFloat) -> CGPath {
    union((0..<3).map { k in
        let a = rotation + CGFloat(k) * 2 * .pi / 3
        var t = CGAffineTransform(translationX: c.x + cos(a) * reach * 0.42, y: c.y + sin(a) * reach * 0.42).rotated(by: a)
        return stroked(CGPath(ellipseIn: CGRect(x: -reach * 0.58, y: -w / 2, width: reach * 1.16, height: w), transform: &t), stroke)
    })
}
func hexRing(center c: CGPoint, radius r: CGFloat, rotation: CGFloat, stroke: CGFloat) -> CGPath {
    let p = CGMutablePath()
    for k in 0..<6 { let a = rotation + CGFloat(k) * .pi / 3; let q = pt(c.x + r * cos(a), c.y + r * sin(a)); k == 0 ? p.move(to: q) : p.addLine(to: q) }
    p.closeSubpath(); return stroked(p, stroke)
}
func rosette(center c: CGPoint, spread: CGFloat, radius r: CGFloat, stroke: CGFloat) -> CGPath {
    union((0..<6).map { k in stroked(circle(pt(c.x + spread * cos(CGFloat(k) * .pi / 3), c.y + spread * sin(CGFloat(k) * .pi / 3)), r), stroke) })
}
func blossom(center c: CGPoint, spread: CGFloat, radius r: CGFloat) -> CGPath {
    union((0..<6).map { k in circle(pt(c.x + spread * cos(CGFloat(k) * .pi / 3 + .pi / 6), c.y + spread * sin(CGFloat(k) * .pi / 3 + .pi / 6)), r) })
}
func letterD(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, stroke: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: pt(x, y)); p.addLine(to: pt(x, y + h)); p.addLine(to: pt(x + w - h / 2, y + h))
    p.addArc(center: pt(x + w - h / 2, y + h / 2), radius: h / 2, startAngle: .pi / 2, endAngle: -.pi / 2, clockwise: true)
    p.closeSubpath(); return stroked(p, stroke)
}
func dimmed(_ alpha: CGFloat, _ draw: () -> Void) { ctx.saveGState(); ctx.setAlpha(alpha); ctx.beginTransparencyLayer(auxiliaryInfo: nil); draw(); ctx.endTransparencyLayer(); ctx.restoreGState() }

drawTile(blue)
switch variant {
case "2":
    // Two linked hexagonal rings.
    let left = hexRing(center: pt(408, 512), radius: 200, rotation: .pi / 6, stroke: 58)
    let right = hexRing(center: pt(616, 512), radius: 200, rotation: .pi / 6, stroke: 58)
    drawGlass(left, blue, stars: 25); drawGlass(right, cyan, stars: 25)
    ctx.saveGState(); ctx.clip(to: CGRect(x: 430, y: 560, width: 170, height: 200)); drawGlass(left, blue, glow: 20, stars: 10); ctx.restoreGState()
    sparkle(pt(760, 760), 30); sparkle(pt(270, 290), 18)
case "3":
    // A six-ring knot with a dimmer double behind it.
    dimmed(0.5) { drawGlass(rosette(center: pt(585, 575), spread: 86, radius: 122, stroke: 30), violet, glow: 40, stars: 10) }
    drawGlass(rosette(center: pt(450, 455), spread: 92, radius: 130, stroke: 34), blue)
    sparkle(pt(450, 455), 30); sparkle(pt(770, 780), 24)
case "4":
    // Double D: the initial, twice.
    dimmed(0.55) { drawGlass(letterD(x: 395, y: 330, w: 370, h: 440, stroke: 64), violet, glow: 40, stars: 10) }
    drawGlass(letterD(x: 275, y: 255, w: 370, h: 440, stroke: 72), blue)
    sparkle(pt(690, 800), 30); sparkle(pt(250, 250), 18)
case "5":
    // Two glass blossoms, one behind the other.
    dimmed(0.6) { drawGlass(blossom(center: pt(610, 600), spread: 112, radius: 128), violet, glow: 40, stars: 20) }
    drawGlass(blossom(center: pt(440, 440), spread: 128, radius: 146), blue)
    sparkle(pt(440, 450), 38); sparkle(pt(780, 790), 24)
default:
    // "1": two three-loop knots, one blue and one cyan, locked together into a six-loop form.
    drawGlass(trefoil(center: pt(512, 512), reach: 300, width: 190, rotation: .pi / 2, stroke: 40), blue)
    drawGlass(trefoil(center: pt(512, 512), reach: 300, width: 190, rotation: -.pi / 2, stroke: 40), cyan, glow: 40)
    sparkle(pt(512, 512), 34); sparkle(pt(770, 790), 24); sparkle(pt(262, 300), 16)
}

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
