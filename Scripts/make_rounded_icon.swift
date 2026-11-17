// Rounds the corners of the icon artwork for use outside the app
// (README, socials) — Apple's system mask is ~22.37% radius. The App
// Store icon itself must stay square; this variant is for the web only.
// Run: swift Scripts/make_rounded_icon.swift <input.png> <output.png>

import AppKit
import CoreGraphics

guard CommandLine.arguments.count > 2 else {
    print("usage: make_rounded_icon.swift <input.png> <output.png>")
    exit(1)
}
let inURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outURL = URL(fileURLWithPath: CommandLine.arguments[2])

let nsImage = NSImage(contentsOf: inURL)!
guard let src = nsImage.cgImage(
    forProposedRect: nil, context: nil, hints: nil
) else {
    print("cannot decode \(inURL.path)"); exit(1)
}

let side = 1024
let ctx = CGContext(
    data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
ctx.interpolationQuality = .high

// Transparent background, clipped to the Apple-style rounded square.
let radius = CGFloat(side) * 0.2237
ctx.addPath(CGPath(
    roundedRect: CGRect(x: 0, y: 0, width: side, height: side),
    cornerWidth: radius, cornerHeight: radius, transform: nil
))
ctx.clip()
ctx.draw(src, in: CGRect(x: 0, y: 0, width: side, height: side))

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: outURL)
print("Rounded icon written to \(outURL.path)")
