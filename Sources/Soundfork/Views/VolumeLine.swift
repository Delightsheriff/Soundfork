import SwiftUI

/// Icon button + slider + percentage, shared by the system output and every app row.
struct VolumeLine: View {
    let value: Float
    var muted = false
    var tint: Color = .white
    var onToggleMute: (() -> Void)?
    let onChange: (Float) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button { onToggleMute?() } label: {
                Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.3.fill", variableValue: Double(value))
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 18, height: 18)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.6))
            .disabled(onToggleMute == nil)

            PillSlider(value: muted ? 0 : value, tint: muted ? .white.opacity(0.3) : tint, onChange: onChange)

            Text(muted ? "Muted" : value.formatted(.percent.precision(.fractionLength(0))))
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 40, alignment: .trailing)
        }
    }
}
