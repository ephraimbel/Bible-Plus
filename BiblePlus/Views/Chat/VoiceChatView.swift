import SwiftUI

// MARK: - Voice Chat View
//
// Full-screen hands-free conversation surface. The user taps the mic, speaks,
// and the same conversation flow that powers text chat handles streaming +
// persistence. The AI's response is read aloud sentence-by-sentence as it
// streams in.
//
// Visual states map directly to VoiceChatService.state:
//   .idle       — soft orb, "Tap to speak"
//   .listening  — pulsing orb, live transcript scrolls
//   .processing — spinning orb, "Thinking..."
//   .speaking   — slowly pulsing orb, AI text fades in below
//
// The view OWNS its VoiceChatService instance for the duration of the sheet.
// It explicitly tears down the service on disappear so the audio session is
// released and the soundscape (if any) can resume cleanly.

struct VoiceChatView: View {
    @Bindable var chatViewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    @State private var voiceService = VoiceChatService()
    @State private var orbPulse: Bool = false
    @State private var lastFedContentLength: Int = 0
    @State private var lastFedMessageId: UUID? = nil
    @State private var permissionDeniedShown = false
    @State private var startupErrorMessage: String? = nil

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar

                Spacer()

                // The orb IS the control — tap it to speak / send / stop. No
                // separate button; the status label below tells you what a tap
                // will do. Pure and minimal.
                orb
                    .contentShape(Circle())
                    .onTapGesture {
                        guard primaryButtonEnabled else { return }
                        HapticService.lightImpact()
                        handlePrimaryTap()
                    }

                Spacer().frame(height: 28)

                statusLabel

                Spacer().frame(height: 16)

