import AVFoundation
import SwiftUI

// MARK: - Shared Paywall Colors

enum PaywallColors {
    static let gold = Color(red: 0.79, green: 0.66, blue: 0.43)
    static let goldLight = Color(red: 1.0, green: 0.88, blue: 0.5)
    static let goldGradient = LinearGradient(
        colors: [goldLight, gold],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let green = Color(red: 0.4, green: 0.8, blue: 0.4)
}

// MARK: - Paywall Carousel (3 Scenes)

struct PaywallCarousel: View {
    @State private var currentPage = 0
    @State private var autoTimer: Timer?

    private let sceneCount = 3
    private let autoAdvanceInterval: TimeInterval = 5.5

    var body: some View {
        VStack(spacing: 12) {
            TabView(selection: $currentPage) {
                FeedMockupScreen()
                    .tag(0)
                ChatMockupScreen()
                    .tag(1)
                BibleMockupScreen()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 310)

            // Page dots + labels
            HStack(spacing: 20) {
                pageDot(index: 0, label: "Daily Feed")
                pageDot(index: 1, label: "AI Chat")
                pageDot(index: 2, label: "Bible")
            }
        }
        .onAppear { startAutoAdvance() }
        .onDisappear { autoTimer?.invalidate() }
        .onChange(of: currentPage) { _, _ in
            startAutoAdvance()
        }
    }

    private func pageDot(index: Int, label: String) -> some View {
        let isActive = currentPage == index
        return VStack(spacing: 4) {
            Circle()
                .fill(isActive ? PaywallColors.gold : Color(hex: "B8B0A0").opacity(0.4))
                .frame(width: isActive ? 8 : 6, height: isActive ? 8 : 6)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)

            Text(label)
                .font(.system(size: 10, weight: isActive ? .semibold : .regular, design: .rounded))
                .foregroundStyle(isActive ? PaywallColors.gold : Color(hex: "B8B0A0"))
                .animation(.easeOut(duration: 0.2), value: isActive)
        }
    }

    private func startAutoAdvance() {
        autoTimer?.invalidate()
        autoTimer = Timer.scheduledTimer(withTimeInterval: autoAdvanceInterval, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                currentPage = (currentPage + 1) % sceneCount
            }
        }
    }
}

// MARK: - Shared Phone Frame

struct PhoneFrame<Content: View>: View {
    let screenBG: Color
    @ViewBuilder let content: Content

    private let phoneW: CGFloat = 148
    private let phoneH: CGFloat = 300
    private let bezel: CGFloat = 3
    private let outerRadius: CGFloat = 36
    private let innerRadius: CGFloat = 33

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: outerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.22, blue: 0.21),
                            Color(red: 0.12, green: 0.12, blue: 0.11),
                            Color(red: 0.16, green: 0.16, blue: 0.15),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: phoneW, height: phoneH)
                .overlay(
                    RoundedRectangle(cornerRadius: outerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.30),
                                    .white.opacity(0.08),
                                    .white.opacity(0.15),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.75
                        )
                )
                .shadow(color: Color(hex: "C9A96E").opacity(0.18), radius: 20, y: 8)
                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)

            RoundedRectangle(cornerRadius: innerRadius)
                .fill(screenBG)
                .frame(width: phoneW - bezel * 2, height: phoneH - bezel * 2)

            VStack(spacing: 0) {
                content
            }
            .frame(width: phoneW - bezel * 2, height: phoneH - bezel * 2)
            .clipShape(RoundedRectangle(cornerRadius: innerRadius))
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.black)
                    .frame(width: 44, height: 12)
                    .padding(.top, 5)
            }

            RoundedRectangle(cornerRadius: 1)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.15), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1.5, height: 28)
                .offset(x: phoneW / 2 + 0.25, y: -30)
        }
    }
}

// MARK: - Scene 1: AI Chat Mockup (matches real app)

