import SwiftUI

struct HomeDashboardView: View {
    @Bindable var vm: FeedViewModel
    let soundscapeService: SoundscapeService
    let onEnterFeed: () -> Void
    let onShowProgress: () -> Void
    let onShowSettings: () -> Void
    let onDailyVerseTap: () -> Void
    let onContinueReading: () -> Void
    let onOpenJournal: () -> Void
    let onOpenSanctuary: () -> Void

    @Environment(\.bpPalette) private var palette
    @State private var animateStreak = false
    @State private var showReadingPlans = false
    @State private var appeared = false
    @State private var floatingOffset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var hasTriggeredHaptic = false

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 12) {
                headerSection
                heroVerseCard
                streakProgressStrip
                quickActionsGrid
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .offset(y: dragOffset)

            // Bottom gradient with swipe prompt
            swipeUpPrompt
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    let translation = value.translation.height
                    guard translation < 0 else {
                        dragOffset = 0
                        return
                    }
                    // Rubber-band: diminishing returns past threshold
                    let raw = -translation
                    dragOffset = -min(raw, 80 + (raw - 80) * 0.2)

                    if raw > 80 && !hasTriggeredHaptic {
                        HapticService.notification(.success)
                        hasTriggeredHaptic = true
                    }
                }
                .onEnded { value in
                    let translation = -value.translation.height
                    if translation > 80 {
                        onEnterFeed()
                    }
                    withAnimation(BPAnimation.spring) {
                        dragOffset = 0
                    }
                    hasTriggeredHaptic = false
                }
        )
        .sheet(isPresented: $showReadingPlans) {
            ReadingPlansView(
                isPro: vm.profile.isPro,
                onReadChapter: { bookName, chapter in
                    showReadingPlans = false
                    NotificationCenter.default.post(
                        name: .scriptureDeepLink,
                        object: nil,
                        userInfo: ["bookName": bookName, "chapter": chapter]
                    )
                }
            )
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
    }

    // MARK: - Swipe Up Prompt

    private var swipeUpPrompt: some View {
        VStack(spacing: 6) {
            Spacer()

            Image(systemName: "chevron.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.accent.opacity(0.6))
                .offset(y: floatingOffset)

            Text("Swipe up to explore")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textMuted)
        }
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [palette.background, palette.background.opacity(0)],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 120)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)
        )
        .allowsHitTesting(false)
        .opacity(appeared ? 1 : 0)
        .animation(BPAnimation.spring.delay(0.5), value: appeared)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                floatingOffset = -4
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.greetingLabel)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textSecondary)

                Text(vm.userName + ".")
                    .font(BPFont.headingSmall)
                    .foregroundStyle(palette.textPrimary)

                Text(vm.formattedDate)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .padding(.top, 2)
            }

            Spacer()

            Button {
                onShowSettings()
                HapticService.lightImpact()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.textMuted)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(palette.surface))
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Hero Verse Card

    @ViewBuilder
    private var heroVerseCard: some View {
        if let verse = vm.dailyVerse {
            let bgColors = vm.currentBackground.gradientColors.map { Color(hex: $0) }
            let gradient = LinearGradient(
                colors: bgColors.isEmpty ? [palette.accent] : bgColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Button {
                onDailyVerseTap()
                HapticService.lightImpact()
            } label: {
                ZStack {
                    // Gradient background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(gradient)

                    // Dark overlay for readability
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.35))

                    // Content
                    VStack(spacing: 16) {
                        // Label
                        HStack(spacing: 6) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 10, weight: .semibold))
                            Text("VERSE OF THE DAY")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.5)
                        }
                        .foregroundStyle(.white.opacity(0.7))

                        // Verse text
                        Text("\u{201C}\(verse.text)\u{201D}")
                            .font(BPFont.prayerMedium)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)

                        // Reference
                        Text("— \(verse.reference)")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.white.opacity(0.7))

                        // CTA
                        HStack(spacing: 4) {
                            Text("Read in Bible")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(Color(hex: "C9A96E"))
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 160)
                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            }
            .buttonStyle(PressableButtonStyle())
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(BPAnimation.spring.delay(0.1), value: appeared)
        }
    }

    // MARK: - Streak Progress Strip

    private var streakProgressStrip: some View {
        let activeDays = vm.activeDaysThisWeek
        let today = Calendar.current.component(.weekday, from: Date())
        let dayOrder: [(label: String, weekday: Int)] = [
            ("M", 2), ("T", 3), ("W", 4), ("T", 5), ("F", 6), ("S", 7), ("S", 1)
        ]

        return Button {
            onShowProgress()
            HapticService.selection()
        } label: {
            HStack(spacing: 0) {
                // Left: Flame + streak
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(palette.accent)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(vm.streakCount >= 2 ? "\(vm.streakCount)-day streak" : "This Week")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.textPrimary)

                        HStack(spacing: 3) {
                            Text("Details")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .foregroundStyle(palette.textMuted)
                    }
                }

                Spacer()

                // Right: 7 compact dots
                HStack(spacing: 6) {
                    ForEach(Array(dayOrder.enumerated()), id: \.offset) { _, day in
                        let isActive = activeDays.contains(day.weekday)
                        let isToday = day.weekday == today

                        VStack(spacing: 3) {
                            ZStack {
                                if isActive {
                                    Circle()
                                        .fill(palette.accent)
                                        .frame(width: 20, height: 20)
                                        .scaleEffect(animateStreak ? 1 : 0)

                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .scaleEffect(animateStreak ? 1 : 0)
                                } else if isToday {
                                    Circle()
                                        .stroke(palette.accent.opacity(0.5), lineWidth: 1.5)
                                        .frame(width: 20, height: 20)
                                } else {
                                    Circle()
                                        .fill(palette.surface)
                                        .frame(width: 20, height: 20)
                                }
                            }

                            Text(day.label)
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(
                                    isToday ? palette.textPrimary : palette.textMuted.opacity(0.7)
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(palette.surface)
            )
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(BPAnimation.spring.delay(0.2), value: appeared)
    }

    // MARK: - Quick Actions Grid

    private var quickActionsGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return LazyVGrid(columns: columns, spacing: 12) {
            // Continue Reading
            quickActionCard(
                icon: "book.fill",
                title: vm.continueReading != nil ? "Continue\nReading" : "Start\nReading",
                subtitle: vm.continueReading.map { "\($0.bookName) \($0.chapter)" } ?? "Open the Bible"
            ) {
                onContinueReading()
                HapticService.lightImpact()
            }

            // Reading Plan
            quickActionCard(
                icon: "calendar",
                title: "Reading\nPlan",
                subtitle: vm.activeReadingPlan.map { "Day \($0.day) of \($0.total)" } ?? "Start a plan",
                progress: vm.activeReadingPlan.map { CGFloat($0.day) / CGFloat(max($0.total, 1)) }
            ) {
                showReadingPlans = true
                HapticService.lightImpact()
            }

            // Prayer Journal
            quickActionCard(
                icon: "pencil.and.scribble",
                title: "Prayer\nJournal",
                subtitle: vm.prayerJournalSummary.map { "\($0.total) prayer\($0.total == 1 ? "" : "s")" } ?? "Start writing"
            ) {
                onOpenJournal()
                HapticService.lightImpact()
            }

            // Sanctuary
            quickActionCard(
                icon: "moon.stars",
                title: "Sanctuary",
                subtitle: soundscapeService.isPlaying
                    ? "Now playing"
                    : "Tap to enter"
            ) {
                onOpenSanctuary()
                HapticService.lightImpact()
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(BPAnimation.spring.delay(0.3), value: appeared)
    }

    private func quickActionCard(
        icon: String,
        title: String,
        subtitle: String,
        progress: CGFloat? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.accent)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(palette.accent.opacity(0.12)))

                Spacer(minLength: 0)

                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                    .lineSpacing(2)

                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)

                if let progress {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(palette.accent.opacity(0.15))
                                .frame(height: 4)
                            Capsule()
                                .fill(palette.accent)
                                .frame(width: geo.size.width * progress, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 110)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(palette.accent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(palette.accent.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

}
