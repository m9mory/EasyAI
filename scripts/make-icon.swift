// Generated icon renderer — kept in the repo for reference; the PNGs under
// EasyAI/Assets.xcassets/AppIcon.appiconset are the committed output.
//
// Usage: swift scripts/make-icon.swift   (on macOS, with AppKit)
import AppKit

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let context = NSGraphicsContext.current!.cgContext
let space = CGColorSpaceCreateDeviceRGB()

// Background gradient (indigo → violet).
let colors = [
    NSColor(srgbRed: 0.24, green: 0.22, blue: 0.72, alpha: 1).cgColor,
    NSColor(srgbRed: 0.55, green: 0.28, blue: 0.92, alpha: 1).cgColor
] as CFArray
let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
context.drawLinearGradient(gradient,
                           start: CGPoint(x: 0, y: size),
                           end: CGPoint(x: size, y: 0),
                           options: [])

// Sparkle glyph.
let config = NSImage.SymbolConfiguration(pointSize: 520, weight: .semibold)
if let symbol = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let tinted = NSImage(size: symbol.size)
    tinted.lockFocus()
    NSColor.white.set()
    let rect = NSRect(origin: .zero, size: symbol.size)
    symbol.draw(in: rect)
    rect.fill(using: .sourceAtop)
    tinted.unlockFocus()

    let target = NSSize(width: 560, height: 560 * symbol.size.height / symbol.size.width)
    let origin = NSPoint(x: (size - target.width) / 2, y: (size - target.height) / 2)
    tinted.draw(in: NSRect(origin: origin, size: target))
}

image.unlockFocus()

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "EasyAI/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
print("wrote AppIcon.png")