struct ChatMockupScreen: View {
    @State private var question: String = ""
    @State private var answer: String = ""
    @State private var imageName: String = ""
    @State private var revealedChars = 0
    @State private var userOpacity: Double = 0
    @State private var aiOpacity: Double = 0
    @State private var dotsOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var cursorOpacity: Double = 0
    @State private var imageOpacity: Double = 0
    @State private var imageZoom: CGFloat = 1.0
    @State private var imageShimmer: CGFloat = -1.0
    @State private var exchangeIndex = 0
    @State private var hasStarted = false
    /// Single owning task for the animation chain. Holding it in @State lets
    /// us cancel cleanly on disappear and guarantees there's never more than
    /// one cycle running at a time — eliminates the race that DispatchQueue
    /// chains used to suffer from when the carousel flipped pages mid-cycle.
    @State private var animationTask: Task<Void, Never>? = nil

    private let bg = Color(hex: "FAF8F4")
    private let textPrimary = Color(hex: "2D2D2D")
    private let textMuted = Color(hex: "B8B0A0")
    private let surfaceEl = Color.white
    private let border = Color(hex: "E0D8C8")
    private let accent = Color(hex: "C9A96E")
    private let gradientTint = Color(red: 0.65, green: 0.48, blue: 0.25)

    /// Each exchange pairs a user question with a streaming AI answer and a
    /// biblical art asset that fades in as a contextual hero card behind the
    /// AI response — the same way a real conversation in the Bible+ app
    /// surfaces relevant imagery alongside Scripture. The list is wide
    /// enough that the cycle never feels like a loop within a single
    /// onboarding session, and each answer is written to read like a
    /// theologically-literate companion, not a quote machine.
    private static let exchanges: [(q: String, a: String, image: String)] = [
        ("Tell me about David and Goliath",
         "One stone, one God who fights for the small. The shepherd boy beat the giant before he ever picked up a sling.",
         "biblical_david_goliath"),
        ("What is the Sermon on the Mount?",
         "Jesus's manifesto. Blessed are the meek, the merciful, the pure in heart — every empire's logic, overturned in eight lines.",
         "biblical_sermon_mount"),
        ("How did Jesus calm the storm?",
         "Three words on the Sea of Galilee — \u{201C}Peace, be still\u{201D} — and the wind obeyed the carpenter.",
         "biblical_jesus_calms_storm"),
        ("Who were the Magi?",
         "Persian astronomer-priests. They followed a star west for months — the first Gentiles to kneel before Christ.",
         "biblical_magi_journey"),
        ("Tell me about Daniel in the lions\u{2019} den",
         "A Jewish exile who out-prayed an empire. Babylon's lions wouldn't touch the man who knelt three times a day.",
         "biblical_daniel_lions"),
        ("What about the loaves and fishes?",
         "Five loaves, two fish, five thousand fed. Twelve baskets left — one for every tribe of Israel.",
         "biblical_loaves_fishes"),
        ("Tell me about the prodigal son",
         "Luke 15. The Father runs to meet him. That one detail rewrites every religion humans have ever invented.",
         "biblical_prodigal_son"),
        ("Who was Noah?",
         "Genesis 6. Forty days of judgment, then a covenant: never again. The rainbow is older than the cross.",
         "biblical_noah_ark"),
    ]

