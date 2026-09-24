import SoundforkCore
import SwiftUI

/// The island: collapsed it's exactly the notch; open it grows into a black card under the notch.
struct IslandView: View {
    @Bindable var model: IslandModel
    let notch: CGSize
    let onIslandFrame: (CGRect) -> Void

    private static let openWidth: CGFloat = 420
    private static let maxVisibleRows = 6
    static let pickerSpring = Animation.spring(response: 0.34, dampingFraction: 0.86)

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notch.height)
            if model.isOpen {
                content
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .top)))
            }
        }
        .frame(width: model.isOpen ? Self.openWidth : notch.width)
        .background(shape.fill(.black))
        .clipShape(shape)
        .shadow(color: .black.opacity(model.isOpen ? 0.45 : 0), radius: 24, y: 10)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onIslandFrame($0) }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }

    private var shape: UnevenRoundedRectangle {
        let radius: CGFloat = model.isOpen ? 30 : 10
        return UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius, style: .continuous)
    }

    static let pageSpring = Animation.spring(response: 0.4, dampingFraction: 0.86)

    private var content: some View {
        ZStack(alignment: .top) {
            switch model.page {
            case .apps:
                appsPage.transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)).combined(with: .opacity))
            case .settings:
                SettingsView(settings: model.settings) { withAnimation(Self.pageSpring) { model.page = .apps } }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .welcome:
                WelcomeView(model: model) { withAnimation(Self.pageSpring) { model.finishWelcome() } }
                    .transition(.opacity)
            }
        }
        .clipped()
    }

    private var appsPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            systemOutput
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
            apps
            footer
        }
    }

    // MARK: Sections

    private var systemOutput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("OUTPUT")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                DeviceChip(
                    title: model.defaultDevice?.name ?? "No output",
                    symbol: model.defaultDevice?.symbolName ?? DeviceSymbol.missing,
                    highlighted: true,
                    isExpanded: model.expandedPicker == IslandModel.outputPickerID,
                    onTap: { withAnimation(Self.pickerSpring) { model.togglePicker(IslandModel.outputPickerID) } }
                )
            }
            if model.expandedPicker == IslandModel.outputPickerID {
                DevicePicker(
                    devices: model.devices,
                    selectedUID: model.defaultDevice?.uid,
                    onSelect: { device in
                        withAnimation(Self.pickerSpring) { if let device { model.setDefaultDevice(device) } }
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if let volume = model.systemVolume {
                VolumeLine(value: volume, muted: model.systemMuted, onToggleMute: model.toggleSystemMute, onChange: model.setSystemVolume)
            } else {
                Text("This device's volume is controlled on the device itself.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private var apps: some View {
        let rows = model.rows + (model.showOtherApps ? model.otherRows : [])
        return Group {
            if rows.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.35))
                    Text("Nothing's playing")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Start audio in any app and it shows up here.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else if rows.count > Self.maxVisibleRows {
                ScrollView { rowList(rows) }
                    .scrollIndicators(.never)
                    .frame(height: CGFloat(Self.maxVisibleRows) * 64)
            } else {
                rowList(rows)
            }
        }
    }

    private func rowList(_ rows: [IslandModel.Row]) -> some View {
        VStack(spacing: 2) {
            ForEach(rows) { row in
                AppRow(
                    row: row,
                    devices: model.devices,
                    defaultDevice: model.defaultDevice,
                    isPickerExpanded: model.expandedPicker == row.id,
                    onTogglePicker: { withAnimation(Self.pickerSpring) { model.togglePicker(row.id) } },
                    onSelect: { device in withAnimation(Self.pickerSpring) { model.setDestination(device, for: row) } },
                    onVolume: { model.setVolume($0, for: row) }
                )
            }
        }
    }

    private var footer: some View {
        HStack {
            if !model.otherRows.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { model.showOtherApps.toggle() }
                } label: {
                    Label(model.showOtherApps ? "Hide other apps" : "Other apps (\(model.otherRows.count))",
                          systemImage: model.showOtherApps ? "chevron.up" : "chevron.down")
                }
            }
            Spacer()
            if model.hasCustomizations {
                Button("Reset all", systemImage: "arrow.counterclockwise") { model.resetAll() }
            }
            Button {
                withAnimation(Self.pageSpring) { model.page = .settings }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .help("Settings")
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.white.opacity(0.5))
        .labelStyle(.titleAndIcon)
    }
}
