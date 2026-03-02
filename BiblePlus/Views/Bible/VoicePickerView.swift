import SwiftUI
import AVFoundation

struct VoicePickerView: View {
    let audioService: AudioBibleService
    let isPro: Bool
    let onSelect: (BibleVoice) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @State private var previewingVoice: BibleVoice? = nil
    @State private var previewSynthesizer: AVSpeechSynthesizer?
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                // Free voices
                Section {
                    ForEach(BibleVoice.freeVoices) { voice in
                        voiceRow(voice, locked: false)
                    }
                } header: {
                    Text("Free")
                        .font(BPFont.button)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(palette.surface)

                // Pro Male voices
                Section {
                    ForEach(BibleVoice.proMaleVoices) { voice in
                        voiceRow(voice, locked: !isPro)
                    }
                } header: {
                    HStack(spacing: 5) {
                        Text("Male Voices")
                            .font(BPFont.button)
                            .foregroundStyle(.secondary)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "C9A96E"))
                    }
                }
                .listRowBackground(palette.surface)

                // Pro Female voices
                Section {
                    ForEach(BibleVoice.proFemaleVoices) { voice in
                        voiceRow(voice, locked: !isPro)
                    }
                } header: {
                    HStack(spacing: 5) {
                        Text("Female Voices")
                            .font(BPFont.button)
                            .foregroundStyle(.secondary)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "C9A96E"))
                    }
                }
                .listRowBackground(palette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("Narrator Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(palette.accent)
                }
            }
            .toolbarBackground(palette.background, for: .navigationBar)
        }
        .onDisappear {
            previewSynthesizer?.stopSpeaking(at: .immediate)
            previewSynthesizer = nil
            previewingVoice = nil
        }
        .fullScreenCover(isPresented: $showPaywall) {
            SummaryPaywallView()
        }
    }

    // MARK: - Voice Row

    @ViewBuilder
    private func voiceRow(_ voice: BibleVoice, locked: Bool) -> some View {
        Button {
            if locked {
                showPaywall = true
                return
            }
            HapticService.selection()
            onSelect(voice)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                // Name and description
                VStack(alignment: .leading, spacing: 3) {
                    Text(voice.displayName)
                        .font(BPFont.button)
                        .foregroundStyle(palette.textPrimary)

                    HStack(spacing: 4) {
                        Text(voice.subtitle)
                            .font(BPFont.caption)
                            .foregroundStyle(palette.textMuted)

                        if !voice.isVoiceDownloaded {
                            Text("· Download in Settings")
                                .font(BPFont.caption)
                                .foregroundStyle(palette.accent.opacity(0.7))
                        }
                    }
                }

                Spacer()

                // Preview button
                if !locked {
                    Button {
                        previewVoice(voice)
                    } label: {
                        Image(systemName: previewingVoice == voice
                            ? "speaker.wave.2.fill"
                            : "play.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(palette.accent)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }

                // Selected check or lock
                if audioService.selectedVoice == voice {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(palette.accent)
                } else if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(palette.textMuted)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .opacity(locked ? 0.5 : 1)
    }

    // MARK: - Preview

    private func previewVoice(_ voice: BibleVoice) {
        // Toggle off if already previewing this voice
        if previewingVoice == voice {
            previewSynthesizer?.stopSpeaking(at: .immediate)
            previewSynthesizer = nil
            previewingVoice = nil
            return
        }

        // Stop any current preview
        previewSynthesizer?.stopSpeaking(at: .immediate)

        previewingVoice = voice
        HapticService.lightImpact()

        let sampleText = "The Lord is my shepherd; I shall not want. He maketh me to lie down in green pastures."
        let utterance = AVSpeechUtterance(string: sampleText)
        utterance.voice = voice.resolvedVoice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        let synthesizer = AVSpeechSynthesizer()
        self.previewSynthesizer = synthesizer
        synthesizer.speak(utterance)

        // Reset state when preview finishes
        Task {
            // Estimate duration (~100ms per word for default rate)
            let wordCount = sampleText.split(separator: " ").count
            let estimatedDuration = Double(wordCount) * 0.3 + 1.0
            try? await Task.sleep(nanoseconds: UInt64(estimatedDuration * 1_000_000_000))
            if previewingVoice == voice {
                previewingVoice = nil
            }
        }
    }
}
