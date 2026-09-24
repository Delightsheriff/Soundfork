import AppKit

/// Where the island lives on a screen: the notch if there is one, otherwise a pill under the menu bar's center.
struct NotchGeometry {
    let screen: NSScreen
    /// Size of the collapsed island (matches the physical notch on notched displays).
    let size: CGSize

    init(screen: NSScreen) {
        self.screen = screen
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea, screen.safeAreaInsets.top > 0 {
            size = CGSize(width: screen.frame.width - left.width - right.width, height: screen.safeAreaInsets.top)
        } else {
            size = CGSize(width: 190, height: max(NSStatusBar.system.thickness, 24))
        }
    }

    /// The notch rectangle in screen coordinates (for hover detection).
    var notchRect: CGRect {
        CGRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height, width: size.width, height: size.height)
    }

    /// Panel frame: top-center of the screen, big enough for the expanded island plus its shadow.
    func panelFrame(width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height, width: width, height: height)
    }
}
