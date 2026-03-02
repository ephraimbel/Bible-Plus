import SwiftUI
import AVFoundation
import CryptoKit

struct VoicePickerView: View {
    let audioService: AudioBibleService
    let isPro: Bool
    let onSelect: (BibleVoice) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @State private var previewingVoice: BibleVoice? = nil
    @State private var isLoadingPreview: Bool = false
    @State private var previewPlayer: AVAudioPlayer?
    @State private var previewTask: Task<Void, Never>?
    @State private var showPaywall = false

    private static let sampleText = "The Lord is my shepherd; I shall not want. He maketh me to lie down in green pastures."

    private static let ttsEndpoint = URL(string: "\(Secrets.supabaseURL)/functions/v1/tts")!

    private static var cacheDirectory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VoicePreviewCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    var body: some View {
        NavigationStack {
            List {
                // Pro banner
                if !isPro {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(hex: "C9A96E"))
                            Text("Audio Bible is a Pro feature")
                                .font(BPFont.button)
                                .foregroundStyle(palette.textPrimary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(palette.surface.opacity(0.6))
                }

                // Male voices
                Section {
                    ForEach(BibleVoice.maleVoices) { voice in
                        voiceRow(voice, locked: !isPro)
                    }
                } header: {
                    HStack(spacing: 5) {
                        Text("Male")
                            .font(BPFont.button)
                            .foregroundStyle(.secondary)
                        if !isPro {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowBackground(palette.surface)

                // Female voices
                Section {
                    ForEach(BibleVoice.femaleVoices) { voice in
                        voiceRow(voice, locked: !isPro)
                    }
                } header: {
                    HStack(spacing: 5) {
                        Text("Female")
                            .font(BPFont.button)
                            .foregroundStyle(.secondary)
                        if !isPro {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
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
            stopPreview()
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
                        if isLoadingPreview && previewingVoice == voice {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 36, height: 36)
                        } else {
                            Image(systemName: previewingVoice == voice
                                ? "stop.circle.fill"
                                : "play.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(palette.accent)
                                .frame(width: 36, height: 36)
                        }
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

    // MARK: - Preview (OpenAI TTS)

    private func previewVoice(_ voice: BibleVoice) {
        // Toggle off if already previewing this voice
        if previewingVoice == voice {
            stopPreview()
            return
        }

        // Stop any current preview
        stopPreview()

        HapticService.lightImpact()
        previewingVoice = voice
        isLoadingPreview = true

        previewTask = Task {
            do {
                let audioData = try await fetchPreviewAudio(voice: voice)
                guard !Task.isCancelled else { return }

                let player = try AVAudioPlayer(data: audioData)
                player.prepareToPlay()

                // Configure audio session
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, options: [.duckOthers])
                try session.setActive(true)

                self.previewPlayer = player
                self.isLoadingPreview = false
                player.play()

                // Wait for playback to finish
                while player.isPlaying {
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
                guard !Task.isCancelled else { return }
                self.previewingVoice = nil
            } catch {
                guard !Task.isCancelled else { return }
                self.isLoadingPreview = false
                self.previewingVoice = nil
            }
        }
    }

    private func fetchPreviewAudio(voice: BibleVoice) async throws -> Data {
        // Check local cache
        let cacheKey = previewCacheKey(voice: voice)
        let cachedURL = Self.cacheDirectory.appendingPathComponent("\(cacheKey).mp3")
        if let data = try? Data(contentsOf: cachedURL), !data.isEmpty {
            return data
        }

        // Call TTS API
        var request = URLRequest(url: Self.ttsEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "tts-1",
            "input": Self.sampleText,
            "voice": voice.apiVoice,
            "response_format": "mp3",
            "speed": 1.0
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              !data.isEmpty else {
            throw URLError(.badServerResponse)
        }

        // Cache locally
        try? data.write(to: cachedURL)

        return data
    }

    private func previewCacheKey(voice: BibleVoice) -> String {
        let input = "\(voice.apiVoice):\(Self.sampleText)"
        let digest = SHA256.hash(data: Data(input.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return "preview-\(voice.apiVoice)-\(hash.prefix(16))"
    }

    private func stopPreview() {
        previewTask?.cancel()
        previewTask = nil
        previewPlayer?.stop()
        previewPlayer = nil
        previewingVoice = nil
        isLoadingPreview = false
    }
}
