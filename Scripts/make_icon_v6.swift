// Generates the "Smash premium" icon (1024x1024) with CoreGraphics.
// Run: swift Scripts/make_icon_v6.swift <output.png>
//
// Developed from the user's own design: real-shuttle silhouette (V-notched
// feather skirt, black neck band, cream cork) on a near-black background,
// plus the two signature elements from their artwork — red speed streaks
// cutting diagonally behind the shuttle, and the white string lattice
// binding the lower skirt.

import AppKit
import CoreGraphics

let pixelSize = 1024
let size: CGFloat = 1024
guard CommandLine.arguments.count > 1 else {
    print("usage: make_icon_v6.swift <output.png>"); exit(1)
}
let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(
    data: nil, width: pixelSize, height: pixelSize,
    bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
let scale = size / 1024

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

let black = color(0.01, 0.01, 0.02)
let white = color(0.99, 0.99, 0.99)
let cream = color(0.98, 0.94, 0.86)
let speedRed = color(1.0, 0.16, 0.12)

// Background — near-black with a faint center glow.
let bg = CGGradient(
    colorsSpace: colorSpace,
    colors: [color(0.10, 0.10, 0.115), color(0.015, 0.015, 0.02)] as CFArray,
    locations: [0, 1]
)!
context.drawRadialGradient(
    bg,
    startCenter: CGPoint(x: 480 * scale, y: 560 * scale), startRadius: 0,
    endCenter: CGPoint(x: 480 * scale, y: 560 * scale), endRadius: 780 * scale,
    options: []
)

// MARK: - Red speed streaks (behind the shuttle, diagonal like the artwork)

func streak(_ from: CGPoint, _ to: CGPoint, width: CGFloat, alpha: CGFloat) {
    let line = CGMutablePath()
    line.move(to: CGPoint(x: from.x * scale, y: from.y * scale))
    line.addLine(to: CGPoint(x: to.x * scale, y: to.y * scale))
    // Glow pass.
    context.setStrokeColor(speedRed.copy(alpha: alpha * 0.28)!)
    context.setLineWidth(width * 2.6 * scale)
    context.setLineCap(.round)
    context.addPath(line)
    context.strokePath()
    // Bright core.
    context.setStrokeColor(speedRed.copy(alpha: alpha)!)
    context.setLineWidth(width * scale)
    context.addPath(line)
    context.strokePath()
}

// Upper-right cluster: trailing the tip, parallel to the skirt axis,
// lower ends tucked behind the skirt (drawn before the feathers).
streak(CGPoint(x: 529, y: 554), CGPoint(x: 711, y: 738), width: 13, alpha: 0.95)
streak(CGPoint(x: 588, y: 536), CGPoint(x: 756, y: 704), width: 9, alpha: 0.7)
streak(CGPoint(x: 645, y: 516), CGPoint(x: 775, y: 646), width: 7, alpha: 0.5)

// Lower-left cluster: trailing the cork, upper ends tucked behind the ball.
streak(CGPoint(x: 142, y: 158), CGPoint(x: 270, y: 340), width: 10, alpha: 0.75)
streak(CGPoint(x: 60, y: 172), CGPoint(x: 134, y: 326), width: 7, alpha: 0.5)
streak(CGPoint(x: 135, y: 239), CGPoint(x: 195, y: 365), width: 5, alpha: 0.35)

// MARK: - Feather skirt (five overlapping feathers, V-notched mouth)

struct Feather {
    var root: CGPoint   // canvas units, inside the cork
    var tip: CGPoint
}

let feathers = [
    Feather(root: CGPoint(x: 335, y: 370), tip: CGPoint(x: 395, y: 796)),
    Feather(root: CGPoint(x: 345, y: 368), tip: CGPoint(x: 476, y: 796)),
    Feather(root: CGPoint(x: 355, y: 365), tip: CGPoint(x: 553, y: 771)),
    Feather(root: CGPoint(x: 365, y: 360), tip: CGPoint(x: 622, y: 727)),
    Feather(root: CGPoint(x: 375, y: 355), tip: CGPoint(x: 674, y: 664)),
]

let quillHalf: CGFloat = 22
let vaneHalf: CGFloat = 74
let hook: CGFloat = 20

func featherParts(_ f: Feather) -> (body: CGPath, shaft: CGPath, angle: CGFloat) {
    let dx = (f.tip.x - f.root.x) * scale
    let dy = (f.tip.y - f.root.y) * scale
    let len = sqrt(dx * dx + dy * dy)
    let angle = atan2(dx, dy)

    let b = quillHalf * scale
    let w = vaneHalf * scale
    let h = hook * scale
    let body = CGMutablePath()
    body.move(to: CGPoint(x: -b, y: 0))
    body.addCurve(
        to: CGPoint(x: h, y: len),
        control1: CGPoint(x: -w * 0.90, y: len * 0.30),
        control2: CGPoint(x: -w * 0.55, y: len * 0.74)
    )
    body.addCurve(
        to: CGPoint(x: b, y: 0),
        control1: CGPoint(x: w * 1.10, y: len * 0.68),
        control2: CGPoint(x: w * 0.85, y: len * 0.22)
    )
    body.closeSubpath()

    let shaft = CGMutablePath()
    shaft.move(to: CGPoint(x: 0, y: len * 0.05))
    shaft.addQuadCurve(
        to: CGPoint(x: h * 0.9, y: len * 0.82),
        control: CGPoint(x: h * 0.25, y: len * 0.45)
    )
    return (body, shaft, angle)
}

func inFeatherSpace(_ f: Feather, _ angle: CGFloat, _ body: () -> Void) {
    context.saveGState()
    context.translateBy(x: f.root.x * scale, y: f.root.y * scale)
    context.rotate(by: -angle)
    body()
    context.restoreGState()
}

let drawOrder = [4, 3, 2, 1, 0]
let parts = feathers.map(featherParts)

for i in drawOrder {
    inFeatherSpace(feathers[i], parts[i].angle) {
        context.setFillColor(white)
        context.addPath(parts[i].body)
        context.fillPath()
    }
}
// MARK: - Lower-skirt shading + string lattice (from the artwork)

// Skirt-local frame: origin at the cork center, axis unit u (cork → mouth),
// perpendicular p.
let skO = CGPoint(x: 330, y: 300)
let skU = CGVector(dx: 0.430, dy: 0.902)
let skP = CGVector(dx: -0.902, dy: 0.430)
func sk(_ s: CGFloat, _ t: CGFloat) -> CGPoint {
    CGPoint(
        x: (skO.x + skU.dx * s + skP.dx * t) * scale,
        y: (skO.y + skU.dy * s + skP.dy * t) * scale
    )
}

// Clip = union of the five feather bodies (all wind the same way, so the
// nonzero rule unions the overlaps) — shading and strings stay on the skirt.
let skirtMask = CGMutablePath()
for i in drawOrder {
    let t = CGAffineTransform(
        translationX: feathers[i].root.x * scale, y: feathers[i].root.y * scale
    ).rotated(by: -parts[i].angle)
    skirtMask.addPath(parts[i].body, transform: t)
}

context.saveGState()
context.addPath(skirtMask)
context.clip()

// Soft shadow rising from the neck, so the white mesh reads on the skirt.
let skirtShade = CGGradient(
    colorsSpace: colorSpace,
    colors: [color(0.36, 0.35, 0.33, 0.55), color(0.36, 0.35, 0.33, 0.0)] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    skirtShade,
    start: sk(90, 0), end: sk(290, 0),
    options: []
)

// Bold diamond mesh binding the lower skirt, like the artwork's netting.
context.setStrokeColor(white)
context.setLineWidth(9 * scale)
context.setLineCap(.round)

for s in [135.0, 185, 235, 285] {
    let line = CGMutablePath()
    line.move(to: sk(s, 300))
    line.addQuadCurve(to: sk(s, -300), control: sk(s + 26, 0))
    context.addPath(line)
    context.strokePath()
}
for t in [-130.0, -65, 0, 65, 130] {
    let line = CGMutablePath()
    line.move(to: sk(120, t))
    line.addQuadCurve(to: sk(290, t), control: sk(205, t * 1.05))
    context.addPath(line)
    context.strokePath()
}

context.restoreGState()

// Outlines and shafts go on top so the line work stays crisp.
for i in drawOrder {
    inFeatherSpace(feathers[i], parts[i].angle) {
        context.setStrokeColor(black)
        context.setLineWidth(13 * scale)
        context.setLineJoin(.round)
        context.addPath(parts[i].body)
        context.strokePath()
    }
}
for i in drawOrder {
    inFeatherSpace(feathers[i], parts[i].angle) {
        context.setStrokeColor(black)
        context.setLineWidth(5 * scale)
        context.setLineCap(.round)
        context.addPath(parts[i].shaft)
        context.strokePath()
    }
}

// MARK: - Cork with black neck band

let corkCenter = CGPoint(x: 330 * scale, y: 300 * scale)
let corkRadius: CGFloat = 92 * scale
let corkRect = CGRect(
    x: corkCenter.x - corkRadius, y: corkCenter.y - corkRadius,
    width: corkRadius * 2, height: corkRadius * 2
)

// Subtle shading so the ball isn't dead flat.
let corkShade = CGGradient(
    colorsSpace: colorSpace,
    colors: [color(1.0, 0.98, 0.94), color(0.93, 0.87, 0.76)] as CFArray,
    locations: [0, 1]
)!
context.saveGState()
context.addEllipse(in: corkRect)
context.clip()
context.drawLinearGradient(
    corkShade,
    start: CGPoint(x: corkCenter.x - corkRadius, y: corkCenter.y + corkRadius),
    end: CGPoint(x: corkCenter.x + corkRadius, y: corkCenter.y - corkRadius),
    options: []
)
context.restoreGState()

context.setStrokeColor(black)
context.setLineWidth(13 * scale)
context.strokeEllipse(in: corkRect)

// Black leather band around the neck, perpendicular to the skirt axis.
context.saveGState()
context.addEllipse(in: corkRect)
context.clip()
context.translateBy(x: corkCenter.x, y: corkCenter.y)
context.rotate(by: -26 * .pi / 180)
context.setFillColor(black)
context.fill(CGRect(
    x: -corkRadius * 1.1, y: corkRadius * 0.52,
    width: corkRadius * 2.2, height: corkRadius * 0.30
))
context.restoreGState()

// MARK: - Export

let image = context.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: outputURL)
print("Icon written to \(outputURL.path)")
