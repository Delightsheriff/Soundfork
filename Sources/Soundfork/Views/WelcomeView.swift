import AppKit
import SoundforkCore
import SwiftUI

/// First-launch walkthrough, shown once inside the island: what it is, audio permission, open at login.
struct WelcomeView: View {
    let model: IslandModel
    let onFinish: () -> Void

    @State private var step = 0
    @State private var permission = PermissionState.notAsked
    @State private var openAtLogin = true

    private enum PermissionState { case notAsked, asking, asked }
    private static let stepCount = 3

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                switch step {
                case 0: intro.transition(stepTransition)
                case 1: permissionStep.transition(stepTransition)
                default: loginStep.transition(stepTransition)
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()

            HStack {
                dots
                Spacer()
                primaryButton
            }
        }
        .padding(.top, 6)
    }

    // MARK: Steps

    private var intro: some View {
        stepLayout(
            title: "Welcome to Soundfork",
            text: "Send each app to its own speaker, each with its own volume. Soundfork lives in your notch: rest the pointer on it, or press the shortcut, whenever you need it.",
            art: {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
            },
            extra: {
                HStack(spacing: 8) {
                    Label("Hover the notch", systemImage: "cursorarrow.motionlines")
                    Text("or").foregroundStyle(.white.opacity(0.35))
                    KeyBadge(text: AppSettings.shortcutDisplay)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            }
        )
    }

    private var permissionStep: some View {
        stepLayout(
            title: "Allow audio access",
            text: "To move an app to another speaker, Soundfork needs permission to capture that app's audio. It only redirects it to the device you pick. Nothing is recorded, and nothing leaves your Mac.",
            art: { glyph(permission == .asked ? "checkmark" : "waveform", tint: permission == .asked ? .green : .white) },
            extra: {
                if permission == .asked {
                    Text("If macOS asked, choose Allow. You can change it later in System Settings › Privacy & Security.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
            }
        )
    }

    private var loginStep: some View {
        stepLayout(
            title: "Runs quietly in the background",
            text: "No windows, no Dock icon. Soundfork stays out of the way until you need it, and you can quit it anytime from Settings or the menu-bar icon.",
            art: { glyph("moon.zzz.fill", tint: .white) },
            extra: {
                HStack(spacing: 10) {
                    Text("Open at login")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                    IslandToggle(isOn: openAtLogin) { openAtLogin = $0 }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(.white.opacity(0.07)))
            }
        )
    }

    // MARK: Pieces

    private var primaryButton: some View {
        Group {
            switch step {
            case 0:
                IslandButton(title: "Continue") { advance() }
            case 1 where permission == .notAsked:
                HStack(spacing: 8) {
                    IslandButton(title: "Later", prominent: false) { advance() }
                    IslandButton(title: "Allow Access", systemImage: "lock.open.fill") { askPermission() }
                }
            case 1 where permission == .asking:
                ProgressView().controlSize(.small).tint(.white).frame(height: 30)
            case 1:
                IslandButton(title: "Continue") { advance() }
            default:
                IslandButton(title: "Done") {
                    model.settings.setOpenAtLogin(openAtLogin)
                    onFinish()
                }
            }
        }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(0..<Self.stepCount, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(index == step ? 0.9 : 0.2))
                    .frame(width: index == step ? 16 : 6, height: 6)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: step)
    }

    private var stepTransition: AnyTransition {
        .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity))
    }

    private func stepLayout<Art: View, Extra: View>(title: String, text: String,
                                                    @ViewBuilder art: () -> Art,
                                                    @ViewBuilder extra: () -> Extra) -> some View {
        VStack(spacing: 12) {
            art()
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
            extra()
        }
        .padding(.top, 4)
    }

    private func glyph(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 56, height: 56)
            .background(Circle().fill(.white.opacity(0.08)))
            .contentTransition(.symbolEffect(.replace))
    }

    private func advance() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { step += 1 }
    }

    private func askPermission() {
        withAnimation { permission = .asking }
        Task {
            await AudioCapturePermission.request()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { permission = .asked }
        }
    }
}
