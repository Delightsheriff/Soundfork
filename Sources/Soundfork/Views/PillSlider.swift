import SwiftUI

/// Thin capsule slider that thickens on hover and drag. Keeps its own value while dragging,
/// so live refreshes from Core Audio don't make the knob jump under the cursor.
struct PillSlider: View {
    let value: Float
    var tint: Color = .white
    let onChange: (Float) -> Void
    /// Called once with the final value when a drag ends.
    var onCommit: ((Float) -> Void)?

    @State private var dragValue: Float?
    @State private var hovering = false

    private var active: Bool { hovering || dragValue != nil }

    var body: some View {
        GeometryReader { geometry in
            let shown = CGFloat(dragValue ?? value)
            let height: CGFloat = active ? 8 : 5
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.14))
                Capsule().fill(tint).frame(width: max(height, geometry.size.width * shown))
            }
            .frame(height: height)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let newValue = Float(min(max(drag.location.x / geometry.size.width, 0), 1))
                        dragValue = newValue
                        onChange(newValue)
                    }
                    .onEnded { _ in
                        if let dragValue { onCommit?(dragValue) }
                        dragValue = nil
                    }
            )
        }
        .frame(height: 18)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: active)
    }
}
