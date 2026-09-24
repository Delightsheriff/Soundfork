import SoundforkCore
import SwiftUI

struct AppRow: View {
    let row: IslandModel.Row
    let devices: [OutputDevice]
    let defaultDevice: OutputDevice?
    let isPickerExpanded: Bool
    let onTogglePicker: () -> Void
    let onSelect: (OutputDevice?) -> Void
    let onVolume: (Float, _ final: Bool) -> Void
    let onToggleMute: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(row.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if row.app.isPlaying {
                        Image(systemName: "waveform")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.green)
                            .symbolEffect(.variableColor.iterative, options: .repeating)
                    }
                    Spacer(minLength: 8)
                    DeviceChip(
                        title: row.chosenName ?? "Default",
                        symbol: row.chipSymbol,
                        highlighted: row.chosenUID != nil,
                        warning: row.isFallingBack,
                        isExpanded: isPickerExpanded,
                        onTap: onTogglePicker
                    )
                }
                if isPickerExpanded {
                    DevicePicker(
                        devices: devices,
                        selectedUID: row.chosenUID,
                        defaultOption: ("System default", defaultDevice?.name),
                        onSelect: onSelect
                    )
                    .padding(.top, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                VolumeLine(value: row.volume, muted: row.muted,
                           tint: row.volume < RoutePreference.fullVolume ? .white : .white.opacity(0.85),
                           onToggleMute: onToggleMute,
                           onChange: { onVolume($0, false) }, onCommit: { onVolume($0, true) })
                if let note {
                    Text(note)
                        .font(.system(size: 10.5))
                        .foregroundStyle(row.error != nil ? Color.red : .orange)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 7)
    }

    private var icon: some View {
        Group {
            if let image = row.icon {
                Image(nsImage: image).resizable()
            } else {
                RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.12))
                    .overlay(Image(systemName: "app.fill").foregroundStyle(.white.opacity(0.5)))
            }
        }
        .frame(width: 30, height: 30)
        .padding(.top, 2)
    }

    private var note: String? {
        if let error = row.error { return error }
        if row.isFallingBack, let chosen = row.chosenName {
            return "\(chosen) isn't available. Playing on \(defaultDevice?.name ?? "the default output") until it's back."
        }
        return nil
    }
}
