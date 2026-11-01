// Generates the Podflow app icon: an alpine ridgeline drawn as waveform bars
// (running/trail podcast) with a trail-orange sun, on a deep alpine gradient.
// Usage: swift make-icon.swift <output.png> <size>
import AppKit

let arguments = CommandLine.arguments
guard arguments.count >= 3, let size = Int(arguments[2]) else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <output.png> <size>\n".utf8))
    exit(1)
}
let outputPath = arguments[1]
let dimension = CGFloat(size)

let image = NSImage(size: NSSize(width: dimension, height: dimension))
image.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else { exit(1) }

let scale = dimension / 1024.0

// macOS icon grid: rounded rect inset ~10%.
let inset = 100.0 * scale
let rect = CGRect(x: inset, y: inset, width: dimension - 2 * inset, height: dimension - 2 * inset)
let radius = 185.0 * scale
let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

// Background: night-alpine gradient.
context.saveGState()
context.addPath(path)
context.clip()
let bgColors = [
    CGColor(red: 0.07, green: 0.22, blue: 0.19, alpha: 1),
    CGColor(red: 0.03, green: 0.10, blue: 0.12, alpha: 1),
] as CFArray
let bgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors, locations: [0, 1])!
context.drawLinearGradient(
    bgGradient,
    start: CGPoint(x: rect.minX, y: rect.maxY),
    end: CGPoint(x: rect.maxX, y: rect.minY),
    options: [])

// Sun: trail orange, upper right.
let sunCenter = CGPoint(x: rect.minX + rect.width * 0.72, y: rect.minY + rect.height * 0.74)
let sunRadius = 95.0 * scale
let sunColors = [
    CGColor(red: 1.0, green: 0.62, blue: 0.25, alpha: 1),
    CGColor(red: 0.95, green: 0.45, blue: 0.13, alpha: 1),
] as CFArray
let sunGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: sunColors, locations: [0, 1])!
context.saveGState()
context.addEllipse(in: CGRect(x: sunCenter.x - sunRadius, y: sunCenter.y - sunRadius,
                              width: sunRadius * 2, height: sunRadius * 2))
context.clip()
context.drawRadialGradient(
    sunGradient, startCenter: sunCenter, startRadius: 0,
    endCenter: sunCenter, endRadius: sunRadius, options: [])
context.restoreGState()

// Waveform bars forming a mountain ridgeline (two peaks).
// Heights as fractions of the panel height.
let fractions: [CGFloat] = [0.16, 0.24, 0.34, 0.46, 0.62, 0.50, 0.40, 0.52, 0.70, 0.56, 0.42, 0.30, 0.22, 0.15]
let barAreaWidth = rect.width * 0.76
let barAreaX = rect.minX + (rect.width - barAreaWidth) / 2
let gap = 14.0 * scale
let barWidth = (barAreaWidth - gap * CGFloat(fractions.count - 1)) / CGFloat(fractions.count)
let baseY = rect.minY + rect.height * 0.18
let maxBarHeight = rect.height * 0.60

for (index, fraction) in fractions.enumerated() {
    let x = barAreaX + CGFloat(index) * (barWidth + gap)
    let height = maxBarHeight * fraction
    let barRect = CGRect(x: x, y: baseY, width: barWidth, height: height)
    let barPath = CGPath(roundedRect: barRect, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil)
    context.saveGState()
    context.addPath(barPath)
    context.clip()
    let barColors = [
        CGColor(red: 1.0, green: 0.72, blue: 0.38, alpha: 1),
        CGColor(red: 0.95, green: 0.45, blue: 0.13, alpha: 1),
    ] as CFArray
    let barGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: barColors, locations: [0, 1])!
    context.drawLinearGradient(
        barGradient,
        start: CGPoint(x: x, y: barRect.maxY),
        end: CGPoint(x: x, y: barRect.minY),
        options: [])
    context.restoreGState()
}

// Soft specular highlight on the top edge (liquid glass hint).
let highlightColors = [
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.28),
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
] as CFArray
let highlight = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: highlightColors, locations: [0, 1])!
context.drawLinearGradient(
    highlight,
    start: CGPoint(x: rect.midX, y: rect.maxY),
    end: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.22),
    options: [])

context.restoreGState()
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: outputPath))
