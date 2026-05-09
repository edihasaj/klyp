#!/usr/bin/env swift
import AppKit

guard CommandLine.arguments.count >= 2 else {
    fputs("usage: generate-icon.swift <output-appiconset-dir>\n", stderr)
    exit(1)
}

let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func renderIcon(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    let s = size

    // Squircle clip (Big Sur–style corner radius ≈ 22.37% of side).
    let cornerRadius = s * 0.2237
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
    ctx.clip()

    // Diagonal gradient: indigo → hot pink.
    let bgColors = [
        CGColor(red: 0.42, green: 0.32, blue: 0.96, alpha: 1.0),
        CGColor(red: 1.00, green: 0.40, blue: 0.62, alpha: 1.0),
    ] as CFArray
    let bgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors, locations: [0, 1])!
    ctx.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])

    // Soft top-light glaze.
    ctx.saveGState()
    ctx.setBlendMode(.softLight)
    ctx.setFillColor(CGColor(gray: 1, alpha: 0.35))
    ctx.fill(CGRect(x: 0, y: s * 0.55, width: s, height: s * 0.45))
    ctx.restoreGState()

    // Three offset rounded "cards" — clipboard history stack.
    let cardW = s * 0.56
    let cardH = s * 0.66
    let cx = s / 2
    let cy = s / 2
    let cardCorner = s * 0.07

    let offsets: [(x: CGFloat, y: CGFloat, alpha: CGFloat)] = [
        (-s * 0.07, -s * 0.07, 0.32),
        (0, 0, 0.62),
        (s * 0.07, s * 0.07, 1.00),
    ]

    for off in offsets {
        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: -s * 0.006),
            blur: s * 0.03,
            color: CGColor(gray: 0, alpha: 0.30)
        )
        ctx.setFillColor(CGColor(gray: 1, alpha: off.alpha))
        ctx.addPath(CGPath(
            roundedRect: CGRect(x: cx - cardW / 2 + off.x,
                                y: cy - cardH / 2 + off.y,
                                width: cardW, height: cardH),
            cornerWidth: cardCorner, cornerHeight: cardCorner, transform: nil
        ))
        ctx.fillPath()
        ctx.restoreGState()
    }

    // Three text-line bars on the topmost card.
    let topCardX = cx - cardW / 2 + s * 0.07
    let topCardY = cy - cardH / 2 + s * 0.07
    let lineColor = CGColor(red: 0.36, green: 0.32, blue: 0.55, alpha: 0.85)
    ctx.setFillColor(lineColor)
    let lineH = max(s * 0.035, 1)
    let lineWidths: [CGFloat] = [cardW * 0.70, cardW * 0.55, cardW * 0.40]
    let lineGap = s * 0.095
    let firstLineY = topCardY + cardH - s * 0.18
    let lineX = topCardX + s * 0.06
    for (i, w) in lineWidths.enumerated() {
        let y = firstLineY - CGFloat(i) * lineGap
        ctx.addPath(CGPath(
            roundedRect: CGRect(x: lineX, y: y, width: w, height: lineH),
            cornerWidth: lineH / 2, cornerHeight: lineH / 2, transform: nil
        ))
        ctx.fillPath()
    }

    // Pin accent (warm gold → orange) at top-right of top card.
    let pinSize = s * 0.13
    let pinX = topCardX + cardW - pinSize - s * 0.05
    let pinY = topCardY + cardH - pinSize - s * 0.05
    let pinColors = [
        CGColor(red: 1.0, green: 0.86, blue: 0.40, alpha: 1.0),
        CGColor(red: 1.0, green: 0.50, blue: 0.20, alpha: 1.0),
    ] as CFArray
    let pinGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: pinColors, locations: [0, 1])!
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -s * 0.005),
        blur: s * 0.02,
        color: CGColor(gray: 0, alpha: 0.4)
    )
    ctx.addEllipse(in: CGRect(x: pinX, y: pinY, width: pinSize, height: pinSize))
    ctx.clip()
    ctx.drawLinearGradient(pinGradient,
                           start: CGPoint(x: pinX, y: pinY + pinSize),
                           end: CGPoint(x: pinX + pinSize, y: pinY),
                           options: [])
    ctx.restoreGState()

    img.unlockFocus()
    return img
}

func savePNG(image: NSImage, size: CGFloat, to url: URL) {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 32
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
               from: .zero, operation: .copy, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()
    let png = bitmap.representation(using: .png, properties: [:])!
    try! png.write(to: url)
}

let sizes: [(file: String, px: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for s in sizes {
    let img = renderIcon(size: s.px)
    savePNG(image: img, size: s.px, to: outDir.appendingPathComponent(s.file))
}

let contents = """
{
  "images" : [
    { "size" : "16x16",   "idiom" : "mac", "filename" : "icon_16x16.png",     "scale" : "1x" },
    { "size" : "16x16",   "idiom" : "mac", "filename" : "icon_16x16@2x.png",  "scale" : "2x" },
    { "size" : "32x32",   "idiom" : "mac", "filename" : "icon_32x32.png",     "scale" : "1x" },
    { "size" : "32x32",   "idiom" : "mac", "filename" : "icon_32x32@2x.png",  "scale" : "2x" },
    { "size" : "128x128", "idiom" : "mac", "filename" : "icon_128x128.png",    "scale" : "1x" },
    { "size" : "128x128", "idiom" : "mac", "filename" : "icon_128x128@2x.png", "scale" : "2x" },
    { "size" : "256x256", "idiom" : "mac", "filename" : "icon_256x256.png",    "scale" : "1x" },
    { "size" : "256x256", "idiom" : "mac", "filename" : "icon_256x256@2x.png", "scale" : "2x" },
    { "size" : "512x512", "idiom" : "mac", "filename" : "icon_512x512.png",    "scale" : "1x" },
    { "size" : "512x512", "idiom" : "mac", "filename" : "icon_512x512@2x.png", "scale" : "2x" }
  ],
  "info" : { "version" : 1, "author" : "xcode" }
}
"""
try contents.write(to: outDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

print("✓ Generated \(sizes.count) icons in \(outDir.path)")
