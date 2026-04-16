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

                orb

                Spacer().frame(height: 32)

                statusLabel

                Spacer().frame(height: 12)

                transcriptArea
                    .frame(maxHeight: 220)

                Spacer()

                primaryButton

                Spacer().frame(height: 48)
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
        ZStack {
            // Deep gradient base — same warm tones as the rest of the app but
            // pushed darker so the orb pops. Always uses dark-mode colors for
            // visual consistency regardless of system theme.
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.04),
                    Color(red: 0.14, green: 0.10, blue: 0.06),
                    Color(red: 0.06, green: 0.05, blue: 0.04),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Radial accent glow behind the orb
            RadialGradient(
                colors: [
                    palette.accent.opacity(stateGlowStrength),
                    .clear,
                ],
                center: .center,
                startRadius: 20,
                endRadius: 320
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.4), value: voiceService.state)
        }
    }

    private var stateGlowStrength: Double {
        switch voiceService.state {
        case .idle: return 0.10
        case .listening: return 0.28
        case .processing: return 0.20
        case .speaking: return 0.34
        }
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
            // Outermost halo — fades in/out with state
            Circle()
                .stroke(palette.accent.opacity(0.20), lineWidth: 1)
                .frame(width: 240, height: 240)
                .scaleEffect(orbPulse ? 1.06 : 0.98)
                .opacity(orbPulse ? 0.8 : 0.4)

            // Mid ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            palette.accent.opacity(0.30),
                            palette.accent.opacity(0.05),
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 110
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(orbPulse ? 1.04 : 1.0)

            // Core orb — bright accent
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            palette.accent,
                            palette.accent.opacity(0.7),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 130, height: 130)
                .shadow(color: palette.accent.opacity(0.6), radius: 30, y: 0)
                .scaleEffect(orbPulse ? 1.02 : 0.98)

            // Iconography in the center reflects state
            Image(systemName: orbIcon)
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, options: orbPulseOptions, value: orbPulse)
        }
        .animation(orbAnimation, value: orbPulse)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: voiceService.state)
        .onAppear { orbPulse = true }
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

    // MARK: - Primary Button

    private var primaryButton: some View {
        Button {
            HapticService.lightImpact()
            handlePrimaryTap()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: primaryButtonIcon)
                    .font(.system(size: 16, weight: .semibold))
                Text(primaryButtonLabel)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(.white.opacity(0.95))
                    .shadow(color: palette.accent.opacity(0.4), radius: 18, y: 8)
            )
        }
        .buttonStyle(.plain)
        .opacity(primaryButtonEnabled ? 1.0 : 0.45)
        .disabled(!primaryButtonEnabled)
    }

    private var primaryButtonLabel: String {
        switch voiceService.state {
        case .idle: return "Tap to speak"
        case .listening: return "Send"
        case .processing: return "Thinking…"
        case .speaking: return "Stop"
        }
    }

    private var primaryButtonIcon: String {
        switch voiceService.state {
        case .idle: return "mic.fill"
        case .listening: return "checkmark"
        case .processing: return "sparkle"
        case .speaking: return "stop.fill"
        }
    }

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
