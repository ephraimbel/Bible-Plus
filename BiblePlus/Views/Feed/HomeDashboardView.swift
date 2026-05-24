import SwiftUI

// MARK: - Home Dashboard (Haven-inspired, chat-first)
//
// One main page, composer pinned at the bottom. Layout draws on Haven
// Bible Chat's organization: hero verse on a painterly background, a
// "Today" card combining streak + CTA, a 2x2 topic grid of conversation
// starters, and an "Ask anything..." composer at the very bottom.
//
// Composition (top to bottom):
//   1. Top bar — Bible glyph (left) · wordmark (center) · profile+streak pill (right)
//   2. ScrollView containing:
//      - Daily Verse card (large hero with sanctuary-bg + dark overlay)
//      - Today card (streak header · 7 day-of-week circles · CTA)
//      - Topic grid (4 gradient cards → AI conversation starters)
//   3. Composer (.safeAreaInset bottom) — TextField + send button
//
// Every infinite-repeat animation that was on the previous dashboard
// (glow pulse, floating chevron, rotating composer halo) is gone. The
// only motion left is one-shot appearance + a focus-state border tween.
struct HomeDashboardView: View {
    @Bindable var vm: FeedViewModel
    let soundscapeService: SoundscapeService

    // Callbacks preserved for API compat with FeedContentView. Feed entry
    // and Continue Reading are no longer surfaced on home — Bible Reader
    // is reached via the top-bar book glyph, the Feed is shelved.
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
    @State private var composerText: String = ""
    @FocusState private var composerFocused: Bool

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    private let dayWeekdays = [1, 2, 3, 4, 5, 6, 7]

