// Generates the "Smash at speed" app icon candidates (1024x1024) with CoreGraphics.
// Run: swift Scripts/make_icon_v2.swift <variant a|b|c> <output.png>
//
// Design brief: a feather shuttlecock moving so fast that only a few feathers
// stay solid — the rest dissolve into light streaks — with a lightning flash.
//
// Geometry: in local space the cork points "up" (direction of flight) and the
// skirt is a tight, near-parallel cone trailing "down". The whole bird is
// rotated clockwise so it flies up-right; the trail (dissolving feathers,
// fragments, speed lines, bolt) breaks toward the down-left trailing side.

import AppKit
import CoreGraphics

let pixelSize = 1024
let size: CGFloat = 1024
guard CommandLine.arguments.count > 2 else {
    print("usage: make_icon_v2.swift <a|b|c> <output.png>"); exit(1)
}
let variant = CommandLine.arguments[1].lowercased()
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

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

// MARK: - Palettes

let (bgTop, bgBottom, accent, bolt): (CGColor, CGColor, CGColor, CGColor)
switch variant {
case "b":
    (bgTop, bgBottom, accent, bolt) = (
        color(0.05, 0.11, 0.20), color(0.01, 0.03, 0.07),
        color(0.28, 0.82, 0.95), color(1.0, 0.84, 0.10)
    )
case "c":
    (bgTop, bgBottom, accent, bolt) = (
        color(0.17, 0.71, 0.36), color(0.10, 0.50, 0.26),
        color(1.0, 1.0, 1.0), color(1.0, 0.89, 0.20)
    )
default: // "a"
    (bgTop, bgBottom, accent, bolt) = (
        color(0.09, 0.10, 0.11), color(0.03, 0.035, 0.04),
        color(0.19, 0.82, 0.35), color(1.0, 0.84, 0.10)
    )
}
let white = color(0.98, 0.99, 1.0)

// MARK: - Background

let gradient = CGGradient(
    colorsSpace: colorSpace, colors: [bgTop, bgBottom] as CFArray, locations: [0, 1]
)!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: size / 2, y: size),
    end: CGPoint(x: size / 2, y: 0),
    options: []
)

// MARK: - Bird (local space: flight = up, trail = down)

context.saveGState()
context.translateBy(x: size / 2 + 30 * scale, y: size / 2 + 40 * scale)
context.rotate(by: -.pi / 5) // fly up-right

// A faint beam of light along the flight path — the "flash" energy.
// Drawn first so the whole bird sits on top of it.
let beam = CGPath(
    roundedRect: CGRect(
        x: -150 * scale, y: -540 * scale, width: 300 * scale, height: 970 * scale
    ),
    cornerWidth: 150 * scale, cornerHeight: 150 * scale, transform: nil
)
context.setFillColor(color(1, 1, 1, variant == "c" ? 0.14 : 0.07))
context.addPath(beam)
context.fillPath()

func capsuleRect(width: CGFloat, from: CGFloat, to: CGFloat) -> CGRect {
    CGRect(x: -width / 2, y: min(from, to), width: width, height: abs(to - from))
}

let rootY: CGFloat = 180 * scale

func withAngle(_ degrees: CGFloat, _ body: () -> Void) {
    context.saveGState()
    context.translateBy(x: 0, y: rootY)
    context.rotate(by: degrees * .pi / 180)
    body()
    context.restoreGState()
}

func capsule(_ width: CGFloat, _ from: CGFloat, _ to: CGFloat, _ fill: CGColor) {
    let path = CGPath(
        roundedRect: capsuleRect(width: width * scale, from: from * scale, to: to * scale),
        cornerWidth: (width / 2) * scale, cornerHeight: (width / 2) * scale, transform: nil
    )
    context.setFillColor(fill)
    context.addPath(path)
    context.fillPath()
}

