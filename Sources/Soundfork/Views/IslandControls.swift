import SwiftUI

/// Capsule switch in the island's style.
struct IslandToggle: View {
    let isOn: Bool
    var isEnabled = true
    let onChange: (Bool) -> Void

    var body: some View {
        Button { onChange(!isOn) } label: {
            Capsule()
                .fill(isOn ? Color.green.opacity(0.9) : .white.opacity(0.16))
                .frame(width: 34, height: 20)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle().fill(.white).padding(2.5).shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isOn)
    }
}

/// Row of pill options, one selected.
struct IslandSegmented<Option: Hashable & Identifiable>: View {
    let options: [Option]
    let selection: Option
    let title: (Option) -> String
    var isEnabled = true
    let onSelect: (Option) -> Void

    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                Button { onSelect(option) } label: {
                    Text(title(option))
                        .font(.system(size: 11, weight: option == selection ? .semibold : .regular))
                        .foregroundStyle(.white.opacity(option == selection ? 1 : 0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background {
                            if option == selection {
                                Capsule().fill(.white.opacity(0.18)).matchedGeometryEffect(id: "pill", in: highlight)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(.white.opacity(0.07)))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selection)
    }
}

/// Keyboard-key style badge, e.g. for "⌃⌥⌘S".
struct KeyBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.white.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.white.opacity(0.12)))
    }
}

/// Primary action button in the island (white capsule, black text).
struct IslandButton: View {
    let title: String
    var systemImage: String?
    var prominent = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 11, weight: .semibold)) }
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(prominent ? .black : .white.opacity(0.85))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(prominent ? .white : .white.opacity(0.1)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
