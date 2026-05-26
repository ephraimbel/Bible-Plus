import SwiftUI

// MARK: - AI Companion Scene
//
// A live recreation of the Bible+ AI "ask" page. Faithful to ChatView: a
// scrolling conversation that auto-pins to the bottom as the answer streams in
// (so it flows down, never cuts off), with the "Ask anything…" input bar fixed
// at the base. The assistant answers a real, human question with warmth, then a
// scripture art card (a biblical painting) — the same rich formatting the real
// chat uses. No SwiftData, no networking; choreographed and deterministic.
//
// Animation, step by step:
//   1. Nav + input bar fade in (chrome is present from the start).
//   2. The question slides up from the right; view scrolls to it.
//   3. The assistant "thinks" (typing dots).
//   4. The answer types out word-by-word; the view auto-scrolls to follow it.
//   5. A scripture card (biblical painting + verse) rises in; view scrolls to
//      reveal it fully.
//   6. Hold on the finished, composed answer.
struct AICompanionScene: View {
    var threadTitle: String = "Forgiveness"
    var question: String = "How do I forgive someone who isn't sorry?"
    var answer: String = "Forgiveness doesn't mean what they did was okay. It means handing the weight to God — so you can walk free, even before they're ever sorry."
    var verse: String = "Bear with each other and forgive one another, as the Lord forgave you."
    var reference: String = "Colossians 3:13"
    /// A biblical painting matched to the moment — forgiveness → the Prodigal Son.
    var artKey: String = "biblical_prodigal_son"
    var loops: Bool = false