    var body: some View {
        PhoneFrame(screenBG: bg) {
            ZStack {
                topGoldGradient.allowsHitTesting(false)

                VStack(spacing: 0) {
                    // Chat messages area — stable layout. Every element
                    // reserves its slot up front so opacity transitions never
                    // shove other content around. This is the difference
                    // between a polished mock and a janky one.
                    VStack(alignment: .leading, spacing: 6) {
                        Spacer(minLength: 0)

                        // User bubble — right-aligned, gold gradient, real bubble shape
                        HStack {
                            Spacer(minLength: 20)
                            Text(question.isEmpty ? " " : question)
                                .font(.system(size: 7.5, weight: .regular, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 10,
                                        bottomLeadingRadius: 10,
                                        bottomTrailingRadius: 10,
                                        topTrailingRadius: 3
                                    )
                                    .fill(
                                        LinearGradient(
                                            colors: [accent, accent.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: accent.opacity(0.2), radius: 4, y: 2)
                                )
                        }
                        .opacity(userOpacity)
                        .offset(y: userOpacity == 1 ? 0 : 4)

                        // AI response — sparkle avatar + hero card + body
                        HStack(alignment: .top, spacing: 4) {
                            // Sparkle avatar matching real app
                            ZStack {
                                Circle()
                                    .fill(accent.opacity(0.08))
                                    .frame(width: 18, height: 18)
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [accent.opacity(0.18), accent.opacity(0.06)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 15, height: 15)
                                Image(systemName: "sparkle")
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(red: 1.0, green: 0.84, blue: 0.3), accent],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                            .padding(.top, 1)

                            VStack(alignment: .leading, spacing: 4) {
                                // Hero card always reserves its slot — opacity
                                // alone fades it in, so the streaming text
                                // beneath never jumps when the image arrives.
                                biblicalHeroCard
                                    .opacity(imageOpacity)

                                // Dots and streaming text share the same
                                // vertical slot via ZStack so the layout is
                                // identical whether dots or text are visible.
                                ZStack(alignment: .topLeading) {
                                    MockTypingDots(lightMode: true)
                                        .opacity(dotsOpacity)

                                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                                        Text(revealedChars > 0 ? String(answer.prefix(revealedChars)) : " ")
                                            .font(.system(size: 7, weight: .regular, design: .serif))
                                            .foregroundStyle(textPrimary)
                                            .lineSpacing(2.5)

                                        // Blinking cursor while streaming
                                        RoundedRectangle(cornerRadius: 0.5)
                                            .fill(accent)
                                            .frame(width: 1.5, height: 8)
                                            .opacity(cursorOpacity)
                                    }
                                    .opacity(textOpacity)
                                }
                                .frame(minHeight: 14, alignment: .topLeading)
                            }

                            Spacer(minLength: 10)
                        }
                        .opacity(aiOpacity)
                        .offset(y: aiOpacity == 1 ? 0 : 4)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                    // Input bar — matches real app style
                    VStack(spacing: 0) {
                        border.opacity(0.3).frame(height: 0.5)
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(surfaceEl)
                                .frame(height: 22)
                                .overlay(alignment: .leading) {
                                    Text("Ask anything about Scripture...")
                                        .font(.system(size: 6.5, weight: .regular, design: .rounded))
                                        .foregroundStyle(textMuted)
                                        .padding(.leading, 8)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(border.opacity(0.3), lineWidth: 0.5)
                                )
                                .shadow(color: .black.opacity(0.03), radius: 2, y: 1)

                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [accent, accent.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 20, height: 20)
                                    .shadow(color: accent.opacity(0.2), radius: 2, y: 1)
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(bg.opacity(0.95))
                    }
                }
            }
        }
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            // Pick a random starting point so opening the paywall twice in
            // a session doesn't always show the same first exchange.
            exchangeIndex = Int.random(in: 0..<Self.exchanges.count)
            beginCycle()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
            hasStarted = false
        }
    }

    /// Contextual biblical hero card — fades in beneath the typing dots
    /// before the AI streams its answer, the way the real Bible+ chat would
    /// surface relevant imagery for the verse or story being discussed.
    /// Layered: art, dark scrim for legibility, gold border + glow, plus a
    /// shimmer sweep that crosses the card while it appears.
    private var biblicalHeroCard: some View {
        let cardW: CGFloat = 100
        let cardH: CGFloat = 42
        return ZStack {
            // The art itself, scaled fill, with a slow Ken Burns zoom that
            // animates over the entire visible window so it always feels
            // like the image is breathing rather than frozen.
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaleEffect(imageZoom)
                .frame(width: cardW, height: cardH)
                .clipped()

            // Subtle bottom-darken so any future caption would read.
            LinearGradient(
                colors: [.clear, .black.opacity(0.18)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Gold shimmer sweep — diagonal highlight strip that travels
            // across the card during the reveal, like light catching gilt.
            GeometryReader { geo in
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white.opacity(0.32), location: 0.5),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: geo.size.width * 0.55)
                .offset(x: imageShimmer * geo.size.width)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
            }
            .clipped()
        }
        .frame(width: cardW, height: cardH)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    LinearGradient(
                        colors: [accent.opacity(0.6), accent.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.6
                )
        )
        .shadow(color: accent.opacity(0.25), radius: 6, y: 2)
        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
    }

    private var topGoldGradient: some View {
        let s: CGFloat = 0.28
        return LinearGradient(
            stops: [
                .init(color: bg.blend(with: gradientTint, amount: s), location: 0.0),
                .init(color: bg.blend(with: gradientTint, amount: s * 0.9), location: 0.12),
                .init(color: bg.blend(with: gradientTint, amount: s * 0.7), location: 0.25),
                .init(color: bg.blend(with: gradientTint, amount: s * 0.45), location: 0.40),
                .init(color: bg.blend(with: gradientTint, amount: s * 0.15), location: 0.55),
                .init(color: bg, location: 0.65),
                .init(color: bg, location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Animation cycle

    /// Kicks off the never-ending choreography. The whole sequence lives
    /// inside a single `Task` so cancellation is atomic and there's only
    /// ever one cycle in flight at a time — no more racing dispatch chains
    /// that fight each other when the carousel page changes.
    private func beginCycle() {
        animationTask?.cancel()
        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                await runOneExchange()
            }
        }
    }

    @MainActor
    private func runOneExchange() async {
        let ex = Self.exchanges[exchangeIndex % Self.exchanges.count]

        // Reset all state for the fresh exchange.
        question = ex.q
        answer = ex.a
        imageName = ex.image
        revealedChars = 0
        userOpacity = 0
        aiOpacity = 0
        dotsOpacity = 0
        textOpacity = 0
        cursorOpacity = 0
        imageOpacity = 0
        imageZoom = 1.0
        imageShimmer = -1.0

        // Brief beat so the previous exchange's fade-out has time to settle
        // before the next one starts populating.
        guard await sleep(0.45) else { return }

        // 1. User message slides in
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            userOpacity = 1
        }
        guard await sleep(0.85) else { return }

        // 2. AI row appears with typing dots
        withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
            aiOpacity = 1
            dotsOpacity = 1
        }
        guard await sleep(0.95) else { return }

        // 3. Dots fade out, hero card fades in with Ken Burns zoom +
        //    shimmer. Image space was already reserved up front, so this
        //    fade-in produces zero layout shift.
        withAnimation(.easeOut(duration: 0.22)) {
            dotsOpacity = 0
        }
        withAnimation(.easeOut(duration: 0.6)) {
            imageOpacity = 1
        }
        withAnimation(.easeInOut(duration: 6.5)) {
            imageZoom = 1.10
        }
        withAnimation(.easeInOut(duration: 1.15)) {
            imageShimmer = 1.0
        }
        guard await sleep(0.7) else { return }

        // 4. Text streams in beneath the image with a blinking cursor.
        textOpacity = 1
        cursorOpacity = 1

        let total = answer.count
        let perChar: UInt64 = 18_000_000 // 18ms per char
        for i in 1...total {
            try? await Task.sleep(nanoseconds: perChar)
            if Task.isCancelled { return }
            revealedChars = i
        }

        // 5. Hide the cursor and let the answer breathe before the cycle
        //    rolls over.
        guard await sleep(0.15) else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            cursorOpacity = 0
        }
        guard await sleep(2.4) else { return }

        // 6. Fade everything out together.
        withAnimation(.easeOut(duration: 0.55)) {
            userOpacity = 0
            aiOpacity = 0
            textOpacity = 0
            imageOpacity = 0
        }
        guard await sleep(0.7) else { return }

        // Advance to the next exchange. The `while` loop in `beginCycle`
        // immediately calls `runOneExchange` again with the new index.
        exchangeIndex = (exchangeIndex + 1) % Self.exchanges.count
    }

