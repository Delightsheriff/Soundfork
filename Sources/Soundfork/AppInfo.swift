import AppKit

/// Display name and icon for a bundle ID, via Launch Services.
struct AppInfo {
    let name: String
    let icon: NSImage?
    /// False for background daemons and system services with no .app we can find.
    let isInstalledApp: Bool

    init(bundleID: String) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            let image = NSWorkspace.shared.icon(forFile: url.path)
            image.size = NSSize(width: 64, height: 64)
            icon = image
            isInstalledApp = url.pathExtension == "app"
        } else {
            name = bundleID.split(separator: ".").last.map(String.init) ?? bundleID
            icon = nil
            isInstalledApp = false
        }
    }
}
