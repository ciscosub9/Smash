// Generates the "Smash classic" icon (1024x1024) with CoreGraphics.
// Run: swift Scripts/make_icon_v5.swift <output.png>
//
// Black background, white feathers fanning up-right from a cream cork —
// real-shuttle anatomy: narrow quills at the base, vanes widening toward
// the sharp tips, a center shaft on every feather.

import AppKit
import CoreGraphics

let pixelSize = 1024
let size: CGFloat = 1024
guard CommandLine.arguments.count > 1 else {
    print("usage: make_icon_v5.swift <output.png>"); exit(1)
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

// Background — black.
context.setFillColor(black)
context.fill(CGRect(x: 0, y: 0, width: size, height: size))

// MARK: - Feather blades (real-shuttle anatomy: narrow quill at the base,
// vane widening to ~70% up, sharp tip, visible center shaft)

struct Feather {
    var root: CGPoint   // canvas units, inside the ball
    var tip: CGPoint
}

// Five feathers, tight overlap — each tip emerges from behind the next,
// creating the V-notched mouth edge of a real skirt.
let feathers = [
    Feather(root: CGPoint(x: 335, y: 370), tip: CGPoint(x: 395, y: 796)),
    Feather(root: CGPoint(x: 345, y: 368), tip: CGPoint(x: 476, y: 796)),
    Feather(root: CGPoint(x: 355, y: 365), tip: CGPoint(x: 553, y: 771)),
    Feather(root: CGPoint(x: 365, y: 360), tip: CGPoint(x: 622, y: 727)),
    Feather(root: CGPoint(x: 375, y: 355), tip: CGPoint(x: 674, y: 664)),
]

let quillHalf: CGFloat = 22   // half-width at the base
let vaneHalf: CGFloat = 74    // half-width at the widest point
let hook: CGFloat = 20        // tip pull, blade-local

func featherParts(_ f: Feather) -> (body: CGPath, shaft: CGPath, angle: CGFloat) {
    let dx = (f.tip.x - f.root.x) * scale
    let dy = (f.tip.y - f.root.y) * scale
    let len = sqrt(dx * dx + dy * dy)
    let angle = atan2(dx, dy) // degrees-from-vertical, positive = right

    let b = quillHalf * scale
    let w = vaneHalf * scale
    let h = hook * scale
    let body = CGMutablePath()
    // Outer edge: quill widens steadily into the vane.
    body.move(to: CGPoint(x: -b, y: 0))
    body.addCurve(
        to: CGPoint(x: h, y: len),
        control1: CGPoint(x: -w * 0.90, y: len * 0.30),
        control2: CGPoint(x: -w * 0.55, y: len * 0.74)
    )
    // Inner edge: vane tapers back to the quill.
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

// Draw back to front: rightmost feather first, front-left last —
// each tip emerges from behind the next, forming the V-notched mouth.
let drawOrder = [4, 3, 2, 1, 0]
let parts = feathers.map(featherParts)

// Fill pass (white vanes).
for i in drawOrder {
    inFeatherSpace(feathers[i], parts[i].angle) {
        context.setFillColor(white)
        context.addPath(parts[i].body)
        context.fillPath()
    }
}

// Stroke pass — every feather fully outlined, even where it crosses another.
for i in drawOrder {
    inFeatherSpace(feathers[i], parts[i].angle) {
        context.setStrokeColor(black)
        context.setLineWidth(13 * scale)
        context.setLineJoin(.round)
        context.addPath(parts[i].body)
        context.strokePath()
    }
}

// Center shafts (the quill line on each feather, stopping before the tip).
for i in drawOrder {
    inFeatherSpace(feathers[i], parts[i].angle) {
        context.setStrokeColor(black)
        context.setLineWidth(5 * scale)
        context.setLineCap(.round)
        context.addPath(parts[i].shaft)
        context.strokePath()
    }
}

// MARK: - Cork (drawn last so it covers the blade roots)

let corkCenter = CGPoint(x: 330 * scale, y: 300 * scale)
let corkRadius: CGFloat = 92 * scale
let corkRect = CGRect(
    x: corkCenter.x - corkRadius, y: corkCenter.y - corkRadius,
    width: corkRadius * 2, height: corkRadius * 2
)
context.setFillColor(cream)
context.fillEllipse(in: corkRect)
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
    x: -corkRadius * 1.1, y: corkRadius * 0.42,
    width: corkRadius * 2.2, height: corkRadius * 0.20
))
context.restoreGState()

// MARK: - Export

let image = context.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: outputURL)
print("Icon written to \(outputURL.path)")
