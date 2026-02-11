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

    @Environment(\.bpPalette) private var palette
    @State private var heartScale: CGFloat = 1.0
    @State private var showVolumeSlider = false

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

            // Volume slider — visible when audio is playing and user taps sound button
            if showVolumeSlider && isAudioPlaying {
                MiniVolumeSlider(volume: volume, onVolumeChange: onVolumeChange)
                    .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
            }

            // Sound toggle — tap to toggle or show volume, long-press to open Sanctuary
            actionButton(
                icon: isAudioPlaying ? "speaker.wave.2.fill" : "speaker.slash",
                color: isAudioPlaying ? palette.accent : .white
            ) {
                HapticService.selection()
                if isAudioPlaying {
                    withAnimation(BPAnimation.spring) {
                        showVolumeSlider.toggle()
                    }
                } else {
                    onToggleSound()
                    // Show slider when turning on
                    withAnimation(BPAnimation.spring.delay(0.2)) {
                        showVolumeSlider = true
                    }
                }
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        HapticService.impact(.medium)
                        onOpenSanctuary()
                    }
            )

            Spacer()
                .frame(height: 120)
        }
        .onChange(of: isAudioPlaying) { _, playing in
            if !playing {
                withAnimation(BPAnimation.spring) {
                    showVolumeSlider = false
                }
            }
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

// MARK: - Mini Volume Slider

private struct MiniVolumeSlider: View {
    let volume: Float
    let onVolumeChange: (Float) -> Void

    private let trackHeight: CGFloat = 100
    private let trackWidth: CGFloat = 6
    private let thumbSize: CGFloat = 18

    var body: some View {
        ZStack(alignment: .bottom) {
            // Track background
            Capsule()
                .fill(.white.opacity(0.2))
                .frame(width: trackWidth, height: trackHeight)

            // Filled track
            Capsule()
                .fill(Color(hex: "C9A96E"))
                .frame(width: trackWidth, height: trackHeight * CGFloat(volume))

            // Thumb
            Circle()
                .fill(Color(hex: "C9A96E"))
                .frame(width: thumbSize, height: thumbSize)
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                .offset(y: -((trackHeight - thumbSize) * CGFloat(volume)))
        }
        .frame(width: 44, height: trackHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    // Invert Y axis — top is max, bottom is min
                    let normalizedY = 1.0 - (value.location.y / trackHeight)
                    let clamped = Float(max(0, min(1, normalizedY)))
                    onVolumeChange(clamped)
                }
        )
    }
}
