import AppKit
import SoundforkCore
import Observation

/// Everything the island shows, refreshed from Core Audio twice a second while it's open.
@Observable
@MainActor
final class IslandModel {
    struct Row: Identifiable, Equatable {
        var id: String { app.bundleID }
        let app: AudioApp
        let name: String
        let icon: NSImage?
        /// The device the user picked, or nil for "System default".
        let chosenDevice: (uid: String, name: String)?
        /// Picked device is disconnected; audio is on the default output meanwhile.
        let isFallingBack: Bool
        let volume: Float
        let error: String?

        static func == (a: Row, b: Row) -> Bool {
            a.app == b.app && a.chosenDevice?.uid == b.chosenDevice?.uid && a.isFallingBack == b.isFallingBack
                && a.volume == b.volume && a.error == b.error
        }
    }

    private(set) var rows: [Row] = []
    private(set) var otherRows: [Row] = []
    private(set) var devices: [OutputDevice] = []
    private(set) var defaultDevice: OutputDevice?
    private(set) var systemVolume: Float?
    private(set) var systemMuted = false
    var isOpen = false
    var showOtherApps = false
    /// Which device picker is unfolded: an app's bundle ID, `outputPickerID`, or nil.
    var expandedPicker: String?
    static let outputPickerID = "__output__"

    private let manager: RouteManager
    private var appInfo: [String: AppInfo] = [:]
    private var timer: Timer?

    /// Apple apps worth routing; every other com.apple.* process is a system service.
    private static let appleAppsAllowed: Set<String> = [
        "com.apple.Safari", "com.apple.Music", "com.apple.TV", "com.apple.podcasts", "com.apple.QuickTimePlayerX",
    ]

    init(manager: RouteManager) {
        self.manager = manager
    }

    var hasCustomizations: Bool { !manager.preferences.isEmpty }

    func startLiveUpdates() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            MainActor.assumeIsolated { [weak self] in self?.refresh() }
        }
    }

    func stopLiveUpdates() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let apps = ((try? AudioApps.current()) ?? []).filter(isRoutable)
        manager.absorbNewHelpers(from: apps)
        devices = (try? OutputDevices.all()) ?? []
        defaultDevice = try? OutputDevices.defaultOutput()
        systemVolume = defaultDevice.flatMap { DeviceVolume.get($0.objectID) }
        systemMuted = defaultDevice.map { DeviceVolume.isMuted($0.objectID) } ?? false

        // Customized apps that aren't running still get a row, so they can be reset.
        let running = Set(apps.map(\.bundleID))
        let absent = manager.preferences
            .filter { !running.contains($0.key) }
            .map { AudioApp(bundleID: $0.key, tapBundleIDs: $0.value.tapBundleIDs, isPlaying: false) }

        let all = (apps + absent).map(row).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        rows = all.filter { $0.app.isPlaying || manager.preferences[$0.id] != nil }
        otherRows = all.filter { !$0.app.isPlaying && manager.preferences[$0.id] == nil }
    }

    // MARK: Actions

    func togglePicker(_ id: String) {
        expandedPicker = expandedPicker == id ? nil : id
    }

    func setDestination(_ device: OutputDevice?, for row: Row) {
        expandedPicker = nil
        manager.setDestination(device, for: row.app)
        refresh()
    }

    func setVolume(_ volume: Float, for row: Row) {
        manager.setVolume(volume, for: row.app)
        refresh()
    }

    func setSystemVolume(_ volume: Float) {
        guard let defaultDevice else { return }
        try? DeviceVolume.set(volume, on: defaultDevice.objectID)
        if systemMuted, volume > 0 { try? DeviceVolume.setMuted(false, on: defaultDevice.objectID) }
        refresh()
    }

    func toggleSystemMute() {
        guard let defaultDevice else { return }
        try? DeviceVolume.setMuted(!systemMuted, on: defaultDevice.objectID)
        refresh()
    }

    func setDefaultDevice(_ device: OutputDevice) {
        expandedPicker = nil
        try? OutputDevices.setDefault(device)
        refresh()
    }

    func resetAll() {
        manager.removeAll()
        refresh()
    }

    // MARK: Helpers

    private func row(for app: AudioApp) -> Row {
        let info = info(for: app.bundleID)
        let preference = manager.preferences[app.bundleID]
        let chosen = preference?.deviceUID.map { uid in
            (uid: uid, name: devices.first { $0.uid == uid }?.name ?? preference?.deviceName ?? "Unknown device")
        }
        return Row(
            app: app,
            name: info.name,
            icon: info.icon,
            chosenDevice: chosen,
            isFallingBack: chosen.map { chosen in !devices.contains { $0.uid == chosen.uid } } ?? false,
            volume: preference?.volume ?? 1,
            error: manager.errors[app.bundleID]
        )
    }

    private func isRoutable(_ app: AudioApp) -> Bool {
        if app.bundleID.hasPrefix("com.apple.") { return Self.appleAppsAllowed.contains(app.bundleID) }
        return info(for: app.bundleID).isInstalledApp
    }

    private func info(for bundleID: String) -> AppInfo {
        if let cached = appInfo[bundleID] { return cached }
        let info = AppInfo(bundleID: bundleID)
        appInfo[bundleID] = info
        return info
    }
}