    @Environment(\.bpPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // 0 idle · 1 question · 2 thinking · 3 answering · 4 scripture card.
    @State private var stage: Int = 0
    @State private var revealedChars: Int = 0
    @State private var chromeOpacity: Double = 0
    @State private var choreography: Task<Void, Never>? = nil

    var body: some View {
        VStack(spacing: 0) {
            navBar
                .opacity(chromeOpacity)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        if stage >= 1 { userBubble }
                        if stage == 2 { thinkingRow }
                        if stage >= 3 { assistantResponse }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 14)
                }
                .scrollBounceBehavior(.basedOnSize)
                // Keep the latest content in view as the answer streams — the
                // conversation flows down instead of cutting off.
                .onChange(of: revealedChars) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                .onChange(of: stage) { _, _ in
                    withAnimation(.easeOut(duration: 0.45)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            // Fixed input bar — the signature ask-page element, always visible.
            inputBar
                .opacity(chromeOpacity)
        }
        .background(palette.background)
        .onAppear { start() }
        .onDisappear {
            choreography?.cancel()
            choreography = nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A preview of the Bible Plus AI companion answering: \(question)")
    }

    // MARK: - Nav

    private var navBar: some View {
        ZStack {
            Text(threadTitle)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(palette.textPrimary)
            HStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.accent)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 32)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.border.opacity(0.5)).frame(height: 0.5)
        }
    }

    // MARK: - Messages

    private var userBubble: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 30)
            Text(question)
                .font(.custom("Georgia", size: 15))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.white)
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: 17, bottomLeadingRadius: 17, bottomTrailingRadius: 17, topTrailingRadius: 5)
                        .fill(LinearGradient(colors: [palette.accent, palette.accent.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: palette.accent.opacity(0.22), radius: 9, y: 4)
                )
        }
        .transition(.asymmetric(insertion: .offset(y: 10).combined(with: .opacity), removal: .opacity))
    }

    private var thinkingRow: some View {
        HStack(alignment: .center, spacing: 10) {
            sparkleAvatar(26)
            MiniTypingDots(color: palette.textMuted.opacity(0.55))
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(Capsule().fill(palette.surface.opacity(0.7)))
            Spacer(minLength: 0)
        }
        .transition(.opacity)
    }

    private var assistantResponse: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 10) {
                sparkleAvatar(26)
                Text(revealedAnswer)
                    .font(.system(size: 15.5, weight: .medium, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if stage >= 4 {
                scriptureCard
            }
        }
        .transition(.opacity)
    }

    // MARK: - Scripture card (biblical painting + verse)

    private var scriptureCard: some View {
        VStack(spacing: 0) {
            Image(artKey)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 108)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, palette.surfaceElevated.opacity(0.45), palette.surfaceElevated],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 60)
                    .allowsHitTesting(false)
                }

            VStack(alignment: .leading, spacing: 9) {
                Text("FROM SCRIPTURE")
                    .font(.system(size: 8.5, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(palette.accent.opacity(0.7))

                Text(verse)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(palette.textPrimary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Rectangle().fill(palette.accent.opacity(0.4)).frame(width: 16, height: 1)
                    Text(reference)
                        .font(.system(size: 11.5, weight: .medium, design: .serif))
                        .foregroundStyle(palette.accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surfaceElevated)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.accent.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.1), radius: 12, y: 5)
        .transition(.asymmetric(insertion: .offset(y: 14).combined(with: .opacity), removal: .opacity))
    }

    // MARK: - Input bar (mirrors ChatView.inputBar)

    private var inputBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(palette.border.opacity(0.4)).frame(height: 0.5)
            HStack(spacing: 9) {
                Image(systemName: "waveform")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(palette.accent.opacity(0.1)))
                    .overlay(Circle().stroke(palette.accent.opacity(0.18), lineWidth: 0.5))

                Text("Ask anything…")
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(palette.surfaceElevated)
                            .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(palette.border.opacity(0.12), lineWidth: 0.5))

                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(LinearGradient(colors: [palette.accent, palette.accent.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: palette.accent.opacity(0.25), radius: 5, y: 2)
                    )
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
        }
        .background(palette.background)
    }

    // MARK: - Sparkle Avatar (matches ChatBubbleView.aiIndicator)

    private func sparkleAvatar(_ size: CGFloat) -> some View {
        ZStack {
            Circle().fill(palette.accent.opacity(0.08)).frame(width: size, height: size)
            Circle()
                .fill(LinearGradient(colors: [palette.accent.opacity(0.18), palette.accent.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size * 0.84, height: size * 0.84)
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(LinearGradient(colors: [Color(red: 1.0, green: 0.84, blue: 0.3), palette.accent], startPoint: .top, endPoint: .bottom))
        }
    }

    private var revealedAnswer: String {
        guard revealedChars > 0 else { return " " }
        let count = min(revealedChars, answer.count)
        let end = answer.index(answer.startIndex, offsetBy: count)
        return String(answer[answer.startIndex..<end])
    }

    // MARK: - Choreography

    private func start() {
        choreography?.cancel()
        withAnimation(.easeOut(duration: 0.5)) { chromeOpacity = 1 }

        if reduceMotion {
            revealedChars = answer.count
            stage = 4
            return
        }
        choreography = Task { @MainActor in await run() }
    }

    @MainActor
    private func run() async {
        repeat {
            stage = 0
            revealedChars = 0

            guard await pause(0.5) else { return }
            withAnimation(BPAnimation.arrive) { stage = 1 }

            guard await pause(0.6) else { return }
            withAnimation(.easeOut(duration: 0.35)) { stage = 2 }

            guard await pause(0.7) else { return }
            withAnimation(.easeOut(duration: 0.25)) { stage = 3 }

            // Type the answer out, scrolling to follow it (see body.onChange).
            for i in 1...answer.count {
                if Task.isCancelled { return }
                revealedChars = i
                guard await pause(0.018) else { return }
            }

            guard await pause(0.4) else { return }
            withAnimation(BPAnimation.arrive) { stage = 4 }

            guard await pause(loops ? 5.0 : 60.0) else { return }
        } while loops && !Task.isCancelled
    }

    @MainActor
    private func pause(_ seconds: Double) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}

// MARK: - Mini Typing Dots

private struct MiniTypingDots: View {
    let color: Color
    @State private var phase: Int = 0
    private let timer = Timer.publish(every: 0.32, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .opacity(phase == i ? 1 : 0.35)
                    .scaleEffect(phase == i ? 1.0 : 0.7)
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.28)) { phase = (phase + 1) % 3 }
        }
    }
}

#Preview("AI Companion Scene") {
    ZStack {
        BPColorPalette.light.background.ignoresSafeArea()
        DeviceFrame(width: 264) {
            AICompanionScene()
                .environment(\.bpPalette, .light)
        }
    }
}
