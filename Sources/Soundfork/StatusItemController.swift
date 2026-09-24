import AppKit
import SoundforkCore

/// Menu-bar icon. Left click toggles the island; right click shows a small options menu.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let island: IslandController
    private let manager: RouteManager
    private let settings: AppSettings

    init(island: IslandController, manager: RouteManager, settings: AppSettings) {
        self.island = island
        self.manager = manager
        self.settings = settings
        super.init()
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        applySettings()
        updateIcon()
    }

    func applySettings() {
        statusItem.isVisible = settings.showMenuBarIcon
    }

    func updateIcon() {
        let image = manager.hasActiveRoutes ? StatusGlyph.active : StatusGlyph.idle
        if statusItem.button?.image !== image { statusItem.button?.image = image }
    }

    var screen: NSScreen? { statusItem.button?.window?.screen }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            island.close()
            showOptionsMenu()
        } else {
            island.toggle(on: screen)
        }
    }

    private func showOptionsMenu() {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
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

    @objc private func openSettings() {
        island.open(on: screen, page: .settings)
    }

    @objc private func resetAll() {
        manager.removeAll()
    }
}
