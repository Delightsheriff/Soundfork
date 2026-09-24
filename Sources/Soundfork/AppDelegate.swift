import AppKit
import SoundforkCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var manager: RouteManager?
    private var settings: AppSettings?
    private var island: IslandController?
    private var statusItem: StatusItemController?
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let manager = RouteManager()
        let settings = AppSettings()
        let island = IslandController(model: IslandModel(manager: manager, settings: settings))
        let statusItem = StatusItemController(island: island, manager: manager, settings: settings)
        let hotKey = GlobalHotKey.soundfork { [weak island] in island?.toggle(on: nil) }
        manager.onChange = { [weak statusItem] in statusItem?.updateIcon() }
        settings.onChange = { [weak self] in self?.applySettings() }

        self.manager = manager
        self.settings = settings
        self.island = island
        self.statusItem = statusItem
        self.hotKey = hotKey
        applySettings()

        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { manager.handleWake() }
        }

        // First launch only: introduce Soundfork from the notch. Launches at login stay silent.
        if !settings.hasCompletedWelcome {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { island.open(on: NSScreen.main, page: .welcome) }
        }

        let options = LaunchOptions()
        if let path = options.snapshotPath {
            IslandSnapshot.write(model: island.model, to: path, page: options.snapshotPage, expandedPicker: options.expandedPicker)
            NSApp.terminate(nil)
        }
        if options.openIsland {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { island.open(on: NSScreen.main) }
        }
    }

    /// Launching Soundfork again (Finder, Spotlight, Launchpad) while it runs opens the island,
    /// which is the way back in when the menu-bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        island?.open(on: nil)
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager?.stopAll()
    }

    private func applySettings() {
        guard let settings else { return }
        statusItem?.applySettings()
        island?.setHoverToOpen(settings.openOnHover)
        if settings.shortcutEnabled {
            settings.shortcutUnavailable = !(hotKey?.register() ?? false)
        } else {
            hotKey?.unregister()
            settings.shortcutUnavailable = false
        }
    }
}