                transcriptArea
                    .frame(maxHeight: 200)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
        .task {
            await setupOnAppear()
        }
        .onDisappear {
            voiceService.teardown()
        }
        .onChange(of: chatViewModel.displayMessages.last?.content ?? "") { _, newContent in
            handleStreamDelta(newContent)
        }
        .onChange(of: chatViewModel.isStreaming) { _, isStreaming in
            if !isStreaming {
                // Stream just ended — flush whatever's left in the sentence
                // buffer so the tail of the response gets spoken.
                voiceService.finishStreaming()
                lastFedContentLength = 0
                lastFedMessageId = nil
            }
        }
        .alert("Permissions needed", isPresented: $permissionDeniedShown) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("Voice chat needs microphone and speech recognition access. Enable both in Settings → Bible+ to continue.")
        }
    }

    // MARK: - Background

    private var background: some View {
        // A clean, flat near-black with a whisper of warmth — no glowing accent
        // blob behind the orb. Lets the page read calm and minimal.
        LinearGradient(
            colors: [
                Color(red: 0.09, green: 0.08, blue: 0.07),
                Color(red: 0.05, green: 0.05, blue: 0.05),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Spacer()

            Button {
                HapticService.lightImpact()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.10))
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.18), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    // MARK: - Orb

    private var orb: some View {
        ZStack {
            // A single thin ring — barely there at idle, a touch brighter when
            // active. The only accent on the page.
            Circle()
                .strokeBorder(palette.accent.opacity(ringOpacity), lineWidth: 1)
                .frame(width: 172, height: 172)
                .scaleEffect(orbPulse ? 1.03 : 1.0)

            // A calm frosted-glass disc — no fill colour, no glow. Premium and
            // quiet; the material does the work.
            Circle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .frame(width: 128, height: 128)
                .overlay(Circle().strokeBorder(.white.opacity(0.10), lineWidth: 0.5))
                .scaleEffect(orbPulse ? 1.015 : 1.0)

            // The state icon — quiet gold, the single warm note.
            Image(systemName: orbIcon)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(palette.accent)
                .symbolEffect(.pulse, options: orbPulseOptions, value: orbPulse)
        }
        .animation(orbAnimation, value: orbPulse)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: voiceService.state)
        .onAppear { orbPulse = true }
    }

    /// The orb ring is nearly invisible at rest and strengthens subtly while
    /// the assistant is listening or speaking — a quiet state cue.
    private var ringOpacity: Double {
        switch voiceService.state {
        case .idle: return 0.22
        case .listening: return 0.6
        case .processing: return 0.4
        case .speaking: return 0.5
        }
    }

    private var orbIcon: String {
        switch voiceService.state {
        case .idle: return "mic.fill"
        case .listening: return "waveform"
        case .processing: return "sparkle"
        case .speaking: return "speaker.wave.2.fill"
        }
    }

    private var orbAnimation: Animation {
        switch voiceService.state {
        case .idle: return .easeInOut(duration: 2.4).repeatForever(autoreverses: true)
        case .listening: return .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
        case .processing: return .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
        case .speaking: return .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
        }
    }

    private var orbPulseOptions: SymbolEffectOptions {
        switch voiceService.state {
        case .listening: return .repeating.speed(2.0)
        case .processing: return .repeating.speed(1.4)
        case .speaking: return .repeating.speed(1.0)
        case .idle: return .nonRepeating
        }
    }

    // MARK: - Status Label

    private var statusLabel: some View {
        Text(statusText)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .tracking(2.0)
            .foregroundStyle(.white.opacity(0.65))
            .textCase(.uppercase)
    }

    private var statusText: String {
        if let err = startupErrorMessage { return err }
        switch voiceService.state {
        case .idle: return "Tap to speak"
        case .listening: return "Listening…"
        case .processing: return "Thinking…"
        case .speaking: return "Speaking"
        }
    }

    // MARK: - Transcript / Response

    private var transcriptArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if voiceService.state == .listening, !voiceService.liveTranscript.isEmpty {
                    Text(voiceService.liveTranscript)
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineSpacing(6)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                } else if let last = chatViewModel.displayMessages.last,
                          last.role == .assistant,
                          !last.content.isEmpty,
                          (voiceService.state == .speaking || voiceService.state == .processing) {
                    Text(plainAssistantText(from: last.content))
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.white.opacity(0.85))
                        .lineSpacing(5)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                } else if voiceService.state == .idle {
                    Text("Speak naturally — Bible+ will respond out loud.")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .animation(.easeInOut(duration: 0.25), value: voiceService.state)
        }
        .scrollIndicators(.hidden)
    }

    /// Strips card markup for the on-screen rendering of the AI response.
    /// Same machinery used by the TTS layer.
    private func plainAssistantText(from content: String) -> String {
        ChatTTSService.cleanForSpeech(content)
    }

    // MARK: - Tap Handling

    /// Whether a tap on the orb does anything in the current state (disabled
    /// only while the assistant is processing).
    private var primaryButtonEnabled: Bool {
        switch voiceService.state {
        case .processing: return false
        default: return true
        }
    }

    private func handlePrimaryTap() {
        switch voiceService.state {
        case .idle:
            beginListening()
        case .listening:
            sendCurrentTranscript()
        case .processing:
            break
        case .speaking:
            voiceService.stopSpeaking()
        }
    }

    // MARK: - Setup / Teardown

    private func setupOnAppear() async {
        voiceService.refreshPermissionStatus()
        if !voiceService.hasAllPermissions {
            let granted = await voiceService.requestPermissions()
            if !granted {
                permissionDeniedShown = true
                return
            }
        }
    }

    private func beginListening() {
        startupErrorMessage = nil
        do {
            try voiceService.startListening()
        } catch let error as VoiceChatError {
            startupErrorMessage = error.localizedDescription
            HapticService.notification(.warning)
        } catch {
            startupErrorMessage = "Could not start the microphone."
            HapticService.notification(.warning)
        }
    }

    private func sendCurrentTranscript() {
        let text = voiceService.stopListening().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Reset streaming bookkeeping for the upcoming assistant response.
        lastFedContentLength = 0
        lastFedMessageId = nil
        voiceService.enterProcessing()

        // sendQuickPrompt sets inputText then calls the standard send flow,
        // so the message persists into SwiftData and shows up the next time
        // the user opens the conversation in text mode.
        chatViewModel.sendQuickPrompt(text)
    }

    /// Called whenever the latest assistant message's content changes during
    /// streaming. Computes the delta versus the last frame and feeds it to
    /// the voice service so sentences are spoken as they arrive.
    private func handleStreamDelta(_ newContent: String) {
        guard chatViewModel.isStreaming else { return }
        guard let last = chatViewModel.displayMessages.last,
              last.role == .assistant else { return }

        // New assistant message — reset the cursor so we don't replay text
        // from a previous turn.
        if lastFedMessageId != last.id {
            lastFedMessageId = last.id
            lastFedContentLength = 0
        }

        guard newContent.count > lastFedContentLength else { return }
        let startIndex = newContent.index(newContent.startIndex, offsetBy: lastFedContentLength)
        let delta = String(newContent[startIndex...])
        lastFedContentLength = newContent.count

        if !delta.isEmpty {
            voiceService.feedStreamingText(delta)
        }
    }
}
