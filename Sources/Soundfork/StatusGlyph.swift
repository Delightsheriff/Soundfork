import AppKit

/// The menu-bar icon: the app icon's fork in miniature, as a template image so it follows the menu bar's
/// appearance. When routes are active, sound waves ring off the tines.
@MainActor
enum StatusGlyph {
    static let idle = draw(active: false)
    static let active = draw(active: true)

    private static func draw(active: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            NSColor.black.set()

            // The notch pill.
            NSBezierPath(roundedRect: NSRect(x: 5, y: 1.5, width: 8, height: 3), xRadius: 1.5, yRadius: 1.5).fill()

            let fork = NSBezierPath()
            fork.lineWidth = 1.7
            fork.lineCapStyle = .round
            fork.lineJoinStyle = .round
            fork.move(to: NSPoint(x: 9, y: 4.5))
            fork.line(to: NSPoint(x: 9, y: 8.5))
            for x in [6.0, 12.0] {
                fork.move(to: NSPoint(x: 9, y: 8.5))
                fork.curve(to: NSPoint(x: x, y: 11.5), controlPoint1: NSPoint(x: 9, y: 10), controlPoint2: NSPoint(x: x, y: 9.8))
                fork.line(to: NSPoint(x: x, y: 16.5))
            }
            fork.stroke()

            if active {
                let waves = NSBezierPath()
                waves.lineWidth = 1.3
                waves.lineCapStyle = .round
                // Flipped context: angles run clockwise from +x.
                waves.appendArc(withCenter: NSPoint(x: 6, y: 14), radius: 3.3, startAngle: 145, endAngle: 215, clockwise: false)
                waves.move(to: NSPoint(x: 12 + 3.3 * cos(-35 * .pi / 180), y: 14 + 3.3 * sin(-35 * .pi / 180)))
                waves.appendArc(withCenter: NSPoint(x: 12, y: 14), radius: 3.3, startAngle: -35, endAngle: 35, clockwise: false)
                waves.stroke()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Soundfork"
        return image
    }
}
