import SwiftUI
import AVFoundation

struct VoicePickerView: View {
    let audioService: AudioBibleService
    let isPro: Bool
    let onSelect: (BibleVoice) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @State private var previewingVoice: BibleVoice? = nil
    @State private var isPreviewLoading = false
    @State private var previewTask: Task<Void, Never>?
    @State private var previewPlayer: AVAudioPlayer?

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
            previewTask?.cancel()
            previewPlayer?.stop()
            previewPlayer = nil
        }
    }

    // MARK: - Voice Row

    @ViewBuilder
    private func voiceRow(_ voice: BibleVoice, locked: Bool) -> some View {
        Button {
            if locked { return }
            HapticService.selection()
            onSelect(voice)
        } label: {
            HStack(spacing: 12) {
                // Name and description
                VStack(alignment: .leading, spacing: 3) {
                    Text(voice.displayName)
                        .font(BPFont.button)
                        .foregroundStyle(palette.textPrimary)

                    Text(voice.subtitle)
                        .font(BPFont.caption)
                        .foregroundStyle(palette.textMuted)
                }

                Spacer()

                // Preview button
                if !locked {
                    Button {
                        previewVoice(voice)
                    } label: {
                        Group {
                            if isPreviewLoading && previewingVoice == voice {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: previewingVoice == voice
                                    ? "speaker.wave.2.fill"
                                    : "play.circle")
                                    .font(.system(size: 18))
                            }
                        }
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
        .disabled(locked)
        .opacity(locked ? 0.5 : 1)
    }

    // MARK: - Preview

    private func previewVoice(_ voice: BibleVoice) {
        previewTask?.cancel()

        if previewingVoice == voice {
            previewPlayer?.stop()
            previewPlayer = nil
            previewingVoice = nil
            return
        }

        previewingVoice = voice
        isPreviewLoading = true
        HapticService.lightImpact()

        previewTask = Task {
            do {
                let sampleText = "The Lord is my shepherd; I shall not want. He maketh me to lie down in green pastures."
                let data = try await generatePreview(text: sampleText, voice: voice)
                guard !Task.isCancelled else { return }

                let player = try AVAudioPlayer(data: data)
                self.previewPlayer = player
                player.play()

                isPreviewLoading = false

                // Wait for playback to finish, then reset
                try await Task.sleep(nanoseconds: UInt64(player.duration * 1_000_000_000) + 500_000_000)
                if previewingVoice == voice {
                    previewingVoice = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                isPreviewLoading = false
                previewingVoice = nil
            }
        }
    }

    private func generatePreview(text: String, voice: BibleVoice) async throws -> Data {
        let endpoint = URL(string: "https://api.openai.com/v1/audio/speech")!
        let body: [String: Any] = [
            "model": "tts-1-hd",
            "input": text,
            "voice": voice.apiVoice,
            "response_format": "mp3",
            "speed": voice.ttsSpeed
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(
            "Bearer \(Secrets.openAIAPIKey)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              !data.isEmpty else {
            throw AudioBibleError.invalidResponse
        }

        return data
    }
}
