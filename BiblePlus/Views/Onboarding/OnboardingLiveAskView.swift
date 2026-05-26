import SwiftUI
import SwiftData

// MARK: - Live "Ask Anything" (the real product, mid-flow)
//
// The single most persuasive moment in the funnel: instead of SHOWING the AI
// (the S2 hook does that), this lets the user actually TYPE a question — or tap
// a burden-tailored suggestion — and watch a REAL pastoral answer stream in,
// tailored to what they just shared. "Show, then let them try."
//
// Robustness:
//   • Uses AIService.streamCompletion with a short-answer onboarding prompt
//     (plain prose, no card markup) so it renders as elegant typography.
//   • Never persists a ChatMessage → does NOT consume the 5 free lifetime
//     messages. Onboarding is a free taste.
//   • On ANY failure (offline, server, timeout) it falls back to a warm,
//     burden-matched canned answer. The screen never dead-ends.
//
// Warm Paper / light, so it sits naturally inside the question flow.
struct OnboardingLiveAskView: View {
    @Bindable var viewModel: OnboardingViewModel
    var onContinue: () -> Void = {}

    @Environment(\.bpPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase { case idle, thinking, streaming, done }

    @State private var phase: Phase = .idle
    @State private var questionText = ""
    @State private var submittedQuestion = ""
    @State private var answer = ""
    @State private var streamTask: Task<Void, Never>? = nil
    @State private var introIn = false
    @FocusState private var fieldFocused: Bool

    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)

    private var name: String {
        let n = viewModel.firstName.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "" : n
    }
    private var topBurden: Burden? { viewModel.selectedBurdens.first }

