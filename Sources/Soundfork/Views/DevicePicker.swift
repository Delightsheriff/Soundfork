import SoundforkCore
import SwiftUI

/// Inline device list that unfolds under a row, styled like the rest of the island.
struct DevicePicker: View {
    let devices: [OutputDevice]
    let selectedUID: String?
    /// Title for the "no route" option, e.g. "System default"; nil hides it (the Output section has no default-of-default).
    var defaultOption: (title: String, detail: String?)?
    let onSelect: (OutputDevice?) -> Void

    var body: some View {
        VStack(spacing: 3) {
            if let defaultOption {
                Option(symbol: "arrow.triangle.branch", title: defaultOption.title, detail: defaultOption.detail,
                       isSelected: selectedUID == nil) { onSelect(nil) }
            }
            ForEach(devices) { device in
                Option(symbol: device.symbolName, title: device.name, detail: nil,
                       isSelected: selectedUID == device.uid) { onSelect(device) }
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.06)))
    }

    private struct Option: View {
        let symbol: String
        let title: String
        let detail: String?
        let isSelected: Bool
        let action: () -> Void

        @State private var hovering = false

        var body: some View {
            Button(action: action) {
                HStack(spacing: 9) {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.white.opacity(isSelected ? 0.2 : 0.08)))
                    Text(title)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .lineLimit(1)
                    if let detail {
                        Text(detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .foregroundStyle(.white.opacity(isSelected ? 1 : 0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.12 : hovering ? 0.07 : 0)))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
        }
    }
}
