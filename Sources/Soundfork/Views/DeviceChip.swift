import SwiftUI

/// Compact capsule showing where audio plays. Tapping it unfolds a `DevicePicker` inside the island.
struct DeviceChip: View {
    let title: String
    let symbol: String
    var highlighted = false
    var warning = false
    let isExpanded: Bool
    let onTap: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Image(systemName: warning ? "exclamationmark.triangle.fill" : symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(0.6)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(warning ? Color.orange : .white.opacity(highlighted || isExpanded ? 1 : 0.75))
            .background(Capsule().fill(.white.opacity(fillOpacity)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }

    private var fillOpacity: Double {
        if isExpanded { return 0.24 }
        return (highlighted ? 0.16 : 0.09) + (hovering ? 0.06 : 0)
    }
}