    /// Cancellation-aware sleep helper. Returns false if the task was
    /// cancelled during (or before) the sleep so the caller can early-exit.
    private func sleep(_ seconds: Double) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}

// MARK: - Scene 2: Bible Reader Mockup (Verse Cascade)

struct BibleMockupScreen: View {
    @State private var visibleCount = 0
    @State private var cycleToken = 0
    @State private var hasStarted = false

    private let parchment = Color(hex: "FAF8F4")
    private let textDark = Color(hex: "2D2D2D")
    private let accent = Color(hex: "C9A96E")

    private let verses: [(Int, String)] = [
        (1, "The Lord is my shepherd; I shall not want."),
        (2, "He maketh me to lie down in green pastures: he leadeth me beside the still waters."),
        (3, "He restoreth my soul: he leadeth me in the paths of righteousness for his name\u{2019}s sake."),
        (4, "Yea, though I walk through the valley of the shadow of death, I will fear no evil: for thou art with me; thy rod and thy staff they comfort me."),
        (5, "Thou preparest a table before me in the presence of mine enemies."),
    ]

    var body: some View {
        PhoneFrame(screenBG: parchment) {
            HStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(textDark.opacity(0.35))
                Spacer()
                Text("Psalm 23")
                    .font(.system(size: 9, weight: .semibold, design: .serif))
                    .foregroundStyle(textDark)
                Spacer()
                Image(systemName: "textformat.size")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(textDark.opacity(0.35))
            }
            .padding(.horizontal, 10)
            .padding(.top, 22)
            .padding(.bottom, 4)

            Text("Psalm 23")
                .font(.system(size: 11, weight: .semibold, design: .serif))
                .foregroundStyle(textDark)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 2)

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(accent.opacity(0.4))
                        .frame(width: 2, height: 2)
                }
            }
            .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(verses.enumerated()), id: \.element.0) { index, verse in
                    let isVisible = index < visibleCount
                    verseRow(number: verse.0, text: verse.1)
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: isVisible ? 0 : 4)
                        .animation(
                            .easeOut(duration: 0.4).delay(Double(index) * 0.08),
                            value: visibleCount
                        )
                }
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 0)
        }
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            runCascade()
        }
    }

    private func verseRow(number: Int, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(number)")
                .font(.system(size: 5, weight: .bold, design: .serif))
                .foregroundStyle(accent)
                .baselineOffset(3)

            Text("\u{2009}\(text) ")
                .font(.system(size: 7, weight: .regular, design: .serif))
                .foregroundStyle(textDark.opacity(0.85))
                .lineSpacing(2.5)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 3)
    }

    private func runCascade() {
        cycleToken += 1
        let token = cycleToken
        visibleCount = 0

        let stagger: TimeInterval = 0.5
        for i in 1...verses.count {
            after(stagger * Double(i)) {
                guard cycleToken == token else { return }
                visibleCount = i
            }
        }

        let holdStart = stagger * Double(verses.count) + 2.5

        after(holdStart) {
            guard cycleToken == token else { return }
            visibleCount = 0
        }

        after(holdStart + 0.8) {
            guard cycleToken == token else { return }
            runCascade()
        }
    }

    private func after(_ delay: TimeInterval, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }
}

