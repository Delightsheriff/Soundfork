import AppKit
import SwiftUI

/// Renders the open island to a PNG, for checking layout without screen recording.
@MainActor
enum IslandSnapshot {
    static func write(model: IslandModel, to path: String) {
        model.refresh()
        model.isOpen = true
        if let index = CommandLine.arguments.firstIndex(of: "--page"), index + 1 < CommandLine.arguments.count {
            switch CommandLine.arguments[index + 1] {
            case "settings": model.page = .settings
            case "welcome": model.page = .welcome
            default: break
            }
        }
        if let index = CommandLine.arguments.firstIndex(of: "--expand"), index + 1 < CommandLine.arguments.count {
            model.expandedPicker = CommandLine.arguments[index + 1]
        }
        let notch = NSScreen.main.map { NotchGeometry(screen: $0).size } ?? CGSize(width: 185, height: 32)
        let view = IslandView(model: model, notch: notch, onIslandFrame: { _ in })
            .frame(width: 480, height: 760)
            .background(Color(white: 0.55))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}
