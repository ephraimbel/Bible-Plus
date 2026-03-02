import SwiftUI

struct AudioMiniPlayerView: View {
    let audioService: AudioBibleService
    let chapterTitle: String
    let totalVerses: Int
    let onClose: () -> Void

    @Environment(\.bpPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar

            HStack(spacing: 16) {
                // Chapter info
                VStack(alignment: .leading, spacing: 2) {
                    Text(chapterTitle)
                        .font(BPFont.button)
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)

                    Text(verseProgressText)
                        .font(BPFont.caption)
                        .foregroundStyle(palette.textMuted)
                }

                Spacer()

                // Speed button
                Button {
                    cycleSpeed()
                } label: {
                    Text(audioService.playbackSpeed.displayName)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().stroke(palette.accent, lineWidth: 1)
                        )
                }

                // Play/Pause button
                Button {
                    HapticService.lightImpact()
                    audioService.togglePlayback()
                } label: {
                    Image(systemName: audioService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(palette.accent)
                        .frame(width: 44, height: 44)
                }

                // Close button
                Button {
                    HapticService.lightImpact()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.textMuted)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider().overlay(palette.border)
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            let progress = totalVerses > 0
                ? CGFloat(audioService.currentVerseIndex + 1) / CGFloat(totalVerses)
                : 0

            Rectangle()
                .fill(palette.accent)
                .frame(width: geo.size.width * progress, height: 2)
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
        .frame(height: 2)
    }

    // MARK: - Helpers

    private var verseProgressText: String {
        if audioService.isLoading {
            return "Generating audio..."
        }
        let voiceName = audioService.selectedVoice.displayName
        return "Verse \(audioService.currentVerseIndex + 1) of \(totalVerses) \u{00B7} \(voiceName)"
    }

    private func cycleSpeed() {
        let speeds = PlaybackSpeed.allCases
        guard let currentIdx = speeds.firstIndex(of: audioService.playbackSpeed) else { return }
        let nextIdx = (currentIdx + 1) % speeds.count
        audioService.setSpeed(speeds[nextIdx])
        HapticService.selection()
    }
}