// MARK: - Scene 3: Daily Feed Mockup

struct FeedMockupScreen: View {
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    @State private var appeared = false
    @State private var heartPop = false

    private let screenW: CGFloat = 142
    private let screenH: CGFloat = 294

    private let waterGradient: [Color] = [
        Color(hex: "1A5276"),
        Color(hex: "2980B9"),
        Color(hex: "5DADE2"),
    ]

    var body: some View {
        PhoneFrame(screenBG: Color(hex: "1A5276")) {
            ZStack {
                LinearGradient(
                    colors: waterGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: screenW, height: screenH)

                if let player {
                    PersistentPlayerLayer(player: player)
                        .frame(width: screenW, height: screenH)
                        .clipped()
                }

                Color.black.opacity(0.06)
                    .frame(width: screenW, height: screenH)

                RadialGradient(
                    colors: [.clear, .black.opacity(0.18)],
                    center: .center,
                    startRadius: 80,
                    endRadius: 200
                )
                .frame(width: screenW, height: screenH)

                VStack(spacing: 0) {
                    Spacer(minLength: 30)

                    Text("VERSE OF THE DAY")
                        .font(.system(size: 5.5, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                        .padding(.bottom, 12)

                    Text("Be still, and know\nthat I am God.")
                        .font(.system(size: 12, weight: .regular, design: .serif))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .shadow(color: .black.opacity(0.5), radius: 4, y: 1)

                    HStack(spacing: 4) {
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 12, height: 0.5)
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 3))
                            .foregroundStyle(.white.opacity(0.35))
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 12, height: 0.5)
                    }
                    .padding(.top, 10)

                    Text("\u{2014} Psalm 46:10")
                        .font(.system(size: 7, weight: .medium, design: .serif))
                        .foregroundStyle(.white.opacity(0.75))
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .padding(.top, 5)

                    Spacer(minLength: 20)
                }
                .frame(width: screenW, height: screenH)
                .padding(.horizontal, 14)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 6)

                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 14) {
                        feedIcon("heart.fill", tinted: heartPop)
                        feedIcon("square.and.arrow.up", tinted: false)
                        feedIcon("pin", tinted: false)
                        feedIcon("bubble.left.and.bubble.right", tinted: false)
                    }
                    Spacer()
                }
                .frame(width: screenW, height: screenH, alignment: .trailing)
                .padding(.trailing, 8)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            if player == nil {
                setupPlayer()
            } else {
                player?.play()
            }

            if !appeared {
                withAnimation(.easeOut(duration: 0.5).delay(0.2)) { appeared = true }
                heartLoop()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            player?.play()
        }
    }

    private func setupPlayer() {
        guard let url = Bundle.main.url(forResource: "water-ripples", withExtension: "mp4") else { return }
        let asset = AVAsset(url: url)
        let template = AVPlayerItem(asset: asset)
        let qp = AVQueuePlayer()
        qp.isMuted = true
        looper = AVPlayerLooper(player: qp, templateItem: template)
        player = qp
        qp.play()
    }

    private func feedIcon(_ name: String, tinted: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(tinted ? PaywallColors.gold : .white.opacity(0.85))
            .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
            .scaleEffect(tinted && name == "heart.fill" ? 1.2 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: tinted)
    }

    private func heartLoop() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { heartPop = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation { heartPop = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            heartLoop()
        }
    }
}

