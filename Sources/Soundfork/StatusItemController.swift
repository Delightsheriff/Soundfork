import AppKit
import SoundforkCore

/// Menu-bar icon. Left click toggles the island; right click shows a small options menu.
@MainActor
final class StatusItemController: NSObject {
    private static let hoverKey = "openOnNotchHover"

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let island: IslandController
    private let manager: RouteManager

    init(island: IslandController, manager: RouteManager) {
        self.island = island
        self.manager = manager
        super.init()
        UserDefaults.standard.register(defaults: [Self.hoverKey: true])

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        island.setHoverToOpen(hoverEnabled)
        updateIcon()
    }

    func updateIcon() {
        let symbol = manager.activeRouteCount > 0 ? "hifispeaker.2.fill" : "hifispeaker.2"
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Soundfork")
    }

    private var hoverEnabled: Bool { UserDefaults.standard.bool(forKey: Self.hoverKey) }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            island.close()
            showOptionsMenu()
        } else {
            island.toggle(on: statusItem.button?.window?.screen)
        }
    }

    private func showOptionsMenu() {
        let menu = NSMenu()
        let hover = NSMenuItem(title: "Open When Hovering Over the Notch", action: #selector(toggleHover), keyEquivalent: "")
        hover.target = self
        hover.state = hoverEnabled ? .on : .off
        menu.addItem(hover)
        menu.addItem(.separator())
        let reset = NSMenuItem(title: "Send Every App Back to Default", action: #selector(resetAll), keyEquivalent: "")
        reset.target = self
        reset.isEnabled = !manager.preferences.isEmpty
        menu.addItem(reset)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Soundfork", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleHover() {
        UserDefaults.standard.set(!hoverEnabled, forKey: Self.hoverKey)
        island.setHoverToOpen(hoverEnabled)
    }

    @objc private func resetAll() {
        manager.removeAll()
    }
}
