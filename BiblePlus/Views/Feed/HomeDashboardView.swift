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
            // Tight, fixed gaps between sections; the verse card flexes to
            // absorb the leftover height. That keeps the cards large and the
            // gaps small while still adapting to every screen — the verse
            // card grows on tall phones and shrinks toward its minimum on
            // short ones, so nothing clips.
            VStack(spacing: 14) {
                headerSection

                streakRow
                    .padding(.top, 4)

                heroVerseCard

                quickActionsRow

                askCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 56)
            .frame(maxWidth: UIScreen.main.bounds.width)
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

    /// Soft warm canvas with a gentle gold-tan glow rising from the bottom.
    /// On the barely-warm white background this reads as a quiet pool of
    /// warmth behind the composer — premium, not harsh. Strength is kept
    /// low so it never reads as a heavy gold wash.
    private var fullPageBackground: some View {
        let tint = palette.accent
        let bg = palette.background
        let strength: CGFloat = colorScheme == .dark ? 0.20 : 0.22

        return ZStack {
            bg.ignoresSafeArea()

            LinearGradient(
                stops: [
                    .init(color: bg, location: 0.0),
                    .init(color: bg, location: 0.42),
                    .init(color: bg.blend(with: tint, amount: strength * 0.25), location: 0.60),
                    .init(color: bg.blend(with: tint, amount: strength * 0.55), location: 0.76),
                    .init(color: bg.blend(with: tint, amount: strength * 0.8), location: 0.90),
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
        .padding(.bottom, 18)
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
        HStack(spacing: 10) {
            wordmark
            Spacer()
            streakPill
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

    /// Streak count as a compact top-bar pill (Cal AI pattern). Tapping
    /// opens progress, same as the bare day-ring row below.
    private var streakPill: some View {
        Button {
            HapticService.lightImpact()
            onShowProgress()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accent)
                Text("\(vm.streakCount)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(palette.surfaceElevated)
                    .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
            )
            .overlay(Capsule().stroke(palette.border.opacity(0.35), lineWidth: 0.5))
        }
        .accessibilityLabel("\(vm.streakCount) day streak")
    }

    private var wordmark: some View {
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

    // MARK: - Curated Colorful Art
    //
    // The biblical-art catalog is mostly muted Tissot watercolors and B&W
    // Doré engravings, so auto-matching by verse kept landing on gloomy /
    // grayscale paintings that looked muddy on the clean white home. These
    // are hand-picked for vivid color. Each home surface (hero / read /
    // plan) gets a different one via a seed offset.
    private static let colorfulArtKeys = [
        "sermon_mount",     // Bloch — blue sky, scarlet robe
        "beatitudes",       // blue lake, golden hills
        "miraculous_catch", // orange tunic, blue water
        "magi_journey",     // gold cloaks, warm desert
    ]

    private func colorfulArt(seed: Int) -> UIImage? {
        let keys = Self.colorfulArtKeys
        guard !keys.isEmpty else { return nil }
        let key = keys[((seed % keys.count) + keys.count) % keys.count]
        return BiblicalImageService.rawImage(for: key)
    }

    private var dayOfYearSeed: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
    }

    /// Seed that advances every 6 hours so the matched painting rotates
    /// "every once in a while" through the day rather than staying fixed.
    private var rotatingArtSeed: Int {
        let cal = Calendar.current
        let day = cal.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let sixHourBucket = cal.component(.hour, from: Date()) / 6
        return day * 4 + sixHourBucket
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
            // Use a curated vivid painting that rotates through the day
            // (every ~6 hours) rather than auto-matching, which kept
            // landing on dark/grayscale art.
            let artImage = colorfulArt(seed: rotatingArtSeed)
            let bgColors = vm.currentBackground.gradientColors.map { Color(hex: $0) }
            let gradient = LinearGradient(
                colors: bgColors.isEmpty ? [palette.accent] : bgColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ZStack {
                // Cinematic scrim — a soft dark vignette plus a vertical
                // gradient so the centered verse stays legible over any
                // painting, no matter how light or busy the art is, while
                // the colour still reads through.
                LinearGradient(
                    colors: [.black.opacity(0.38), .black.opacity(0.30), .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                RadialGradient(
                    colors: [.black.opacity(0.34), .clear],
                    center: .center,
                    startRadius: 8,
                    endRadius: 220
                )

                VStack(spacing: 10) {
                    Spacer(minLength: 0)

                    Text("\u{201C}\(truncatedVerse(verse.text))\u{201D}")
                        .font(.custom("Georgia", size: 17))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .lineLimit(4)
                        .shadow(color: .black.opacity(0.55), radius: 7, y: 1)

                    OrnamentalDivider(color: .white, opacity: 0.2)

                    HStack(spacing: 6) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "C9A96E"))

                        Text(verse.reference)
                            .font(.custom("Georgia-Italic", size: 13))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .shadow(color: .black.opacity(0.5), radius: 5, y: 1)

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
                            Image(systemName: "sparkle")
                                .font(.system(size: 10, weight: .medium))
                            Text("Ask")
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
            .frame(minHeight: 150, maxHeight: .infinity)
            // The painting is a background so it fills the card without ever
            // driving its width — on tall screens an aspect-fill image as a
            // direct child would expand the card past its siblings.
            .background {
                if let artImage {
                    Image(uiImage: artImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    gradient
                        .overlay {
                            if let imageName = vm.currentBackground.imageName,
                               let uiImage = SanctuaryBackground.loadImage(named: imageName) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            }
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
            .onTapGesture {
                onDailyVerseTap()
                HapticService.lightImpact()
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(BPAnimation.spring.delay(0.16), value: appeared)
        }
    }

    // MARK: - Streak Row (bare, Cal AI style)
    //
    // No card background — the day rings sit directly on the canvas so the
    // verse + Read/Plan cards below read as floating above it, giving the
    // screen depth. The streak count lives in the top-bar pill.

    private var streakRow: some View {
        let activeDays = vm.activeDaysThisWeek
        let today = Calendar.current.component(.weekday, from: Date())

        return Button {
            onShowProgress()
            HapticService.selection()
        } label: {
            HStack(spacing: 0) {
            ForEach(Array(zip(dayLabels, dayWeekdays)), id: \.1) { label, weekday in
                let isActive = activeDays.contains(weekday)
                let isToday = weekday == today

                VStack(spacing: 7) {
                    Text(String(label.prefix(1)))
                        .font(.system(size: 11, weight: isToday ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isToday ? palette.accent : palette.textMuted)

                    ZStack {
                        if isActive {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [palette.accent, palette.accent.opacity(0.82)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)
                                .shadow(color: palette.accent.opacity(0.35), radius: 5, y: 2)
                                .scaleEffect(animateStreak ? 1 : 0)

                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .scaleEffect(animateStreak ? 1 : 0)
                        } else if isToday {
                            Circle()
                                .stroke(palette.accent, lineWidth: 2)
                                .frame(width: 36, height: 36)
                        } else {
                            Circle()
                                .stroke(palette.border.opacity(0.6), lineWidth: 1.5)
                                .frame(width: 36, height: 36)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(BPAnimation.spring.delay(0.08), value: appeared)
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

        // Curated vivid painting, offset so it differs from the hero + plan.
        let artImage = colorfulArt(seed: rotatingArtSeed + 1)

        return bookPageCard(
            eyebrow: eyebrow,
            numeral: numeral,
            fallbackIcon: "book.closed.fill",
            microLabel: microLabel,
            progress: progress,
            subtitle: subtitle,
            artImage: artImage
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

        // Curated vivid painting, offset so it differs from the hero + read.
        let artImage = colorfulArt(seed: rotatingArtSeed + 2)

        return bookPageCard(
            eyebrow: eyebrow,
            numeral: numeral,
            fallbackIcon: "calendar",
            microLabel: microLabel,
            progress: progress,
            subtitle: subtitle,
            artImage: artImage
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
        subtitle: LocalizedStringKey,
        artImage: UIImage?
    ) -> some View {
        VStack(spacing: 0) {
            // Painting header — matched art with the small-caps label set
            // over a soft bottom scrim. Postcard treatment: art on top,
            // crisp white info below.
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let artImage {
                        Image(uiImage: artImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        LinearGradient(
                            colors: [palette.accent.opacity(0.55), palette.accent.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 88)
                .clipped()

                // Bottom scrim for label legibility over any painting
                LinearGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 88)
                .allowsHitTesting(false)

                HStack(spacing: 6) {
                    Text(eyebrow)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 0)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }

            // White info area
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let numeral {
                        Text(numeral)
                            .font(.custom("Georgia", size: 26))
                            .foregroundStyle(palette.textPrimary)
                    } else {
                        Image(systemName: fallbackIcon)
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(palette.accent)
                    }

                    Text(microLabel)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(palette.textMuted)
                }
                .padding(.top, 10)

                Spacer(minLength: 8)

                progressHairline(progress: progress)
                    .padding(.top, 6)

                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.top, 7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.bottom, 11)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 184)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(palette.surfaceElevated)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            // Full warm hairline — crisp edge definition on the white canvas.
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(palette.border, lineWidth: 0.75)
                .allowsHitTesting(false)
        )
        .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
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