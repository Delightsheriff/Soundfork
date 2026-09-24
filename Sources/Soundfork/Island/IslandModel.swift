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
        /// The device the user picked (nil = System default). The name survives while it's disconnected.
        let chosenUID: String?
        let chosenName: String?
        let chipSymbol: String
        /// A device was picked but the app is playing somewhere else right now (disconnected or still settling).
        let isFallingBack: Bool
        var volume: Float
        let error: String?
    }

    enum Page { case apps, settings, welcome }

    private(set) var rows: [Row] = []
    private(set) var otherRows: [Row] = []
    private(set) var devices: [OutputDevice] = []
    private(set) var defaultDevice: OutputDevice?
    private(set) var systemVolume: Float?
    private(set) var systemMuted = false

    var isOpen = false
    var page: Page = .apps
    var showOtherApps = false
    /// Which device picker is unfolded: an app's bundle ID, `outputPickerID`, or nil.
    var expandedPicker: String?
    static let outputPickerID = "__output__"

    let settings: AppSettings
    private let manager: RouteManager
    private var appInfo: [String: AppInfo] = [:]
    private var timer: Timer?

    /// Apple apps worth routing; every other com.apple.* process is a system service.
    private static let appleAppsAllowed: Set<String> = [
        "com.apple.Safari", "com.apple.Music", "com.apple.TV", "com.apple.podcasts", "com.apple.QuickTimePlayerX",
    ]

    init(manager: RouteManager, settings: AppSettings) {
        self.manager = manager
        self.settings = settings
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
        let devices = (try? OutputDevices.all()) ?? []
        let defaultDevice = try? OutputDevices.defaultOutput(in: devices)
        // Only publish values that changed, so SwiftUI doesn't re-render the island every tick.
        if devices != self.devices { self.devices = devices }
        if defaultDevice != self.defaultDevice { self.defaultDevice = defaultDevice }
        let volume = defaultDevice.flatMap { DeviceVolume.get($0.objectID) }
        if volume != systemVolume { systemVolume = volume }
        let muted = defaultDevice.map { DeviceVolume.isMuted($0.objectID) } ?? false
        if muted != systemMuted { systemMuted = muted }

        // Customized apps that aren't running still get a row, so they can be reset.
        let running = Set(apps.map(\.bundleID))
        let absent = manager.preferences
            .filter { !running.contains($0.key) }
            .map { AudioApp(bundleID: $0.key, tapBundleIDs: $0.value.tapBundleIDs, isPlaying: false) }

        let all = (apps + absent).map(row).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        var shown: [Row] = []
        var others: [Row] = []
        for row in all {
            if row.app.isPlaying || manager.preferences[row.id] != nil { shown.append(row) } else { others.append(row) }
        }
        if shown != rows { rows = shown }
        if others != otherRows { otherRows = others }
    }

    // MARK: Actions

    func finishWelcome() {
        settings.hasCompletedWelcome = true
        page = .apps
    }

    func togglePicker(_ id: String) {
        expandedPicker = expandedPicker == id ? nil : id
    }

    func setDestination(_ device: OutputDevice?, for row: Row) {
        expandedPicker = nil
        manager.setDestination(device, for: row.app)
        refresh()
    }

    /// Called for every slider tick: patch the one row instead of re-reading Core Audio.
    func setVolume(_ volume: Float, for row: Row) {
        manager.setVolume(volume, for: row.app)
        if let index = rows.firstIndex(where: { $0.id == row.id }) {
            rows[index].volume = volume
        } else if let index = otherRows.firstIndex(where: { $0.id == row.id }) {
            otherRows[index].volume = volume
        }
    }

    func setSystemVolume(_ volume: Float) {
        guard let defaultDevice else { return }
        try? DeviceVolume.set(volume, on: defaultDevice.objectID)
        if systemMuted, volume > 0 {
            try? DeviceVolume.setMuted(false, on: defaultDevice.objectID)
            systemMuted = false
        }
        systemVolume = volume
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
        let chosenUID = preference?.deviceUID
        let chosenDevice = chosenUID.flatMap { uid in devices.first { $0.uid == uid } }
        return Row(
            app: app,
            name: info.name,
            icon: info.icon,
            chosenUID: chosenUID,
            chosenName: chosenDevice?.name ?? preference?.deviceName ?? chosenUID.map { _ in "Unknown device" },
            chipSymbol: chosenUID == nil ? DeviceSymbol.systemDefault : chosenDevice?.symbolName ?? DeviceSymbol.missing,
            isFallingBack: chosenUID != nil && manager.currentDestination(for: app.bundleID) != chosenUID,
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
