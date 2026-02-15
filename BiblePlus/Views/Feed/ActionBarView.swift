import SwiftUI

struct ActionBarView: View {
    let isSaved: Bool
    var isAudioPlaying: Bool = false
    var volume: Float = 0.3
    var onSave: () -> Void = {}
    var onShare: () -> Void = {}
    var onPin: () -> Void = {}
    var onAskAI: () -> Void = {}
    var onToggleSound: () -> Void = {}
    var onVolumeChange: (Float) -> Void = { _ in }
    var onOpenSanctuary: () -> Void = {}
    var onOpenSoundscapes: () -> Void = {}
    var onOpenBackgrounds: () -> Void = {}

    @Environment(\.bpPalette) private var palette
    @State private var heartScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Frosted glass pill — vertically centered
            VStack(spacing: 0) {
                // Heart — Save / Favorite
                pillButton(
                    icon: isSaved ? "heart.fill" : "heart",
                    tint: isSaved ? palette.accent : nil,
                    scale: heartScale
                ) {
                    HapticService.impact(.light)
                    withAnimation(BPAnimation.spring) {
                        heartScale = 1.3
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(BPAnimation.spring) {
                            heartScale = 1.0
                        }
                    }
                    onSave()
                }
                .accessibilityLabel(isSaved ? "Remove from favorites" : "Save to favorites")

                // Share
                pillButton(icon: "square.and.arrow.up") {
                    HapticService.impact(.medium)
                    onShare()
                }
                .accessibilityLabel("Share")

                // Pin to collection
                pillButton(icon: "pin") {
                    HapticService.selection()
                    onPin()
                }
                .accessibilityLabel("Save to collection")

                // Ask AI
                pillButton(icon: "bubble.left.and.bubble.right") {
                    HapticService.selection()
                    onAskAI()
                }
                .accessibilityLabel("Ask AI about this")

                // Background theme
                pillButton(icon: "paintpalette") {
                    HapticService.selection()
                    onOpenBackgrounds()
                }
                .accessibilityLabel("Change background")

                // Soundscape
                pillButton(
                    icon: isAudioPlaying ? "speaker.wave.2.fill" : "speaker.slash",
                    tint: isAudioPlaying ? palette.accent : nil
                ) {
                    HapticService.selection()
                    onOpenSoundscapes()
                }
                .accessibilityLabel(isAudioPlaying ? "Pause soundscape" : "Play soundscape")
            }
            .padding(.vertical, 14)

            Spacer()
        }
    }

    // MARK: - Pill Button

    @ViewBuilder
    private func pillButton(
        icon: String,
        tint: Color? = nil,
        scale: CGFloat = 1.0,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(tint ?? .white)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 1)
                .scaleEffect(scale)
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PillActionButtonStyle())
    }

    // MARK: - Divider

    private var pillDivider: some View {
        Capsule()
            .fill(.white.opacity(0.06))
            .frame(width: 16, height: 0.5)
    }
}

// MARK: - Subtle press style for pill buttons

private struct PillActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
