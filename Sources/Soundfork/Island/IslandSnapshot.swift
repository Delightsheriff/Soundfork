import AppKit
import SwiftUI

/// Renders the open island to a PNG, for checking layout without screen recording.
@MainActor
enum IslandSnapshot {
    static func write(model: IslandModel, to path: String, page: IslandModel.Page?, expandedPicker: String?) {
        model.refresh()
        model.isOpen = true
        if let page { model.page = page }
        model.expandedPicker = expandedPicker
        let notch = NSScreen.main.map { NotchGeometry(screen: $0).size } ?? CGSize(width: 185, height: 32)
        // Transparent, sized to the island itself plus room for its shadow.
        let view = IslandView(model: model, notch: notch, onIslandFrame: { _ in })
            .frame(width: 480)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 40)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}