    // MARK: - Body

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ScrollView {
                    VStack(spacing: 14) {
                        dailyVerseCard
                        todayCard
                        actionGrid
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 8) {
            // Composer pinned at the bottom safe area. SwiftUI's default
            // keyboard avoidance lifts this inset with the keyboard so
            // the composer stays visible while typing.
            homeComposer
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
        }
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
        .onTapGesture {
            // Tap outside the composer dismisses the keyboard.
            if composerFocused {
                composerFocused = false
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            bibleGlyph
            Spacer()
            wordmark
            Spacer()
            profileStreakPill
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    private var bibleGlyph: some View {
        Button {
            HapticService.lightImpact()
            NotificationCenter.default.post(name: .switchToBibleTab, object: nil)
        } label: {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.accent)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(palette.surfaceElevated)
                        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
                )
                .overlay(
                    Circle()
                        .stroke(palette.border.opacity(0.35), lineWidth: 0.5)
                )
        }
        .accessibilityLabel("Open Bible Reader")
    }

    private var wordmark: some View {
        HStack(spacing: 2) {
            Text("Bible")
                .font(.system(size: 22, weight: .light, design: .serif))
                .foregroundStyle(palette.textPrimary)

            Image(systemName: "sparkle")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.3))
                .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 3)
                .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.4), radius: 8)
        }
    }

    /// Avatar + streak fused into a single pill. Opens the main menu
    /// drawer (History · Saved · Progress · Plans · Sanctuary · Settings) —
    /// the replacement for the old bottom tab bar.
    private var profileStreakPill: some View {
        Button {
            HapticService.lightImpact()
            NotificationCenter.default.post(name: .openMainMenu, object: nil)
        } label: {
            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.accent.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)

                    if let data = vm.profile.profileImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                    } else {
                        Text(vm.profile.firstName.prefix(1).uppercased())
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }

                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(palette.accent)
                    Text("\(vm.streakCount)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                }
            }
            .padding(.leading, 4)
            .padding(.trailing, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(palette.surfaceElevated)
                    .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
            )
            .overlay(
                Capsule()
                    .stroke(palette.border.opacity(0.35), lineWidth: 0.5)
            )
        }
        .accessibilityLabel("Open menu, \(vm.streakCount) day streak")
    }

    // MARK: - Daily Verse Card

    @ViewBuilder
    private var dailyVerseCard: some View {
        if let verse = vm.dailyVerse {
            let bgColors = vm.currentBackground.gradientColors.map { Color(hex: $0) }
            let gradient = LinearGradient(
                colors: bgColors.isEmpty ? [palette.accent, palette.accent.opacity(0.6)] : bgColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Button {
                onDailyVerseTap()
                HapticService.lightImpact()
            } label: {
                ZStack {
                    gradient
                        .overlay {
                            if let imageName = vm.currentBackground.imageName,
                               let uiImage = SanctuaryBackground.loadImage(named: imageName) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            }
                        }
                        .clipped()

                    // Dark scrim so white serif type reads cleanly over any
                    // background art. 0.35 is the sweet spot — enough to
                    // anchor text, not so much that the art is muted.
                    Color.black.opacity(0.35)

                    VStack(spacing: 12) {
                        Text("DAILY VERSE \u{00B7} \(monthDayString)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .tracking(1.6)
                            .foregroundStyle(.white.opacity(0.85))

                        Spacer(minLength: 0)

                        Text("\u{201C}\(truncatedVerse(verse.text))\u{201D}")
                            .font(.custom("Georgia", size: 17))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .lineLimit(4)

                        Text(verse.reference)
                            .font(.custom("Georgia-Italic", size: 13))
                            .foregroundStyle(.white.opacity(0.85))

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 20)
                }
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .animation(BPAnimation.spring.delay(0.08), value: appeared)
        }
    }

    private var monthDayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: Date()).uppercased()
    }

    /// Trims verse text to ~110 chars at a natural word boundary so the
    /// 4-line layout never wraps awkwardly on any phone width.
    private func truncatedVerse(_ text: String) -> String {
        let maxLength = 110
        guard text.count > maxLength else { return text }
        let prefix = text.prefix(maxLength)
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(text[text.startIndex..<lastSpace]) + "..."
        }
        return String(prefix) + "..."
    }

    // MARK: - Today Card (streak + CTA)
    //
    // Combines the streak day-circles, current streak count, and a
    // primary action button. Tapping the card opens Reading Plans.

    private var todayCard: some View {
        let activeDays = vm.activeDaysThisWeek
        let today = Calendar.current.component(.weekday, from: Date())
        let plan = vm.activeReadingPlan
        let ctaText: String = plan.map { "Continue Day \($0.day)" } ?? "Begin a Reading Plan"

        return Button {
            showReadingPlans = true
            HapticService.lightImpact()
        } label: {
            VStack(spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today")
                            .font(.custom("Georgia-Bold", size: 18))
                            .foregroundStyle(palette.textPrimary)
                        Text(longDateString)
                            .font(.custom("Georgia", size: 12))
                            .foregroundStyle(palette.textMuted)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(palette.accent)
                        Text("\(vm.streakCount)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.textPrimary)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(palette.background.opacity(0.7))
                    )
                    .overlay(
                        Capsule().stroke(palette.border.opacity(0.3), lineWidth: 0.5)
                    )
                }

                weekCircles(activeDays: activeDays, today: today)

                Text(ctaText)
                    .font(.custom("Georgia", size: 15))
                    .foregroundStyle(palette.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(palette.background.opacity(0.65))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(palette.border.opacity(0.3), lineWidth: 0.5)
                    )
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(palette.surfaceElevated)
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            )
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .animation(BPAnimation.spring.delay(0.16), value: appeared)
    }

    private func weekCircles(activeDays: Set<Int>, today: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(zip(dayLabels, dayWeekdays)), id: \.1) { label, weekday in
                let isActive = activeDays.contains(weekday)
                let isToday = weekday == today

                ZStack {
                    if isActive {
                        Circle()
                            .fill(palette.accent)
                            .frame(width: 30, height: 30)
                            .shadow(color: palette.accent.opacity(0.3), radius: 4, y: 2)
                            .scaleEffect(animateStreak ? 1 : 0)
                    } else if isToday {
                        Circle()
                            .stroke(palette.accent, lineWidth: 1.6)
                            .frame(width: 30, height: 30)
                    } else {
                        Circle()
                            .fill(palette.background.opacity(0.5))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle().stroke(palette.border.opacity(0.25), lineWidth: 0.5)
                            )
                    }

                    Text(label)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            isActive ? .white :
                            (isToday ? palette.accent : palette.textMuted)
                        )
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var longDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: Date())
    }

    // MARK: - Action Grid (functional shortcuts)
    //
    // The 2x2 grid surfaces the practical navigation that the tab bar
    // used to carry — Continue Reading, Reading Plans, Sanctuary, Saved.
    // Each opens its full-page / sheet destination. Subtitles are live:
    // the reading + plan cards reflect the user's actual position.

    private var actionGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            actionCard(
                icon: "book.fill",
                title: vm.continueReading != nil ? "Continue" : "Read",
                subtitle: continueReadingSubtitle
            ) {
                onContinueReading()
            }

            actionCard(
                icon: "calendar",
                title: "Reading Plan",
                subtitle: planSubtitle
            ) {
                showReadingPlans = true
            }

            actionCard(
                icon: "moon.stars.fill",
                title: "Sanctuary",
                subtitle: "Prayer & sound"
            ) {
                onOpenSanctuary()
            }

            actionCard(
                icon: "bookmark.fill",
                title: "Saved",
                subtitle: "Your bookmarks"
            ) {
                NotificationCenter.default.post(name: .switchToSavedTab, object: nil)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .animation(BPAnimation.spring.delay(0.24), value: appeared)
    }

    private var continueReadingSubtitle: LocalizedStringKey {
        if let r = vm.continueReading {
            return "\(r.bookName) \(r.chapter)"
        }
        return "Open the Bible"
    }

    private var planSubtitle: LocalizedStringKey {
        if let p = vm.activeReadingPlan {
            return "Day \(p.day) of \(p.total)"
        }
        return "Browse plans"
    }

    private func actionCard(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticService.lightImpact()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(palette.accent)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(palette.accent.opacity(0.10)))

                Spacer(minLength: 10)

                Text(title)
                    .font(.custom("Georgia", size: 15))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .frame(height: 108)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(palette.surfaceElevated)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Composer (the centerpiece)
    //
    // Real TextField. Submits via the existing `.openAIWithContext`
    // notification — ContentView creates the conversation and routes
    // the user into a streaming ChatView.

    private var homeComposer: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.95, blue: 0.6),
                            Color(red: 1.0, green: 0.84, blue: 0.3),
                            palette.accent
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 22)

            TextField(
                placeholderText,
                text: $composerText,
                axis: .vertical
            )
            .font(BPFont.elegantBody)
            .focused($composerFocused)
            .lineLimit(1...4)
            .submitLabel(.send)
            .onSubmit { submitComposer() }
            .foregroundStyle(palette.textPrimary)

            sendButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    composerFocused ? palette.accent : palette.accent.opacity(0.45),
                    lineWidth: composerFocused ? 1.4 : 0.8
                )
        )
        .animation(.easeOut(duration: 0.18), value: composerFocused)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .animation(BPAnimation.spring.delay(0.32), value: appeared)
    }

    private var sendButton: some View {
        let isEmpty = composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return Button {
            submitComposer()
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(isEmpty ? palette.border.opacity(0.55) : palette.accent)
                )
        }
        .buttonStyle(.plain)
        .disabled(isEmpty)
        .animation(.easeOut(duration: 0.18), value: isEmpty)
    }

    private var placeholderText: String {
        let trimmed = vm.profile.firstName.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return "What\u{2019}s on your heart?"
        }
        return "What\u{2019}s on your heart, \(trimmed)?"
    }

    private func submitComposer() {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        HapticService.lightImpact()
        composerFocused = false

        NotificationCenter.default.post(
            name: .openAIWithContext,
            object: nil,
            userInfo: [
                "context": trimmed,
                "title": String(trimmed.prefix(40))
            ]
        )

        composerText = ""
    }
}