// MARK: - Typing Dots for Mockup

struct MockTypingDots: View {
    var lightMode: Bool = false
    @State private var dotScale: [CGFloat] = [0.5, 0.5, 0.5]

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(lightMode ? Color(hex: "B8B0A0") : .white.opacity(0.35))
                    .frame(width: 3.5, height: 3.5)
                    .scaleEffect(dotScale[i])
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .onAppear {
            for i in 0..<3 {
                withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(Double(i) * 0.15)) {
                    dotScale[i] = 1.0
                }
            }
        }
    }
}

// MARK: - Persistent Player Layer

struct PersistentPlayerLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PersistentPlayerLayerView {
        let view = PersistentPlayerLayerView()
        view.attach(player)
        player.play()
        return view
    }

    func updateUIView(_ uiView: PersistentPlayerLayerView, context: Context) {
        uiView.attach(player)
        player.play()
    }

    static func dismantleUIView(_ uiView: PersistentPlayerLayerView, coordinator: ()) {
        uiView.detach()
    }
}

final class PersistentPlayerLayerView: UIView {
    private var playerLayer: AVPlayerLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func attach(_ player: AVPlayer) {
        if playerLayer?.player === player { return }
        playerLayer?.removeFromSuperlayer()
        let l = AVPlayerLayer(player: player)
        l.videoGravity = .resizeAspectFill
        l.frame = bounds
        layer.addSublayer(l)
        playerLayer = l
    }

    func detach() {
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
}
