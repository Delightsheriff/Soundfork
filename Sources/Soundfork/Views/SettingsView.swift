import AppKit
import SwiftUI

/// The island's settings page, reached from the gear in the footer.
struct SettingsView: View {
    @Bindable var settings: AppSettings
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            VStack(spacing: 2) {
                row("Open at login", detail: settings.loginItemNeedsApproval ? "Needs approval in System Settings" : nil) {
                    IslandToggle(isOn: settings.openAtLogin) { settings.setOpenAtLogin($0) }
                }
                if settings.loginItemNeedsApproval {
                    HStack {
                        Spacer()
                        IslandButton(title: "Open Login Items", systemImage: "arrow.up.forward", prominent: false) {
                            settings.openLoginItemsSettings()
                        }
                    }
                    .padding(.bottom, 6)
                }
                divider
                row("Open when hovering the notch") {
                    IslandToggle(isOn: settings.openOnHover) { settings.openOnHover = $0 }
                }
                row("Hover speed") {
                    IslandSegmented(options: AppSettings.HoverSpeed.allCases, selection: settings.hoverSpeed,
                                    title: \.title, isEnabled: settings.openOnHover) { settings.hoverSpeed = $0 }
                }
                divider
                row("Keyboard shortcut",
                    detail: settings.shortcutUnavailable ? "Another app is using this shortcut" : nil,
                    detailIsWarning: true) {
                    HStack(spacing: 8) {
                        KeyBadge(text: AppSettings.shortcutDisplay)
                        IslandToggle(isOn: settings.shortcutEnabled) { settings.shortcutEnabled = $0 }
                    }
                }
                row("Show menu-bar icon",
                    detail: settings.showMenuBarIcon ? nil : "Open Soundfork from the notch, the shortcut, or by launching it again") {
                    IslandToggle(isOn: settings.showMenuBarIcon,
                                 isEnabled: !settings.showMenuBarIcon || settings.openOnHover || settings.shortcutEnabled) {
                        settings.showMenuBarIcon = $0
                    }
                }
            }
            footer
        }
        .onAppear { settings.refreshLoginItemStatus() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.white.opacity(0.1)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.8))
            Text("Settings")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Soundfork \(Self.version)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Text("Runs offline. Nothing leaves your Mac.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            IslandButton(title: "Quit", systemImage: "power", prominent: false) { NSApp.terminate(nil) }
        }
        .padding(.top, 2)
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.vertical, 6)
    }

    private func row<Trailing: View>(_ title: String, detail: String? = nil, detailIsWarning: Bool = false,
                                     @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                if let detail {
                    Text(detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(detailIsWarning ? Color.orange : .white.opacity(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 5)
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}
