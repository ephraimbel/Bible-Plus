import SwiftUI

struct HomeDashboardView: View {
    @Bindable var vm: FeedViewModel
    let soundscapeService: SoundscapeService
    let onEnterFeed: () -> Void
    let onShowProgress: () -> Void
    let onDailyVerseTap: () -> Void
    let onContinueReading: () -> Void
    let onOpenSanctuary: () -> Void

    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @State private var animateStreak = false
    @State private var showReadingPlans = false
    @State private var appeared = false
    @State private var floatingOffset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var hasTriggeredHaptic = false
    @State private var glowPulse = false

    private var rubberBandScale: CGFloat {
        let progress = min(abs(dragOffset) / 120, 1.0)
        return 1.0 - (progress * 0.03)
    }

    /// Card border opacity. Bumped in light mode because the warm cream
    /// background washes out a 30% gold stroke; dark mode reads cleanly at
    /// the lower value so borders never feel heavy on the dark surface.
    private var cardBorderOpacity: Double {
        colorScheme == .dark ? 0.30 : 0.55
    }

    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let dayWeekdays = [2, 3, 4, 5, 6, 7, 1]

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 16) {
                Spacer(minLength: 0)
                headerSection
                heroVerseCard
                streakCard
                quickActionsRow
                askCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 90)
            .offset(y: dragOffset)
            .scaleEffect(rubberBandScale, anchor: .bottom)

            // Pinned above tab bar
            swipeUpPrompt
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .background(fullPageBackground)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onChanged { value in
                    let translation = value.translation.height
                    guard translation < 0 else {
                        dragOffset = 0
                        return
                    }
                    let raw = -translation
                    let maxDrag: CGFloat = 120
                    dragOffset = -maxDrag * (1 - exp(-raw / maxDrag))

                    if raw > 100 && !hasTriggeredHaptic {
                        HapticService.notification(.success)
                        hasTriggeredHaptic = true
                    }
                }
                .onEnded { value in
                    let translation = -value.translation.height
                    if translation > 100 {
                        onEnterFeed()
                    }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        dragOffset = 0
                    }
                    hasTriggeredHaptic = false
                }
        )
        .sheet(isPresented: $showReadingPlans) {
            ReadingPlansView(isPro: vm.profile.isPro)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(BPAnimation.spring) {
                    appeared = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.6)) {
                    animateStreak = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showPlansFromWidget)) { _ in
            showReadingPlans = true
        }
    }

    // MARK: - Full Page Background

    private var fullPageBackground: some View {
        let tint = palette.accent
        let strength: CGFloat = colorScheme == .dark ? 0.20 : 0.34
        let bg = palette.background

        return ZStack {
            // Base background
            bg.ignoresSafeArea()

            // Bottom glow — mirrors the Ask page's top curve flipped, so the
            // fade shape and peak color match exactly but sit at the bottom
            // of the home page instead of the top.
            LinearGradient(
                stops: [
                    .init(color: bg, location: 0.0),
                    .init(color: bg, location: 0.35),
                    .init(color: bg.blend(with: tint, amount: strength * 0.15), location: 0.45),
                    .init(color: bg.blend(with: tint, amount: strength * 0.45), location: 0.60),
                    .init(color: bg.blend(with: tint, amount: strength * 0.7), location: 0.75),
                    .init(color: bg.blend(with: tint, amount: strength * 0.9), location: 0.88),
                    .init(color: bg.blend(with: tint, amount: strength), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Swipe Up Prompt

    private var swipeUpPrompt: some View {
        VStack(spacing: 4) {
            Image(systemName: "chevron.up")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.accent.opacity(0.5))
                .offset(y: floatingOffset)

            Text("Swipe up to explore")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textMuted)
        }
        .padding(.bottom, 56)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .opacity(appeared ? 1 : 0)
        .animation(BPAnimation.spring.delay(0.5), value: appeared)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                floatingOffset = -3
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            HStack(spacing: 2) {
                Text("Bible")
                    .font(.system(size: 28, weight: .light, design: .serif))
                    .foregroundStyle(palette.textPrimary)

                Image(systemName: "sparkle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.3))
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 4)
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 10)
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(glowPulse ? 0.9 : 0.5), radius: 20)
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(glowPulse ? 0.5 : 0.2), radius: 40)
            }

            Spacer()

            profileAvatar
        }
        .padding(.top, 12)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    private var profileAvatar: some View {
        Button {
            NotificationCenter.default.post(name: .switchToSettingsTab, object: nil)
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [palette.accent, palette.accent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)

                if let data = vm.profile.profileImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())
                } else {
                    Text(vm.profile.firstName.prefix(1).uppercased())
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Hero Verse Card

    @ViewBuilder
    /// Trims verse text to ~100 chars at a natural word boundary so it
    /// always fits cleanly on the card without SwiftUI truncation.
    private func truncatedVerse(_ text: String) -> String {
        let maxLength = 100
        guard text.count > maxLength else { return text }
        // Find the last space before the limit
        let prefix = text.prefix(maxLength)
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(text[text.startIndex..<lastSpace]) + "..."
        }
        return String(prefix) + "..."
    }

    @ViewBuilder
    private var heroVerseCard: some View {
        if let verse = vm.dailyVerse {
            let bgColors = vm.currentBackground.gradientColors.map { Color(hex: $0) }
            let gradient = LinearGradient(
                colors: bgColors.isEmpty ? [palette.accent] : bgColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ZStack {
                gradient
                    .overlay {
                        if let videoName = vm.currentBackground.videoFileName {
                            LoopingVideoPlayer(videoName: videoName, isPlaying: true)
                        } else if let imageName = vm.currentBackground.imageName,
                                  let uiImage = SanctuaryBackground.loadImage(named: imageName) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                    }
                    .clipped()

                Color.black.opacity(0.35)

                VStack(spacing: 10) {
                    Spacer(minLength: 0)

                    Text("\u{201C}\(truncatedVerse(verse.text))\u{201D}")
                        .font(.custom("Georgia", size: 16))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .lineLimit(4)

                    OrnamentalDivider(color: .white, opacity: 0.2)

                    HStack(spacing: 6) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "C9A96E"))

                        Text(verse.reference)
                            .font(.custom("Georgia-Italic", size: 13))
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    Button {
                        NotificationCenter.default.post(
                            name: .openAIWithContext,
                            object: nil,
                            userInfo: [
                                "context": "Walk me through this verse: \"\(verse.text)\" \u{2014} \(verse.reference)",
                                "title": verse.reference,
                            ]
                        )
                        HapticService.lightImpact()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 10, weight: .medium))
                            Text("Discuss")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.15))
                        )
                    }
                    .padding(.top, 4)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
            .onTapGesture {
                onDailyVerseTap()
                HapticService.lightImpact()
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(BPAnimation.spring.delay(0.08), value: appeared)
        }
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        let activeDays = vm.activeDaysThisWeek
        let today = Calendar.current.component(.weekday, from: Date())

        return VStack(spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [palette.accent, palette.accent.opacity(0.7)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(vm.streakCount >= 2 ? "\(vm.streakCount)-day streak" : "This Week")
                            .font(BPFont.elegantHeadingSmall)
                            .foregroundStyle(palette.textPrimary)

                        Text("Your activity")
                            .font(BPFont.elegantCaption)
                            .foregroundStyle(palette.textMuted)
                    }
                }

                Spacer()

                HStack(spacing: 3) {
                    Text("Details")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.accent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(palette.accent.opacity(0.6))
                }
            }

            Rectangle()
                .fill(palette.border.opacity(0.15))
                .frame(height: 0.5)

            HStack(spacing: 0) {
                ForEach(Array(zip(dayLabels, dayWeekdays)), id: \.1) { label, weekday in
                    let isActive = activeDays.contains(weekday)
                    let isToday = weekday == today

                    VStack(spacing: 8) {
                        Text(label)
                            .font(.system(size: 11, weight: isToday ? .bold : .medium, design: .rounded))
                            .foregroundStyle(isToday ? palette.accent : palette.textMuted)

                        ZStack {
                            if isActive {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [palette.accent, palette.accent.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 32, height: 32)
                                    .shadow(color: palette.accent.opacity(0.3), radius: 4, y: 2)
                                    .scaleEffect(animateStreak ? 1 : 0)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .scaleEffect(animateStreak ? 1 : 0)
                            } else if isToday {
                                Circle()
                                    .stroke(palette.accent, lineWidth: 2)
                                    .frame(width: 32, height: 32)

                                Circle()
                                    .fill(palette.accent.opacity(0.08))
                                    .frame(width: 32, height: 32)
                            } else {
                                Circle()
                                    .fill(palette.background)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(palette.border.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
        )
        .onTapGesture {
            onShowProgress()
            HapticService.selection()
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(BPAnimation.spring.delay(0.16), value: appeared)
    }

    // MARK: - Quick Actions Row (Editorial Book Pages)

    private var quickActionsRow: some View {
        HStack(spacing: 10) {
            readPageCard
            planPageCard
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(BPAnimation.spring.delay(0.24), value: appeared)
    }

    // MARK: - Read Page Card

    private var readPageCard: some View {
        let reading = vm.continueReading
        let eyebrow = (reading?.bookName ?? "Bible").uppercased()
        let numeral = reading.map { "\($0.chapter)" }
        let microLabel: LocalizedStringKey = reading != nil ? "chapter" : "open the word"
        let subtitle: LocalizedStringKey = reading != nil ? "Continue reading" : "Tap to open"
        let progress: CGFloat = {
            guard let r = reading, r.totalChapters > 0 else { return 0 }
            return min(CGFloat(r.chapter) / CGFloat(r.totalChapters), 1.0)
        }()

        return bookPageCard(
            eyebrow: eyebrow,
            numeral: numeral,
            fallbackIcon: "book.closed.fill",
            microLabel: microLabel,
            progress: progress,
            subtitle: subtitle
        )
        .onTapGesture {
            onContinueReading()
            HapticService.lightImpact()
        }
    }

    // MARK: - Plan Page Card

    private var planPageCard: some View {
        let plan = vm.activeReadingPlan
        let eyebrow = "PLAN"
        let numeral = plan.map { "\($0.day)" }
        let microLabel: LocalizedStringKey = plan.map { "of \($0.total) days" } ?? "start today"
        let subtitle: LocalizedStringKey = plan.map { LocalizedStringKey($0.name) } ?? "Begin a journey"
        let progress: CGFloat = {
            guard let p = plan, p.total > 0 else { return 0 }
            return min(CGFloat(p.day) / CGFloat(p.total), 1.0)
        }()

        return bookPageCard(
            eyebrow: eyebrow,
            numeral: numeral,
            fallbackIcon: "calendar",
            microLabel: microLabel,
            progress: progress,
            subtitle: subtitle
        )
        .onTapGesture {
            showReadingPlans = true
            HapticService.lightImpact()
        }
    }

    // MARK: - Book Page Card (shared shell)

    private func bookPageCard(
        eyebrow: String,
        numeral: String?,
        fallbackIcon: String,
        microLabel: LocalizedStringKey,
        progress: CGFloat,
        subtitle: LocalizedStringKey
    ) -> some View {
        VStack(spacing: 0) {
            // Eyebrow row — book/plan name in small caps + chevron
            HStack(spacing: 6) {
                Text(eyebrow)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(palette.accent.opacity(0.75))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(palette.accent.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // Hero numeral (or fallback icon)
            Group {
                if let numeral {
                    Text(numeral)
                        .font(.custom("Georgia", size: 44))
                        .foregroundStyle(palette.textPrimary)
                        .shadow(color: palette.accent.opacity(0.20), radius: 6, y: 1)
                        .shadow(color: palette.accent.opacity(0.08), radius: 14, y: 0)
                } else {
                    Image(systemName: fallbackIcon)
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    palette.accent,
                                    palette.accent.opacity(0.65)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: palette.accent.opacity(0.25), radius: 6, y: 1)
                        .shadow(color: palette.accent.opacity(0.10), radius: 14, y: 0)
                        .frame(height: 44)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)

            // Micro label under numeral
            Text(microLabel)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(palette.textMuted)
                .padding(.top, 0)

            Spacer(minLength: 6)

            // Ornamental divider
            OrnamentalDivider(color: palette.accent, opacity: 0.28)
                .padding(.horizontal, 24)

            // Animated progress bar
            progressHairline(progress: progress)
                .padding(.horizontal, 18)
                .padding(.top, 8)

            // Subtitle
            Text(subtitle)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 152)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
        )
        .overlay(
            // Quiet top-edge sheen — suggests light catching paper
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            palette.accent.opacity(colorScheme == .dark ? 0.18 : 0.22),
                            palette.accent.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: 0.6
                )
                .allowsHitTesting(false)
        )
    }

    // MARK: - Progress Hairline

    private func progressHairline(progress: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.border.opacity(0.22))
                    .frame(height: 2)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.accent.opacity(0.55),
                                palette.accent
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: appeared ? geo.size.width * progress : 0,
                        height: 2
                    )
                    .shadow(color: palette.accent.opacity(0.35), radius: 3, y: 0)
                    .animation(.easeOut(duration: 1.0).delay(0.5), value: appeared)
            }
        }
        .frame(height: 2)
    }

    // MARK: - Ask Card

    private var askCard: some View {
        InlineAskComposer(
            firstName: vm.profile.firstName,
            palette: palette
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(BPAnimation.spring.delay(0.32), value: appeared)
    }

}

// MARK: - Inline Ask Composer
//
// Real text input on the Home dashboard. Tapping it focuses the field and
// the keyboard pushes the entire dashboard up so the composer stays visible
// (SwiftUI's default keyboard avoidance handles this for free as long as
// the parent isn't pinned with .ignoresSafeArea(.keyboard)). Submitting
// posts `.openAIWithContext` — the same pipeline used by Feed "Discuss" and
// Plan deep links — which ContentView listens for and routes into a fresh
// streaming Conversation in the Ask tab.

private struct InlineAskComposer: View {
    let firstName: String
    let palette: BPColorPalette

    @Environment(\.colorScheme) private var colorScheme
    @State private var borderRotation: Double = 0

    private var cardBorderOpacity: Double {
        colorScheme == .dark ? 0.30 : 0.55
    }

    /// Personalized placeholder. Shows once focus enters/leaves.
    private var placeholder: String {
        let trimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "What\u{2019}s on your heart?"
        }
        return "Hey \(trimmed), what\u{2019}s on your heart?"
    }

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.3)

    var body: some View {
        HStack(spacing: 12) {
            // Golden sparkle icon
            Image(systemName: "sparkle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.95, blue: 0.6),
                            gold,
                            palette.accent
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: gold, radius: 4)
                .shadow(color: gold.opacity(0.5), radius: 10)

            Text("Ask anything about Scripture")
                .font(BPFont.elegantBody)
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.textMuted)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            // Solid card surface so the gradient border reads cleanly
            RoundedRectangle(cornerRadius: 22)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
        )
        .overlay(
            // Animated halo — an angular gold gradient that rotates slowly
            // around the border. The bright→dim→bright→dim→bright stops
            // create two visible "highlights" that sweep around the field
            // continuously, like a candle flickering on gold leaf.
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            palette.accent.opacity(0.95),
                            palette.accent.opacity(0.10),
                            palette.accent.opacity(0.95),
                            palette.accent.opacity(0.10),
                            palette.accent.opacity(0.95),
                        ]),
                        center: .center,
                        angle: .degrees(borderRotation)
                    ),
                    lineWidth: 1.6
                )
                .blur(radius: 0.4)
                .allowsHitTesting(false)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            HapticService.lightImpact()
            NotificationCenter.default.post(name: .switchToAskTab, object: nil)
        }
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                borderRotation = 360
            }
        }
    }
}