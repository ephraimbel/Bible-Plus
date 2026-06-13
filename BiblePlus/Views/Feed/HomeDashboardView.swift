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
    @Environment(\.modelContext) private var modelContext
    @State private var showReadingPlans = false
    @State private var showPathDetail = false
    @State private var appeared = false
    @State private var floatingOffset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var hasTriggeredHaptic = false
    @State private var dailyPathVM = DailyPathHomeViewModel()

    private var rubberBandScale: CGFloat {
        let progress = min(abs(dragOffset) / 120, 1.0)
        return 1.0 - (progress * 0.03)
    }

    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let dayWeekdays = [2, 3, 4, 5, 6, 7, 1]

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            // Fixed-height sections with a trailing spacer that lets any
            // leftover height collect quietly above the swipe prompt. No
            // GeometryReader / flexible art height — those caused the layout
            // to mis-size (zoom / shift) on cold launch.
            VStack(spacing: 0) {
                greetingHeader
                    .padding(.bottom, BPSpacing.sm)

                weeklyStreakRow

                heroVerseArtCard
                    .padding(.top, BPSpacing.sm)

                VStack(spacing: BPSpacing.sm) {
                    askCard
                    quickLinksRow
                }
                .padding(.top, BPSpacing.md)

                Spacer(minLength: BPSpacing.xs)
            }
            .padding(.horizontal, BPSpacing.lg)
            .padding(.bottom, BPSpacing.giant)
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
        .sheet(isPresented: $showPathDetail, onDismiss: {
            dailyPathVM.refresh(modelContext: modelContext, profile: vm.profile)
        }) {
            if let path = dailyPathVM.activePath {
                PathDetailView(path: path, homeVM: dailyPathVM, isPro: vm.profile.isPro)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(BPAnimation.spring) {
                    appeared = true
                }
            }
            dailyPathVM.refresh(modelContext: modelContext, profile: vm.profile)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showPlansFromWidget)) { _ in
            showReadingPlans = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .pathDeepLink)) { _ in
            dailyPathVM.refresh(modelContext: modelContext, profile: vm.profile)
            if dailyPathVM.activePath != nil {
                showPathDetail = true
            }
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
        VStack(spacing: BPSpacing.xxs) {
            Image(systemName: "chevron.up")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.accent.opacity(0.5))
                .offset(y: floatingOffset)

            Text("Swipe up to explore")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textMuted)
        }
        .padding(.bottom, BPSpacing.xl)
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

    /// Streak count as a compact top-bar pill (Cal AI pattern). Tapping
    /// opens progress, same as the day-ring row below.
    private var streakPill: some View {
        Button {
            HapticService.lightImpact()
            onShowProgress()
        } label: {
            HStack(spacing: BPSpacing.xxs) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accent)
                Text("\(vm.streakCount)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
            }
            .padding(.horizontal, BPSpacing.sm)
            .padding(.vertical, BPSpacing.xs)
            .background(
                Capsule()
                    .fill(palette.surfaceElevated)
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
            )
            .overlay(Capsule().stroke(palette.border.opacity(0.35), lineWidth: 0.5))
        }
        .accessibilityLabel("\(vm.streakCount) day streak")
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

    // MARK: - Header (Bible ✦ wordmark)

    private var greetingHeader: some View {
        HStack(alignment: .center, spacing: BPSpacing.sm) {
            bibleWordmark

            Spacer()

            streakPill
            profileAvatar
        }
        .padding(.top, BPSpacing.sm)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(BPAnimation.spring.delay(0.04), value: appeared)
    }

    /// The "Bible ✦" wordmark — the app's gold glowing-sparkle logo — anchored
    /// top-left of the home screen in place of the time-of-day greeting. Mirrors
    /// the SplashView lockup so the brand identity carries through.
    private var bibleWordmark: some View {
        // Warm gold, a touch brighter than the muted palette accent, for a
        // luminous-but-restrained logo glow.
        let gold = Color(red: 1.0, green: 0.84, blue: 0.4)
        return HStack(spacing: 3) {
            Text("Bible")
                .font(.system(size: 30, weight: .regular, design: .serif))
                .foregroundStyle(palette.textPrimary)

            Image(systemName: "sparkle")
                .font(.system(size: 22, weight: .medium))
                // Gradient sheen on the star itself — bright highlight up top
                // falling to the warm gold below.
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.92, blue: 0.6), gold],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                // Layered gold bloom — brighter and wider than before, but kept
                // mid-opacity so it glows without blowing out.
                .shadow(color: gold.opacity(0.7), radius: 4)
                .shadow(color: gold.opacity(0.55), radius: 9)
                .shadow(color: gold.opacity(0.3), radius: 16)
        }
        .accessibilityElement()
        .accessibilityLabel("Bible Plus")
    }

    // MARK: - Weekly Streak Row (calm, Claude-style)
    //
    // Seven quiet day markers — a small filled gold dot for a day you showed
    // up, a ring for today, a faint dot for the rest. No glossy circles or
    // shadows. Tapping anywhere opens the progress page.

    private var weeklyStreakRow: some View {
        let activeDays = vm.activeDaysThisWeek
        let today = Calendar.current.component(.weekday, from: Date())

        return Button {
            HapticService.lightImpact()
            onShowProgress()
        } label: {
            HStack(spacing: 0) {
                ForEach(dayWeekdays.indices, id: \.self) { index in
                    let weekday = dayWeekdays[index]
                    streakDayCell(
                        letter: String(dayLabels[index].prefix(1)),
                        isActive: activeDays.contains(weekday),
                        isToday: weekday == today,
                        index: index
                    )
                }
            }
            .padding(.vertical, BPSpacing.xxs)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(vm.streakCount) day streak. Opens progress.")
        .opacity(appeared ? 1 : 0)
        .animation(BPAnimation.spring.delay(0.14), value: appeared)
    }

    // One day in the weekly streak: a filled gold disc with a white check for a
    // completed day, a gold ring for today, and a quiet outlined disc for the
    // rest. Each pops in with a soft staggered scale on first appear.
    @ViewBuilder
    private func streakDayCell(letter: String, isActive: Bool, isToday: Bool, index: Int) -> some View {
        VStack(spacing: BPSpacing.xs) {
            Text(letter)
                .font(.system(size: 12, weight: isToday ? .bold : .medium, design: .rounded))
                .foregroundStyle(isToday ? palette.accent : palette.textMuted)

            ZStack {
                if isActive {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.accent.opacity(0.82)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: palette.accent.opacity(0.32), radius: 4, y: 2)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                } else if isToday {
                    Circle()
                        .fill(palette.accent.opacity(0.10))
                    Circle()
                        .strokeBorder(palette.accent, lineWidth: 1.8)
                } else {
                    Circle()
                        .fill(palette.surface)
                        .overlay(Circle().strokeBorder(palette.border.opacity(0.6), lineWidth: 1))
                }
            }
            .frame(width: 28, height: 28)
            .scaleEffect(appeared ? 1 : 0.5)
            .opacity(appeared ? 1 : 0)
            .animation(BPAnimation.spring.delay(0.18 + Double(index) * 0.04), value: appeared)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var heroVerseArtCard: some View {
        if let verse = vm.dailyVerse {
            let art = colorfulArt(seed: rotatingArtSeed)
            // The content VStack OWNS the card's fixed 256pt height and bottom-
            // aligns within it; the art + scrim render BEHIND as a .background so
            // they inherit that same clamped size. This is what keeps the verse,
            // reference and Ask button always fully on the card for any verse of
            // any length — the earlier ZStack approach let the full-bleed image's
            // .frame(maxHeight: .infinity) drive the internal layout taller than
            // 256, so the bottom-aligned content overflowed and clipped the
            // reference row.
            VStack(alignment: .leading, spacing: BPSpacing.sm) {
                // Eyebrow + verse, vertically centered in the space above the
                // footer so a SHORT verse sits mid-card instead of sinking to the
                // bottom; a long verse (up to 5 lines) simply fills the space.
                VStack(alignment: .leading, spacing: BPSpacing.sm) {
                    Text("VERSE FOR TODAY")
                        .font(.system(size: 10.5, weight: .semibold))
                        .tracking(2.6)
                        .foregroundStyle(.white.opacity(0.82))
                        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)

                    Text(verse.text)
                        .font(.system(size: 21, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.white)
                        .lineSpacing(6)
                        .lineLimit(5)
                        .minimumScaleFactor(0.4)
                        // Two shadows keep the verse crisp now that it can float
                        // over the lighter middle of the scrim: a soft glow plus
                        // a tight contour.
                        .shadow(color: .black.opacity(0.45), radius: 6, y: 1)
                        .shadow(color: .black.opacity(0.55), radius: 2, y: 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                HStack(spacing: BPSpacing.md) {
                    HStack(spacing: BPSpacing.xs) {
                        Rectangle()
                            .fill(Color(red: 1.0, green: 0.84, blue: 0.4).opacity(0.9))
                            .frame(width: 16, height: 1)
                        Text(verse.reference)
                            .font(.system(size: 13, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 4, y: 1)
                    }

                    Spacer()

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
                        HStack(spacing: BPSpacing.xxs) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 11, weight: .medium))
                            Text("Ask")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, BPSpacing.sm)
                        .padding(.vertical, BPSpacing.xs)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                        )
                        .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(BPSpacing.lg)
            .frame(maxWidth: .infinity, minHeight: 256, maxHeight: 256, alignment: .topLeading)
            .background {
                // Full-bleed biblical art — the whole card is the painting —
                // with a legibility scrim that deepens toward the bottom so the
                // verse + footer stay crisp over any painting.
                ZStack {
                    Group {
                        if let art {
                            Image(uiImage: art)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            LinearGradient(colors: [palette.accent.opacity(0.55), palette.accent.opacity(0.3)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                    }

                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.0), location: 0.0),
                            .init(color: .black.opacity(0.10), location: 0.34),
                            .init(color: .black.opacity(0.45), location: 0.60),
                            .init(color: .black.opacity(0.74), location: 0.82),
                            .init(color: .black.opacity(0.88), location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                }
                .allowsHitTesting(false)
            }
            // Shares the app card spec (radius / border / elevation); `filled:
            // false` keeps the full-bleed painting as the background.
            .bpCardSurface(palette, filled: false)
            .contentShape(Rectangle())
            .onTapGesture {
                onDailyVerseTap()
                HapticService.lightImpact()
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(BPAnimation.spring.delay(0.12), value: appeared)
        }
    }

    // MARK: - Quiet Quick Links (Bible / Plan as stacked editorial rows)

    private var quickLinksRow: some View {
        let reading = vm.continueReading
        let readContext = reading.map { "\($0.bookName) \($0.chapter)" }
        let readProgress: CGFloat = {
            guard let r = reading, r.totalChapters > 0 else { return 0 }
            return min(CGFloat(r.chapter) / CGFloat(r.totalChapters), 1)
        }()
        let plan = vm.activeReadingPlan
        let planContext = plan.map { "Day \($0.day) of \($0.total)" }
        let planProgress: CGFloat = {
            guard let p = plan, p.total > 0 else { return 0 }
            return min(CGFloat(p.day) / CGFloat(p.total), 1)
        }()

        return VStack(spacing: 0) {
            quickLink(
                eyebrow: "BIBLE",
                title: reading != nil ? "Continue reading" : "Open the Word",
                context: readContext,
                progress: reading != nil ? readProgress : nil
            ) {
                onContinueReading()
                HapticService.lightImpact()
            }

            // Subtle hairline separating the Bible row from the Plan row. Inset
            // a touch from the card edges so it reads as an intentional editorial
            // divider rather than a full-bleed rule.
            Rectangle()
                .fill(palette.border.opacity(0.55))
                .frame(height: 1)
                .padding(.vertical, BPSpacing.xxs)

            quickLink(
                eyebrow: "PLAN",
                title: plan != nil ? "Continue your plan" : "Reading plans",
                context: planContext,
                progress: plan != nil ? planProgress : nil
            ) {
                showReadingPlans = true
                HapticService.lightImpact()
            }
        }
        .padding(.horizontal, BPSpacing.md)
        // A small symmetric inset so the rows (and the PLAN progress bar) aren't
        // pressed against the card's top/bottom edges — lets the card breathe.
        .padding(.vertical, BPSpacing.xs)
        .bpCardSurface(palette)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
        .animation(BPAnimation.spring.delay(0.30), value: appeared)
    }

    /// One stacked row inside the combined Bible/Plan card: a gold eyebrow with
    /// the place you left off + arrow on the right, the action in serif, and a
    /// thin gold progress bar where progress is meaningful.
    private func quickLink(eyebrow: String, title: String, context: String?, progress: CGFloat?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: BPSpacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: BPSpacing.xs) {
                    Text(eyebrow)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(palette.accent.opacity(0.8))

                    Spacer()

                    if let context {
                        Text(context)
                            .font(.system(size: 12))
                            .foregroundStyle(palette.textMuted)
                            .lineLimit(1)
                    }

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.accent.opacity(0.6))
                }

                Text(title)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)

                if let progress {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(palette.accent.opacity(0.12))
                                .frame(height: 4)
                            Capsule()
                                .fill(palette.accent)
                                .frame(width: max(4, geo.size.width * progress), height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }
            .padding(.vertical, BPSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    /// Seed that advances every 6 hours so the matched painting rotates
    /// "every once in a while" through the day rather than staying fixed.
    private var rotatingArtSeed: Int {
        let cal = Calendar.current
        let day = cal.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let sixHourBucket = cal.component(.hour, from: Date()) / 6
        return day * 4 + sixHourBucket
    }

    // MARK: - Ask Card

    private var askCard: some View {
        DailyPathCTA(
            pathTitle: dailyPathVM.pathTitle,
            currentDay: dailyPathVM.currentDay,
            totalDays: dailyPathVM.totalDays,
            completedDays: dailyPathVM.completedDayNumbers,
            hasStarted: dailyPathVM.hasStarted,
            hasPath: dailyPathVM.activePath != nil,
            completedToday: dailyPathVM.completedToday,
            currentDayTitle: dailyPathVM.currentDayTitle,
            palette: palette
        ) {
            guard dailyPathVM.activePath != nil else { return }
            HapticService.lightImpact()
            showPathDetail = true
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(BPAnimation.spring.delay(0.32), value: appeared)
    }

}

// MARK: - Daily Path CTA
//
// The home-screen entry into the user's Daily Path. A calm, editorial card:
// a soft icon chip, a quiet eyebrow, the path name in serif, and a thin
// progress line once the journey is underway. No motion, no glow — stillness
// reads as premium. Path content gets the prominence because it's the engine
// for daily habit formation; AI gets contextual entry points inside the path
// session (Scripture step, Reflection step) instead of a home button.

private struct DailyPathCTA: View {
    let pathTitle: String
    let currentDay: Int
    let totalDays: Int
    let completedDays: [Int]
    let hasStarted: Bool
    let hasPath: Bool
    let completedToday: Bool
    let currentDayTitle: String
    let palette: BPColorPalette
    let onTap: () -> Void

    private var eyebrow: String {
        hasPath ? "DEVOTIONAL \(currentDay)" : "DAILY PATH"
    }

    private var title: String {
        if !hasPath { return "Start your journey" }
        return pathTitle.isEmpty ? "Your daily path" : pathTitle
    }

    private var subtitle: String {
        if !hasPath { return "A few quiet minutes each day" }
        if completedToday { return "Complete · back tomorrow" }
        return currentDayTitle.isEmpty ? "About 5 minutes" : currentDayTitle
    }

    private var progressFraction: CGFloat {
        guard totalDays > 0 else { return 0 }
        return min(CGFloat(completedDays.count) / CGFloat(totalDays), 1)
    }

    private var accessibilityLabel: String {
        if !hasPath { return "Begin your daily path" }
        if !hasStarted { return "Begin day one of \(pathTitle)" }
        return "Day \(currentDay) of \(pathTitle). \(completedDays.count) of \(totalDays) days complete."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: BPSpacing.sm) {
                VStack(alignment: .leading, spacing: BPSpacing.xxs) {
                    Text(eyebrow)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(palette.accent.opacity(0.85))

                    Text(title)
                        .font(BPFont.elegantHeadingMedium)
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 0)

                // Subtle corner indicator — matches the tiles' arrow; a
                // checkmark once today's reading is done.
                if completedToday {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette.accent)
                } else {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.accent.opacity(0.6))
                }
            }

            if hasPath && hasStarted {
                progressBar
                    .accessibilityHidden(true)
            }
        }
        .padding(BPSpacing.lg)
        // Primary-action treatment: a subtle gold trim around the whole card
        // marks the Daily Path as the day's main action — clean and elegant,
        // distinct from the neutral verse / Bible / Plan cards.
        .bpCardSurface(palette, borderColor: palette.accent.opacity(0.45), borderWidth: 1)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens your daily path")
        .accessibilityAddTraits(.isButton)
    }

    // Thin gold progress line — filled portion = days complete. Clean and flat,
    // matching the Plan tile's bar.
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.accent.opacity(0.14))
                    .frame(height: 4)
                Capsule()
                    .fill(palette.accent)
                    .frame(width: geo.size.width * progressFraction, height: 4)
            }
        }
        .frame(height: 4)
    }
}