// Generates the "Smash fan" icon candidates (1024x1024) with CoreGraphics.
// Run: swift Scripts/make_icon_v3.swift <variant w|d> <output.png>
//
// Reference direction: mascot-style shuttlecock — a fan of sharp, swept-back
// feather blades with bold outlines and vivid color edges, a cork with a blue
// swoosh at the base, and motion arcs trailing behind. Variants:
//   w = white background, black outlines (truest to the reference)
//   d = charcoal background, white outlines (dark-mode sticker look)

import AppKit
import CoreGraphics

let pixelSize = 1024
let size: CGFloat = 1024
guard CommandLine.arguments.count > 2 else {
    print("usage: make_icon_v3.swift <w|d> <output.png>"); exit(1)
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

// MARK: - Palette

let dark = variant == "d"
let outline = dark ? color(0.96, 0.97, 0.96) : color(0.05, 0.05, 0.06)
let cream = color(0.98, 0.94, 0.86)
let faceWhite = color(0.99, 0.99, 0.99)
let green = color(0.16, 0.78, 0.44)
let orange = color(0.98, 0.62, 0.16)
let red = color(0.94, 0.20, 0.16)
let blue = color(0.16, 0.62, 0.94)

// Background — flat, no gradient (the reference is a flat badge).
context.setFillColor(dark ? color(0.08, 0.09, 0.10) : color(0.99, 0.99, 0.98))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))

// MARK: - Motion arcs (trailing the cork, drawn behind everything)

context.setStrokeColor(outline)
context.setLineCap(.round)
context.setLineWidth(11 * scale)
context.addArc(
    center: CGPoint(x: 400 * scale, y: 305 * scale), radius: 145 * scale,
    startAngle: .pi * 0.78, endAngle: .pi * 1.06, clockwise: false
)
context.strokePath()
context.setLineWidth(9 * scale)
context.addArc(
    center: CGPoint(x: 430 * scale, y: 315 * scale), radius: 190 * scale,
    startAngle: .pi * 0.82, endAngle: .pi * 1.00, clockwise: false
)
context.strokePath()

// MARK: - Fan of feather blades

let pivot = CGPoint(x: 440 * scale, y: 340 * scale)

struct BladeSpec {
    var tilt: CGFloat    // degrees from vertical; positive tilts left
    var len: CGFloat
    var width: CGFloat
    var sweep: CGFloat   // how far the tip pulls sideways (the "speed" bend)
    var edge: CGColor?   // colored sliver along the outer edge
}

let blades = [
    BladeSpec(tilt: 24, len: 430, width: 150, sweep: 90, edge: green),
    BladeSpec(tilt: 0, len: 450, width: 150, sweep: 120, edge: nil),
    BladeSpec(tilt: -26, len: 420, width: 145, sweep: 150, edge: orange),
    BladeSpec(tilt: -52, len: 340, width: 140, sweep: 170, edge: red),
]

/// A blade: sharp at base and tip, widest mid-length, bent by `sweep`.
func bladePath(width: CGFloat, len: CGFloat, sweep: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let b1 = CGPoint(x: -width / 2, y: 0)
    let b2 = CGPoint(x: width / 2, y: 0)
    let tip = CGPoint(x: sweep, y: len)
    let cOut = CGPoint(x: -width * 0.95 + sweep * 0.25, y: len * 0.52)
    let cIn = CGPoint(x: width * 0.60 + sweep * 0.78, y: len * 0.45)
    p.move(to: b1)
    p.addQuadCurve(to: tip, control: cOut)
    p.addQuadCurve(to: b2, control: cIn)
    p.closeSubpath()
    return p
}

for spec in blades {
    context.saveGState()
    context.translateBy(x: pivot.x, y: pivot.y)
    context.rotate(by: spec.tilt * .pi / 180)

    let body = bladePath(width: spec.width * scale, len: spec.len * scale, sweep: spec.sweep * scale)

    // Colored blade body.
    context.setFillColor(spec.edge ?? faceWhite)
    context.addPath(body)
    context.fillPath()

    // White face as a streak inside, so the body color dominates —
    // matching the reference where color fills most of each blade.
    if spec.edge != nil {
        context.saveGState()
        context.translateBy(x: spec.width * 0.08 * scale, y: spec.len * 0.015 * scale)
        let whiteFace = bladePath(
            width: spec.width * 0.50 * scale,
            len: spec.len * 0.985 * scale,
            sweep: spec.sweep * 0.88 * scale
        )
        context.setFillColor(faceWhite)
        context.addPath(whiteFace)
        context.fillPath()
        context.restoreGState()
    }

    // Bold mascot outline.
    context.setStrokeColor(outline)
    context.setLineWidth(14 * scale)
    context.setLineJoin(.round)
    context.addPath(body)
    context.strokePath()

    context.restoreGState()
}

// MARK: - Cork (drawn last so it covers the blade roots)

let corkCenter = CGPoint(x: 440 * scale, y: 310 * scale)
let corkRadius: CGFloat = 110 * scale
let corkRect = CGRect(
    x: corkCenter.x - corkRadius, y: corkCenter.y - corkRadius,
    width: corkRadius * 2, height: corkRadius * 2
)
context.setFillColor(cream)
context.fillEllipse(in: corkRect)
context.setStrokeColor(outline)
context.setLineWidth(13 * scale)
context.strokeEllipse(in: corkRect)

// Blue swoosh hugging the inside rim of the cork, left around the bottom.
context.setStrokeColor(blue)
context.setLineWidth(26 * scale)
context.setLineCap(.round)
context.addArc(
    center: corkCenter, radius: corkRadius * 0.72,
    startAngle: .pi * 0.58, endAngle: .pi * 1.62, clockwise: false
)
context.strokePath()

// MARK: - Export

let image = context.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: outputURL)
print("Icon \(variant.uppercased()) written to \(outputURL.path)")
