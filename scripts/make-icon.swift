// Renders the Soundfork app icon into Resources/AppIcon.icns.
//   swift scripts/make-icon.swift
//
// A tuning fork (a "sound fork") hanging from a notch-shaped pill; its two tines ring out in
// different colors — one sound, split to two speakers.

import AppKit
import SwiftUI

let mint = Color(red: 0.24, green: 0.90, blue: 0.62)
let violet = Color(red: 0.62, green: 0.50, blue: 1.00)

struct SoundforkIcon: View {
    var body: some View {
        Canvas { context, _ in
            // Body: macOS icon grid, 824pt squircle inset 100pt in a 1024 canvas.
            let body = Path(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerRadius: 186, style: .continuous)
            context.fill(body, with: .linearGradient(
                Gradient(colors: [Color(red: 0.15, green: 0.15, blue: 0.21), Color(red: 0.04, green: 0.04, blue: 0.07)]),
                startPoint: CGPoint(x: 512, y: 100), endPoint: CGPoint(x: 512, y: 924)))

            // Colored glows behind each tine.
            context.drawLayer { glow in
                glow.clip(to: body)
                glow.addFilter(.blur(radius: 90))
                glow.fill(Path(ellipseIn: CGRect(x: 250, y: 560, width: 260, height: 300)), with: .color(mint.opacity(0.35)))
                glow.fill(Path(ellipseIn: CGRect(x: 514, y: 560, width: 260, height: 300)), with: .color(violet.opacity(0.38)))
            }

            // Soft top highlight on the body.
            context.drawLayer { shine in
                shine.clip(to: body)
                shine.addFilter(.blur(radius: 40))
                shine.fill(Path(ellipseIn: CGRect(x: 60, y: -260, width: 904, height: 560)),
                           with: .color(.white.opacity(0.05)))
            }
            context.stroke(body, with: .color(.white.opacity(0.08)), lineWidth: 3)

            // The island pill at the top.
            let pill = Path(roundedRect: CGRect(x: 367, y: 176, width: 290, height: 86), cornerRadius: 43, style: .continuous)
            context.fill(pill, with: .color(.black))
            context.stroke(pill, with: .color(.white.opacity(0.14)), lineWidth: 3)
            // A tiny "camera" dot, like the notch.
            context.fill(Path(ellipseIn: CGRect(x: 586, y: 207, width: 24, height: 24)), with: .color(.white.opacity(0.12)))

            let stroke = StrokeStyle(lineWidth: 46, lineCap: .round, lineJoin: .round)

            // Tines: each starts silver at the bridge and rings out in its color.
            for (side, color) in [(-1.0, mint), (1.0, violet)] {
                let x = 512 + side * 118
                var tine = Path()
                tine.move(to: CGPoint(x: 512, y: 488))
                tine.addCurve(to: CGPoint(x: x, y: 620),
                              control1: CGPoint(x: 512, y: 560),
                              control2: CGPoint(x: x, y: 540))
                tine.addLine(to: CGPoint(x: x, y: 800))
                context.stroke(tine, with: .linearGradient(Gradient(colors: [Color(white: 0.92), color]),
                                                           startPoint: CGPoint(x: 512, y: 500), endPoint: CGPoint(x: x, y: 780)),
                               style: stroke)

                // Sound arcs radiating outward from the tine.
                for (index, radius) in [78.0, 132.0].enumerated() {
                    var arc = Path()
                    let center = CGPoint(x: x, y: 712)
                    let mid: Double = side < 0 ? 180 : 0
                    arc.addArc(center: center, radius: radius,
                               startAngle: .degrees(mid - 34), endAngle: .degrees(mid + 34), clockwise: false)
                    context.stroke(arc, with: .color(color.opacity(index == 0 ? 0.95 : 0.55)),
                                   style: StrokeStyle(lineWidth: 26, lineCap: .round))
                }
            }
            // Handle, from the pill down to the fork; drawn last so its round end covers the join.
            var handle = Path()
            handle.move(to: CGPoint(x: 512, y: 262))
            handle.addLine(to: CGPoint(x: 512, y: 500))
            context.stroke(handle, with: .linearGradient(Gradient(colors: [Color(white: 0.99), Color(white: 0.92)]),
                                                         startPoint: CGPoint(x: 512, y: 262), endPoint: CGPoint(x: 512, y: 500)),
                           style: stroke)
        }
        .frame(width: 1024, height: 1024)
    }
}

@MainActor
func render(pixels: Int) -> Data {
    let renderer = ImageRenderer(content: SoundforkIcon())
    renderer.scale = CGFloat(pixels) / 1024
    let image = renderer.cgImage!
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    try MainActor.assumeIsolated { render(pixels: points) }.write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try MainActor.assumeIsolated { render(pixels: points * 2) }.write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
try MainActor.assumeIsolated { render(pixels: 1024) }.write(to: root.appendingPathComponent("build/AppIcon-1024.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "wrote Resources/AppIcon.icns" : "iconutil failed")