    var body: some View {
        ZStack {
            background
            if phase == .idle {
                idleView.transition(.opacity)
            } else {
                conversationView.transition(.opacity)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.6)) { introIn = true }
        }
        .onDisappear { streamTask?.cancel(); streamTask = nil }
    }

    // MARK: - Idle (ask)

    private var idleView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(accentGold.opacity(0.10)).frame(width: 60, height: 60)
                    Image(systemName: "sparkle")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(accentGold)
                }
                Text("ASK ME ANYTHING")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(accentGold)
                Text(promptHeadline)
                    .font(.custom("Baskerville-Bold", size: 26))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 26)
                Text("Type your own, or start with one of these.")
                    .font(.custom("Georgia-Italic", size: 15))
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(introIn ? 1 : 0)
            .offset(y: introIn ? 0 : 12)

            Spacer(minLength: 20)

            VStack(spacing: 10) {
                ForEach(suggestions, id: \.self) { s in
                    suggestionChip(s)
                }
            }
            .padding(.horizontal, 22)
            .opacity(introIn ? 1 : 0)

            Spacer(minLength: 16)

            inputBar
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .opacity(introIn ? 1 : 0)
        }
        .padding(.vertical, 16)
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            HapticService.chipTap()
            submit(text)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accentGold.opacity(0.7))
                Text(text)
                    .font(.custom("Georgia", size: 16))
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textMuted.opacity(0.5))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(palette.surfaceElevated)
                    .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
            )
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(accentGold.opacity(0.18), lineWidth: 0.6))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask your own question…", text: $questionText, axis: .vertical)
                .font(.custom("Georgia", size: 16))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1...3)
                .focused($fieldFocused)
                .submitLabel(.send)
                .onSubmit { submit(questionText) }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

            Button {
                submit(questionText)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(canSend ? accentGold : palette.textMuted.opacity(0.3)))
            }
            .disabled(!canSend)
            .padding(.trailing, 5)
        }
        .background(
            Capsule(style: .continuous)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        )
        .overlay(Capsule(style: .continuous).stroke(accentGold.opacity(fieldFocused ? 0.5 : 0.2), lineWidth: 0.8))
        .animation(.easeOut(duration: 0.2), value: fieldFocused)
    }

    private var canSend: Bool {
        !questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Conversation (thinking / streaming / done)

    private var conversationView: some View {
        VStack(spacing: 0) {
            // The user's question — gold bubble, right-aligned (mirrors the real chat).
            HStack {
                Spacer(minLength: 40)
                Text(submittedQuestion)
                    .font(.custom("Georgia", size: 16))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(LinearGradient(colors: [accentGold, accentGold.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)

            // The answer — streams in below a sparkle avatar.
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(accentGold)
                            Text("Bible+")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .tracking(0.5)
                                .foregroundStyle(palette.textMuted)
                        }

                        if phase == .thinking {
                            TypingDotsView(contextLabel: "Reflecting")
                        } else {
                            Text(displayAnswer)
                                .font(.system(size: 18, weight: .medium, design: .serif))
                                .foregroundStyle(palette.textPrimary)
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                }
                .onChange(of: answer) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }

            // Footer + Continue (only once the answer is complete).
            if phase == .done {
                VStack(spacing: 14) {
                    Text("This is yours any time you need it — day or night.")
                        .font(.custom("Georgia-Italic", size: 14))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.textSecondary)
                        .padding(.horizontal, 36)

                    GoldButton(title: "Continue", showGlow: true) {
                        streamTask?.cancel()
                        onContinue()
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .offset(y: 12)))
            }
        }
    }

    private var displayAnswer: String { sanitize(answer) }

    // MARK: - Streaming

    private func submit(_ raw: String) {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, phase == .idle else { return }
        HapticService.commit()
        fieldFocused = false
        submittedQuestion = q
        questionText = ""
        answer = ""
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { phase = .thinking }

        streamTask = Task { @MainActor in
            do {
                try await AIService.streamCompletion(
                    messages: [
                        ("system", systemPrompt),
                        ("user", q),
                    ]
                ) { token in
                    if phase == .thinking {
                        withAnimation(.easeOut(duration: 0.25)) { phase = .streaming }
                    }
                    answer += token
                }
                try Task.checkCancellation()
                // Empty/whitespace-only result is a soft failure → fall back.
                if sanitize(answer).count < 12 {
                    answer = fallbackAnswer
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { phase = .done }
            } catch is CancellationError {
                return
            } catch {
                answer = fallbackAnswer
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { phase = .done }
            }
        }
    }

    /// Strips any stray card markup or follow-up line if the model ignores the
    /// plain-prose instruction — defensive so the onboarding answer always
    /// reads as clean prose.
    private func sanitize(_ s: String) -> String {
        var t = s.replacingOccurrences(of: #"\[/?[A-Za-z]+[^\]]*\]"#, with: "", options: .regularExpression)
        if let r = t.range(of: "|||") { t = String(t[..<r.lowerBound]) }
        t = t.replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var systemPrompt: String {
        let who = name.isEmpty ? "this person" : name
        let burdenLine: String = {
            let names = viewModel.selectedBurdens.map(\.displayName)
            guard !names.isEmpty else { return "" }
            return "They've just shared that they're carrying: \(names.joined(separator: ", ")). Keep that close to heart."
        }()
        return """
        You are the Bible+ companion — a warm, wise friend who knows Scripture deeply. \
        This is \(who)'s very first question, during onboarding. Make them feel deeply understood and glad they reached out.
        \(burdenLine)
        STRICT OUTPUT RULES:
        - Reply in 2 to 4 sentences of warm, plain, personal prose. Specific, not generic.
        - You MAY quote ONE short Scripture verse inline, followed by its reference (e.g. — Isaiah 41:10), only if it fits naturally.
        - NO markdown, NO headings, NO bullet points, NO bracketed tags of any kind, NO follow-up suggestions, NO meta-commentary.
        - Never open with a compliment like "Great question." Go straight to the heart of it.
        - End after the encouragement. Keep the whole reply to one short phone screen.
        """
    }

    // MARK: - Copy

    private var promptHeadline: String {
        name.isEmpty
            ? "Bring me what's really on your heart."
            : "Bring me what's on your heart, \(name)."
    }

    private var suggestions: [String] {
        var list: [String]
        switch topBurden {
        case .anxiety: list = ["Why do I feel anxious all the time?", "What does the Bible say about worry?"]
        case .grief: list = ["Where is God in my grief?", "How do I cope with losing someone I love?"]
        case .doubt: list = ["Is it okay to doubt God?", "How can I believe when I'm unsure?"]
        case .loneliness: list = ["Why do I feel so alone?", "Does God really see me?"]
        case .anger: list = ["How do I let go of my anger?", "How do I forgive someone who hurt me?"]
        case .temptation: list = ["Why do I keep falling into the same thing?", "How do I find strength to resist?"]
        case .health: list = ["Where is God when I'm afraid for my health?", "How do I find peace when I'm sick?"]
        case .financial: list = ["How do I stop worrying about money?", "Does God care about my finances?"]
        case .relationship: list = ["How do I forgive someone who hurt me?", "What does the Bible say about love?"]
        case .purpose: list = ["What is God's purpose for my life?", "How do I find my direction?"]
        default: list = ["Why does God feel so far away sometimes?", "How do I start reading the Bible?"]
        }
        list.append("How do I grow closer to God?")
        return Array(list.prefix(3))
    }

    private var fallbackAnswer: String {
        switch topBurden {
        case .anxiety:
            return "When anxiety rises, you don't have to carry it alone. God invites you to hand him every worry — not because they're small, but because he's strong enough to hold them. \"Cast all your anxiety on him because he cares for you.\" — 1 Peter 5:7"
        case .grief:
            return "Grief is love with nowhere to go, and God doesn't ask you to rush through it. He stays close in the ache, even when words run out. \"The Lord is close to the brokenhearted and saves those who are crushed in spirit.\" — Psalm 34:18"
        case .doubt:
            return "Doubt isn't the opposite of faith — it's often the doorway to a deeper one. You can bring God your most honest questions; he isn't threatened by them. \"I do believe; help my unbelief!\" — Mark 9:24"
        case .loneliness:
            return "Even when no one else is near, you are not unseen. God promises a presence that doesn't leave when the room empties out. \"I will never leave you nor forsake you.\" — Hebrews 13:5"
        case .anger:
            return "Anger usually points to something that mattered — a hurt, an injustice. God can hold it with you and slowly soften it into peace. \"In your anger do not sin; do not let the sun go down while you are still angry.\" — Ephesians 4:26"
        case .temptation:
            return "The pull you feel doesn't define you, and you're not facing it alone. God always makes a way through, even when it feels impossible. \"He will also provide a way out so that you can endure it.\" — 1 Corinthians 10:13"
        case .health:
            return "When your body — or someone you love — feels fragile, fear crowds in fast. God meets you there with a peace that doesn't depend on the diagnosis. \"God is our refuge and strength, an ever-present help in trouble.\" — Psalm 46:1"
        case .financial:
            return "Money worries have a way of stealing tomorrow's peace today. God invites you to trust him one day at a time — he has never run short. \"And my God will meet all your needs according to the riches of his glory.\" — Philippians 4:19"
        case .relationship:
            return "Relationships are where we're most loved and most easily wounded. God's kind of love is patient and steady, and he can teach it to you. \"Love is patient, love is kind.\" — 1 Corinthians 13:4"
        case .purpose:
            return "When the path feels unclear, you don't have to see the whole staircase — just the next step. God promises to guide you as you walk it. \"Your word is a lamp to my feet and a light to my path.\" — Psalm 119:105"
        default:
            return "Drawing near to God doesn't require having it all figured out — only a willingness to show up as you are. He always meets that with open arms. \"Come near to God and he will come near to you.\" — James 4:8"
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            RadialGradient(colors: [accentGold.opacity(0.10), .clear], center: .init(x: 0.5, y: 0.32), startRadius: 0, endRadius: 320)
                .ignoresSafeArea()
        }
    }
}

#Preview("Live Ask") {
    OnboardingLiveAskView(viewModel: OnboardingViewModel(
        modelContext: try! ModelContainer(for: UserProfile.self, configurations: .init(isStoredInMemoryOnly: true)).mainContext,
        storeKitService: StoreKitService()
    ))
    .environment(\.bpPalette, .light)
}
