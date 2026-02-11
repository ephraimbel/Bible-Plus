import SwiftUI

struct ActionBarView: View {
    let isSaved: Bool
    var onSave: () -> Void = {}
    var onShare: () -> Void = {}
    var onPin: () -> Void = {}
    var onAskAI: () -> Void = {}
    var onToggleSound: () -> Void = {}

    @State private var heartScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Heart — Save / Favorite
            actionButton(
                icon: isSaved ? "heart.fill" : "heart",
                color: isSaved ? BPColorPalette.light.accent : .white,
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

            // Share as Image (stub for Phase 4)
            actionButton(icon: "square.and.arrow.up", color: .white) {
                HapticService.impact(.medium)
                onShare()
            }

            // Add to Collection (stub)
            actionButton(icon: "pin", color: .white) {
                HapticService.selection()
                onPin()
            }

            // Ask the AI (stub)
            actionButton(icon: "bubble.left.and.bubble.right", color: .white) {
                HapticService.selection()
                onAskAI()
            }

            // Sound toggle
            actionButton(icon: "speaker.wave.2", color: .white) {
                onToggleSound()
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
