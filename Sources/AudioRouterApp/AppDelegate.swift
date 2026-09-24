import AppKit
import AudioRouterCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var manager: RouteManager?
    private var island: IslandController?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let manager = RouteManager()
        let island = IslandController(model: IslandModel(manager: manager))
        let statusItem = StatusItemController(island: island, manager: manager)
        manager.onChange = { [weak statusItem] in statusItem?.updateIcon() }

        self.manager = manager
        self.island = island
        self.statusItem = statusItem

        // Development aid: `open build/AudioRouter.app --args --open` shows the island right away.
        // Development aid: `--snapshot <file.png>` renders the open island to an image and quits.
        if let index = CommandLine.arguments.firstIndex(of: "--snapshot"), index + 1 < CommandLine.arguments.count {
            IslandSnapshot.write(model: island.model, to: CommandLine.arguments[index + 1])
            NSApp.terminate(nil)
        }
        if CommandLine.arguments.contains("--open") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { island.open(on: NSScreen.main) }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager?.stopAll()
    }
}
