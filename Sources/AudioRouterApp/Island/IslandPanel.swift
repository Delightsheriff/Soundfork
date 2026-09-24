import AppKit

/// Borderless, transparent, non-activating panel that sits over the menu bar at the top-center of the screen.
/// The island shape itself is drawn by SwiftUI inside it.
final class IslandPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    // Needed for Esc and for sliders to track; non-activating, so the frontmost app keeps focus.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
