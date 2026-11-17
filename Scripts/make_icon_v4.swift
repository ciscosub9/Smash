// Generates the "Smash slam" icon (1024x1024) with CoreGraphics.
// Run: swift Scripts/make_icon_v4.swift <output.png>
//
// Same mascot design as v3 (fan of color-edged blades, blue-swoosh cork,
// bold outlines) but: black background, the shuttle tilted cork-DOWN so the
// base touches the ground, and One Piece Haki-style red lightning crackling
// from the point of contact.

import AppKit
import CoreGraphics

let pixelSize = 1024
let size: CGFloat = 1024
guard CommandLine.arguments.count > 1 else {
    print("usage: make_icon_v4.swift <output.png>"); exit(1)
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

// MARK: - Palette

let outline = color(0.96, 0.97, 0.96)
let cream = color(0.98, 0.94, 0.86)
let faceWhite = color(0.99, 0.99, 0.99)
let green = color(0.16, 0.78, 0.44)
let orange = color(0.98, 0.62, 0.16)
let red = color(0.94, 0.20, 0.16)
let blue = color(0.16, 0.62, 0.94)
let hakiRed = color(1.0, 0.20, 0.15)

// Background — near-black, flat.
context.setFillColor(color(0.02, 0.02, 0.03))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Contact point where the cork meets the ground.
let contact = CGPoint(x: 460 * scale, y: 118 * scale)

// MARK: - Ground glow + ground line

let glow = CGGradient(
    colorsSpace: colorSpace,
    colors: [hakiRed.copy(alpha: 0.32)!, hakiRed.copy(alpha: 0.0)!] as CFArray,
    locations: [0, 1]
)!
context.drawRadialGradient(
    glow,
    startCenter: contact, startRadius: 0,
    endCenter: contact, endRadius: 250 * scale,
    options: []
)

context.setStrokeColor(color(1, 1, 1, 0.16))
context.setLineWidth(5 * scale)
context.setLineCap(.round)
context.addLines(between: [
    CGPoint(x: 250 * scale, y: 112 * scale),
    CGPoint(x: 670 * scale, y: 112 * scale),
])
context.strokePath()

// MARK: - Shuttle (tilted slightly, as if it just slammed down)

context.saveGState()
context.translateBy(x: contact.x, y: contact.y)
context.rotate(by: -6 * .pi / 180)
context.translateBy(x: -contact.x, y: -contact.y)

// MARK: Fan of feather blades

let pivot = CGPoint(x: 460 * scale, y: 330 * scale)

struct BladeSpec {
    var tilt: CGFloat
    var len: CGFloat
    var width: CGFloat
    var sweep: CGFloat
    var edge: CGColor?
}

let blades = [
    BladeSpec(tilt: 26, len: 410, width: 148, sweep: 90, edge: green),
    BladeSpec(tilt: 4, len: 435, width: 150, sweep: 115, edge: nil),
    BladeSpec(tilt: -18, len: 415, width: 145, sweep: 140, edge: orange),
    BladeSpec(tilt: -40, len: 350, width: 142, sweep: 160, edge: red),
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

    context.setFillColor(spec.edge ?? faceWhite)
    context.addPath(body)
    context.fillPath()

    // White streak inside so the body color dominates.
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

    context.setStrokeColor(outline)
    context.setLineWidth(14 * scale)
    context.setLineJoin(.round)
    context.addPath(body)
    context.strokePath()

    context.restoreGState()
}

// MARK: Cork at the base

let corkCenter = CGPoint(x: 460 * scale, y: 235 * scale)
let corkRadius: CGFloat = 112 * scale
let corkRect = CGRect(
    x: corkCenter.x - corkRadius, y: corkCenter.y - corkRadius,
    width: corkRadius * 2, height: corkRadius * 2
)
context.setFillColor(cream)
context.fillEllipse(in: corkRect)
context.setStrokeColor(outline)
context.setLineWidth(14 * scale)
context.strokeEllipse(in: corkRect)

// Blue swoosh hugging the inside rim of the cork.
context.setStrokeColor(blue)
context.setLineWidth(26 * scale)
context.setLineCap(.round)
context.addArc(
    center: corkCenter, radius: corkRadius * 0.70,
    startAngle: .pi * 0.58, endAngle: .pi * 1.62, clockwise: false
)
context.strokePath()

context.restoreGState() // shuttle tilt

// MARK: - Haki lightning crackling from the contact point

func bolt(_ points: [(CGFloat, CGFloat)], width: CGFloat) {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: points[0].0 * scale, y: points[0].1 * scale))
    for pt in points.dropFirst() {
        p.addLine(to: CGPoint(x: pt.0 * scale, y: pt.1 * scale))
    }
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setStrokeColor(hakiRed)
    context.setLineWidth(width * scale)
    context.addPath(p)
    context.strokePath()
    // White-hot core.
    context.setStrokeColor(color(1, 1, 1, 0.92))
    context.setLineWidth(width * 0.38 * scale)
    context.addPath(p)
    context.strokePath()
}

bolt([(460, 118), (370, 123), (345, 143), (250, 97), (215, 119), (120, 69)], width: 13)
bolt([(460, 118), (545, 117), (575, 135), (668, 87), (700, 107), (795, 65)], width: 13)
bolt([(460, 118), (448, 101), (472, 71)], width: 11)
bolt([(372, 170), (320, 225), (292, 214), (255, 286)], width: 9)
bolt([(548, 168), (596, 222), (626, 210), (668, 282)], width: 9)

// MARK: - Export

let image = context.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: outputURL)
print("Icon written to \(outputURL.path)")
