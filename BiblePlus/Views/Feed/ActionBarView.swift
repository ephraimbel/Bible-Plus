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
        VStack(spacing: 24) {
            Spacer()

            // Heart — Save / Favorite
            actionButton(
                icon: isSaved ? "heart.fill" : "heart",
                color: isSaved ? palette.accent : .white,
                scale: heartScale
            ) {
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

            // Share as Image
            actionButton(icon: "square.and.arrow.up", color: .white) {
                HapticService.impact(.medium)
                onShare()
            }

            // Add to Collection
            actionButton(icon: "pin", color: .white) {
                HapticService.selection()
                onPin()
            }

            // Ask the AI
            actionButton(icon: "bubble.left.and.bubble.right", color: .white) {
                HapticService.selection()
                onAskAI()
            }

            // Theme / Background picker
            actionButton(icon: "paintpalette", color: .white) {
                HapticService.selection()
                onOpenBackgrounds()
            }

            // Soundscape picker
            actionButton(
                icon: isAudioPlaying ? "speaker.wave.2.fill" : "speaker.slash",
                color: isAudioPlaying ? palette.accent : .white
            ) {
                HapticService.selection()
                onOpenSoundscapes()
            }

            Spacer()
                .frame(height: 120)
        }
    }

    @ViewBuilder
    private func actionButton(
        icon: String,
        color: Color,
        scale: CGFloat = 1.0,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
                .scaleEffect(scale)
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                .frame(width: 44, height: 44)
        }
    }
}
