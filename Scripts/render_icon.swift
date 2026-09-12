#!/usr/bin/env swift
import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Original vector artwork. Run from the repository root on macOS.
// Opaque, square output; iOS applies the rounded icon mask.
let destination = CommandLine.arguments.dropFirst().first
    ?? "TradeLedger/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}
func rounded(_ rect: NSRect, radius: CGFloat, fill: NSColor) {
    fill.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}
func line(_ points: [NSPoint], width: CGFloat, stroke: NSColor) {
    let path = NSBezierPath()
    path.move(to: points[0])
    for point in points.dropFirst() { path.line(to: point) }
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    stroke.setStroke()
    path.stroke()
}

let navy = color(0.067, 0.145, 0.173)
let deepTeal = color(0.047, 0.278, 0.278)
let mint = color(0.596, 0.894, 0.769)
let paper = color(0.970, 0.963, 0.925)
let wash = color(0.185, 0.360, 0.373)
NSGradient(starting: navy, ending: deepTeal)!.draw(
    in: NSRect(x: 0, y: 0, width: size, height: size), angle: 45)

// A subtle inset binding and the open upper edge form a compact ledger.
rounded(NSRect(x: 214, y: 185, width: 57, height: 654), radius: 28, fill: wash)
let outline = NSBezierPath(roundedRect: NSRect(x: 286, y: 198, width: 505, height: 624),
                           xRadius: 65, yRadius: 65)
outline.lineWidth = 27
paper.setStroke()
outline.stroke()
line([NSPoint(x: 375, y: 714), NSPoint(x: 529, y: 714)], width: 22, stroke: paper)
line([NSPoint(x: 375, y: 654), NSPoint(x: 465, y: 654)], width: 15, stroke: wash)

// Baseline and guide marks leave ample negative space for the performance line.
line([NSPoint(x: 379, y: 331), NSPoint(x: 695, y: 331)], width: 14, stroke: wash)
for x: CGFloat in [394, 497, 600, 703] {
    rounded(NSRect(x: x - 5, y: 282, width: 10, height: 12), radius: 5, fill: wash)
}
let chart = [NSPoint(x: 375, y: 420), NSPoint(x: 472, y: 506),
             NSPoint(x: 561, y: 453), NSPoint(x: 698, y: 598)]
line(chart, width: 39, stroke: mint)
paper.setFill()
NSBezierPath(ovalIn: NSRect(x: 674, y: 574, width: 48, height: 48)).fill()

NSGraphicsContext.restoreGraphicsState()
let output = URL(fileURLWithPath: destination)
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
let writer = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(writer, context.makeImage()!, nil)
guard CGImageDestinationFinalize(writer) else { fatalError("PNG encoding failed") }
print("Wrote \(output.path)")
