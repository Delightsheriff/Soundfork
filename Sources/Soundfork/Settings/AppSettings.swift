import Foundation
import Observation
import ServiceManagement

/// User preferences, persisted in UserDefaults. `onChange` lets controllers re-apply them.
@Observable
@MainActor
final class AppSettings {
    enum HoverSpeed: String, CaseIterable, Identifiable {
        case instant, normal, relaxed
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
        /// How long the pointer must rest on the notch before the island opens.
        var dwell: TimeInterval {
            switch self {
            case .instant: 0.05
            case .normal: 0.15
            case .relaxed: 0.4
            }
        }
    }

    static let shortcutDisplay = "⌃⌥⌘S"

    private enum Key {
        static let openOnHover = "openOnNotchHover"
        static let hoverSpeed = "hoverSpeed"
        static let shortcutEnabled = "shortcutEnabled"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let hasCompletedWelcome = "hasCompletedWelcome"
    }

    var openOnHover: Bool { didSet { save(openOnHover, Key.openOnHover); keepReachable() } }
    var hoverSpeed: HoverSpeed { didSet { save(hoverSpeed.rawValue, Key.hoverSpeed) } }
    var shortcutEnabled: Bool { didSet { save(shortcutEnabled, Key.shortcutEnabled); keepReachable() } }
    var showMenuBarIcon: Bool { didSet { save(showMenuBarIcon, Key.showMenuBarIcon); keepReachable() } }
    var hasCompletedWelcome: Bool { didSet { save(hasCompletedWelcome, Key.hasCompletedWelcome) } }
    /// Set by the hot-key registration when another app already owns the combination.
    var shortcutUnavailable = false

    private(set) var loginItemStatus: SMAppService.Status = SMAppService.mainApp.status
    var onChange: (() -> Void)?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.openOnHover: true,
            Key.hoverSpeed: HoverSpeed.normal.rawValue,
            Key.shortcutEnabled: true,
            Key.showMenuBarIcon: true,
            Key.hasCompletedWelcome: false,
        ])
        openOnHover = defaults.bool(forKey: Key.openOnHover)
        hoverSpeed = HoverSpeed(rawValue: defaults.string(forKey: Key.hoverSpeed) ?? "") ?? .normal
        shortcutEnabled = defaults.bool(forKey: Key.shortcutEnabled)
        showMenuBarIcon = defaults.bool(forKey: Key.showMenuBarIcon)
        hasCompletedWelcome = defaults.bool(forKey: Key.hasCompletedWelcome)
    }

    // MARK: Open at login

    var openAtLogin: Bool { loginItemStatus == .enabled || loginItemStatus == .requiresApproval }
    var loginItemNeedsApproval: Bool { loginItemStatus == .requiresApproval }

    func setOpenAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            // The refreshed status reflects what actually happened.
        }
        refreshLoginItemStatus()
    }

    func refreshLoginItemStatus() {
        loginItemStatus = SMAppService.mainApp.status
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // MARK: Helpers

    /// With no menu-bar icon, no hover and no shortcut there'd be no way to open Soundfork; bring the icon back.
    private func keepReachable() {
        if !showMenuBarIcon && !openOnHover && !shortcutEnabled { showMenuBarIcon = true }
        onChange?()
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
    }
}
