// Trims the badge out of the user's finished artwork and exports an
// Apple-guideline app icon: 1024x1024, square, fully opaque (the system
// applies the corner mask itself).
// Run: swift Scripts/make_icon_from_png.swift <input.png> <output.png>

import AppKit
import CoreGraphics
import ImageIO

guard CommandLine.arguments.count > 2 else {
    print("usage: make_icon_from_png.swift <input.png> <output.png>")
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
let w = src.width
let h = src.height

// Read pixels.
let ctx = CGContext(
    data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
ctx.draw(src, in: CGRect(x: 0, y: 0, width: w, height: h))
let buf = ctx.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)

// Bounding box of everything above near-black (the badge vs. the margin).
let threshold: UInt8 = 14
var minX = w, maxX = 0, minY = h, maxY = 0
for y in 0..<h {
    for x in 0..<w {
        let i = (y * w + x) * 4
        if max(buf[i], max(buf[i + 1], buf[i + 2])) > threshold {
            if x < minX { minX = x }
            if x > maxX { maxX = x }
            if y < minY { minY = y }
            if y > maxY { maxY = y }
        }
    }
}
print("image \(w)x\(h), content bbox x[\(minX),\(maxX)] y[\(minY),\(maxY)]")
let bw = maxX - minX + 1, bh = maxY - minY + 1
print("badge \(bw)x\(bh) — fills \(String(format: "%.1f", Double(bw) / Double(w) * 100))% × \(String(format: "%.1f", Double(bh) / Double(h) * 100))%")

// Crop to the badge (CGImage crop rect is top-left based).
let crop = src.cropping(to: CGRect(
    x: CGFloat(minX), y: CGFloat(h - maxY - 1),
    width: CGFloat(bw), height: CGFloat(bh)
))!

// Render onto black at exactly 1024x1024, opaque.
let out = CGContext(
    data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
out.interpolationQuality = .high
out.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
out.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
out.draw(crop, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))

let image = out.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: outURL)
print("Icon written to \(outURL.path)")