func fadingStreak(_ width: CGFloat, _ from: CGFloat, _ to: CGFloat) {
    let rect = capsuleRect(width: width * scale, from: from * scale, to: to * scale)
    let path = CGPath(
        roundedRect: rect, cornerWidth: (width / 2) * scale, cornerHeight: (width / 2) * scale,
        transform: nil
    )
    context.addPath(path)
    context.clip()
    let fade = CGGradient(
        colorsSpace: colorSpace,
        colors: [white, white, accent.copy(alpha: 0.0)!] as CFArray,
        locations: [0, 0.4, 1]
    )!
    context.drawLinearGradient(
        fade,
        start: CGPoint(x: 0, y: from * scale),
        end: CGPoint(x: 0, y: to * scale),
        options: []
    )
}

// Solid skirt: four near-parallel feathers form a tight, readable cone.
withAngle(-10.5) { capsule(74, -20, -430, white) }
withAngle(-3.5) { capsule(74, -20, -445, white) }
withAngle(3.5) { capsule(74, -20, -445, white) }
withAngle(10.5) { capsule(74, -20, -430, white) }

// Subtle separations between the solid feathers.
for angle in [-7.0, 0.0, 7.0] {
    withAngle(angle) {
        let slit = CGPath(
            roundedRect: capsuleRect(width: 7 * scale, from: -50 * scale, to: -400 * scale),
            cornerWidth: 3.5 * scale, cornerHeight: 3.5 * scale, transform: nil
        )
        context.setFillColor(color(0.75, 0.78, 0.76, 0.85))
        context.addPath(slit)
        context.fillPath()
    }
}

// Trailing feathers dissolved into streaks — thin, long, fading out.
withAngle(-22) { fadingStreak(30, -20, -560) }
withAngle(-31) { fadingStreak(26, -20, -540) }

// Detached fragments left behind by the speed, further down the trail.
for (angle, start, len, alpha) in [(-22.0, 600.0, 120.0, 0.95), (-31.0, 570.0, 90.0, 0.7), (-40.0, 520.0, 60.0, 0.45)] {
    withAngle(angle) {
        capsule(17, -start, -start - len, accent.copy(alpha: alpha)!)
    }
}

// Cork head, seated right on the skirt mouth (no gap), with the white
// leather band as a cap on the skirt-facing side of the ball.
let corkCenter = CGPoint(x: 0, y: 228 * scale)
let corkRadius: CGFloat = 96 * scale
let corkRect = CGRect(
    x: corkCenter.x - corkRadius, y: corkCenter.y - corkRadius,
    width: corkRadius * 2, height: corkRadius * 2
)
context.setFillColor(color(0.95, 0.80, 0.64))
context.fillEllipse(in: corkRect)
context.saveGState()
context.addEllipse(in: corkRect)
context.clip()
// Band: a strip across the lower ~28% of the ball — the side that meets the skirt.
context.setFillColor(color(0.96, 0.97, 0.96))
context.fill(CGRect(
    x: corkCenter.x - corkRadius * 1.2, y: corkCenter.y - corkRadius - 2 * scale,
    width: corkRadius * 2.4, height: corkRadius * 0.55 + 2 * scale
))
context.restoreGState()

context.restoreGState() // undo bird rotation

// MARK: - Lightning flash along the trail

let boltCenter = CGPoint(x: size * 0.24, y: size * 0.30)
let boltScale: CGFloat = 88 * scale
let boltPath = CGMutablePath()
let boltPoints: [(CGFloat, CGFloat)] = [
    (0.28, 1.0), (-0.40, -0.05), (-0.04, -0.05), (-0.28, -1.0),
    (0.40, 0.12), (0.04, 0.12),
]
boltPath.move(to: CGPoint(x: boltCenter.x + boltPoints[0].0 * boltScale, y: boltCenter.y + boltPoints[0].1 * boltScale))
for p in boltPoints.dropFirst() {
    boltPath.addLine(to: CGPoint(x: boltCenter.x + p.0 * boltScale, y: boltCenter.y + p.1 * boltScale))
}
boltPath.closeSubpath()
context.setShadow(offset: .zero, blur: 30 * scale, color: bolt.copy(alpha: 0.8)!)
context.setFillColor(bolt)
context.addPath(boltPath)
context.fillPath()
context.setShadow(offset: .zero, blur: 0, color: nil)

// MARK: - Export

let image = context.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: outputURL)
print("Icon \(variant.uppercased()) written to \(outputURL.path)")
