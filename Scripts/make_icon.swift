// Generates the Smash app icon (1024x1024) with CoreGraphics.
// Run: swift Scripts/make_icon.swift <output.png>

import AppKit
import CoreGraphics

let pixelSize = 1024
let size: CGFloat = 1024
guard CommandLine.arguments.count > 1 else {
    print("usage: make_icon.swift <output.png>"); exit(1)
}
let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(
    data: nil, width: pixelSize, height: pixelSize,
    bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

// MARK: - Background: deep court-green vertical gradient

let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        CGColor(red: 0.043, green: 0.42, blue: 0.24, alpha: 1),
        CGColor(red: 0.016, green: 0.24, blue: 0.14, alpha: 1),
    ] as CFArray,
    locations: [0, 1]
)!

context.drawLinearGradient(
    gradient,
    start: CGPoint(x: size / 2, y: size),
    end: CGPoint(x: size / 2, y: 0),
    options: []
)

// MARK: - Shuttlecock

let white = CGColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 1)
let slitColor = CGColor(red: 0.55, green: 0.68, blue: 0.58, alpha: 1)
let scale = size / 1024

context.saveGState()
// Center, slight tilt for energy (apple-design: hint the gesture direction).
context.translateBy(x: size / 2, y: size / 2)
context.rotate(by: .pi / 14)

let corkY: CGFloat = -300 * scale
let topY: CGFloat = 330 * scale

// Skirt silhouette: wide-topped fan with a rounded top edge.
let skirt = CGMutablePath()
let halfTop: CGFloat = 250 * scale
skirt.move(to: CGPoint(x: -40 * scale, y: corkY))
skirt.addLine(to: CGPoint(x: -halfTop, y: topY - 60 * scale))
skirt.addQuadCurve(
    to: CGPoint(x: halfTop, y: topY - 60 * scale),
    control: CGPoint(x: 0, y: topY + 40 * scale)
)
skirt.addLine(to: CGPoint(x: 40 * scale, y: corkY))
skirt.closeSubpath()
context.setFillColor(white)
context.addPath(skirt)
context.fillPath()

// Feather separations.
context.setFillColor(slitColor)
for xOffset in [-90.0, 0.0, 90.0] {
    let x = CGFloat(xOffset) * scale
    let slit = CGMutablePath()
    slit.move(to: CGPoint(x: x - 7 * scale, y: corkY + 20 * scale))
    slit.addLine(to: CGPoint(x: x - 10 * scale, y: topY - 70 * scale))
    slit.addLine(to: CGPoint(x: x + 10 * scale, y: topY - 70 * scale))
    slit.addLine(to: CGPoint(x: x + 7 * scale, y: corkY + 20 * scale))
    slit.closeSubpath()
    context.addPath(slit)
    context.fillPath()
}

// Cork: warm leather tone with a soft band.
let corkRadius: CGFloat = 105 * scale
let corkCenter = CGPoint(x: 0, y: corkY - 20 * scale)

context.setShadow(
    offset: CGSize(width: 0, height: -8 * scale), blur: 40 * scale,
    color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35)
)
context.setFillColor(CGColor(red: 0.93, green: 0.78, blue: 0.62, alpha: 1))
context.fillEllipse(in: CGRect(
    x: corkCenter.x - corkRadius, y: corkCenter.y - corkRadius,
    width: corkRadius * 2, height: corkRadius * 2
))
context.setShadow(offset: .zero, blur: 0, color: nil)

// Band across the cork (narrower than the cork at that height so it stays inside).
context.setFillColor(CGColor(red: 0.90, green: 0.93, blue: 0.90, alpha: 1))
context.fillEllipse(in: CGRect(
    x: corkCenter.x - corkRadius * 0.82, y: corkCenter.y + corkRadius * 0.38,
    width: corkRadius * 1.64, height: corkRadius * 0.6
))

context.restoreGState()

// MARK: - Export

let image = context.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: outputURL)
print("Icon written to \(outputURL.path)")
