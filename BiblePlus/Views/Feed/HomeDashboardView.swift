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
    @Environment(\.colorScheme) private var colorScheme
    @State private var dragOffset: CGFloat = 0
    @State private var crossedThreshold = false
    @State private var lastHapticStep: Int = 0
    @State private var animateStreak = false
    @State private var showReadingPlans = false
    @State private var showPaywall = false

    // MARK: - Layout Constants (8pt grid)

    private let hMargin: CGFloat = 20
    private let sectionGap: CGFloat = 16
    private let innerGap: CGFloat = 8
    private let cardPadH: CGFloat = 14
    private let cardPadV: CGFloat = 14
    private let cardRadius: CGFloat = 14
    private let iconSize: CGFloat = 32

    // Rubber-band physics
    private let rubberBandCoeff: CGFloat = 120

    private func rubberBand(_ offset: CGFloat) -> CGFloat {
        let d = abs(offset)
        let r = rubberBandCoeff * log2(1 + d / rubberBandCoeff)
        return offset < 0 ? -r : r
    }

    private var dragProgress: CGFloat {
        min(abs(dragOffset) / 100, 1.0)
    }

    // MARK: - Gradient theming

    private var gradientTint: Color {
        colorScheme == .dark
            ? palette.accent
            : Color(red: 0.65, green: 0.48, blue: 0.25)
    }

    private var gradientIntensity: CGFloat {
        colorScheme == .dark ? 1.0 : 2.6
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            // Layer 0: Gradient (behind everything)
            bottomGradientOverlay

            // Layer 1: Content
            VStack(spacing: 0) {
                headerSection
                    .padding(.bottom, sectionGap)

                weeklyStreakBar
                    .padding(.bottom, sectionGap)

                dailyVerseSection
                    .padding(.bottom, sectionGap)

                if !vm.dashboardReadingPlans.isEmpty {
                    readingPlansSection
                        .padding(.bottom, sectionGap)
                }

                quickActionsSection

                sanctuarySection
                    .padding(.top, sectionGap)

                Spacer(minLength: 0)

                swipeUpIndicator
                    .padding(.bottom, 8)
            }
            .offset(y: rubberBand(dragOffset) * 0.35)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onChanged { value in
                    if value.translation.height < 0 {
                        dragOffset = value.translation.height

                        let step = Int(abs(value.translation.height) / 25)
                        if step > lastHapticStep && step <= 3 {
                            lastHapticStep = step
                            HapticService.selection()
                        }

                        if abs(value.translation.height) >= 100 && !crossedThreshold {
                            crossedThreshold = true
                            HapticService.impact(.rigid)
                        } else if abs(value.translation.height) < 100 && crossedThreshold {
                            crossedThreshold = false
                            HapticService.selection()
                        }
                    }
                }
                .onEnded { value in
                    if value.translation.height < -100 {
                        HapticService.notification(.success)
                        onEnterFeed()
                    }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                        dragOffset = 0
                    }
                    crossedThreshold = false
                    lastHapticStep = 0
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
        .fullScreenCover(isPresented: $showPaywall) {
            SummaryPaywallView()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.6)) {
                    animateStreak = true
                }
            }
        }
    }

    // MARK: - Swipe Up Indicator

    private var swipeUpIndicator: some View {
        let progress = dragProgress
        let locked = crossedThreshold

        return VStack(spacing: 5) {
            VStack(spacing: 1) {
                Image(systemName: "chevron.compact.up")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(gradientTint.opacity(locked ? 0.8 : 0.35))
                    .offset(y: locked ? -3 : 0)

                Image(systemName: "chevron.compact.up")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(
                        gradientTint.opacity(locked ? 0.6 : 0.2 + max(Double(progress) - 0.3, 0) * 0.5)
                    )
            }
            .scaleEffect(locked ? 1.15 : 1.0 + Double(progress) * 0.08)
            .offset(y: -Double(progress) * 4)
            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.7), value: progress)
            .animation(.easeOut(duration: 0.15), value: locked)

            Text(locked ? "Release to explore" : "Swipe up to explore")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(gradientTint.opacity(locked ? 0.7 : 0.3))
                .animation(.easeOut(duration: 0.15), value: locked)

            Capsule()
                .fill(gradientTint.opacity(0.15 + Double(progress) * 0.3))
                .frame(width: 30 + CGFloat(progress) * 20, height: locked ? 2.5 : 2)
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.7), value: progress)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Static Bottom Gradient

    private var bottomGradientOverlay: some View {
        let i = gradientIntensity
        let base: CGFloat = 0.06 * i

        return VStack(spacing: 0) {
            Spacer()

            LinearGradient(
                stops: [
                    .init(color: Color.clear, location: 0.0),
                    .init(color: Color.clear, location: 0.1),
                    .init(color: gradientTint.opacity(base * 0.2), location: 0.25),
                    .init(color: gradientTint.opacity(base * 0.5), location: 0.45),
                    .init(color: gradientTint.opacity(base * 0.9), location: 0.7),
                    .init(color: gradientTint.opacity(base * 1.3), location: 0.88),
                    .init(color: gradientTint.opacity(base * 1.5), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 280)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 0) {
                    Text("Bible")
                        .foregroundStyle(palette.textPrimary)
                    Text("+")
                        .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.3))
                        .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 4)
                        .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 10)
                        .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.9), radius: 20)
                }
                .font(.system(size: 26, weight: .bold, design: .serif))

                Spacer()

                Button {
                    onShowSettings()
                    HapticService.lightImpact()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(palette.textMuted)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(palette.surface))
                }
            }
            .padding(.top, 8)

            Text(vm.formattedDate.uppercased())
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(palette.textMuted)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 1) {
                Text(vm.greetingLabel)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
                Text(vm.userName + ".")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(palette.textPrimary)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, hMargin)
    }

    // MARK: - Weekly Streak Bar

    private var weeklyStreakBar: some View {
        let activeDays = vm.activeDaysThisWeek
        let today = Calendar.current.component(.weekday, from: Date())
        let dayOrder: [(label: String, weekday: Int)] = [
            ("M", 2), ("T", 3), ("W", 4), ("T", 5), ("F", 6), ("S", 7), ("S", 1)
        ]

        return Button {
            onShowProgress()
            HapticService.selection()
        } label: {
            VStack(spacing: 10) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(palette.accent)
                        Text(vm.streakCount >= 2 ? "\(vm.streakCount)-day streak" : "This Week")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.textPrimary)
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        Text("Details")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.textMuted)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(palette.textMuted)
                    }
                }

                HStack(spacing: 0) {
                    ForEach(Array(dayOrder.enumerated()), id: \.offset) { _, day in
                        let isActive = activeDays.contains(day.weekday)
                        let isToday = day.weekday == today
                        let isPast = isDayPast(day.weekday, today: today)

                        VStack(spacing: 5) {
                            ZStack {
                                Circle()
                                    .fill(isActive ? palette.accent : palette.surface)
                                    .frame(width: 30, height: 30)
                                if isToday && !isActive {
                                    Circle()
                                        .stroke(palette.accent.opacity(0.4), lineWidth: 1.5)
                                        .frame(width: 30, height: 30)
                                }
                                if isActive {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .scaleEffect(animateStreak ? 1 : 0)
                                }
                            }
                            Text(day.label)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(
                                    isToday ? palette.textPrimary :
                                    isPast ? palette.textMuted :
                                    palette.textMuted.opacity(0.5)
                                )
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, cardPadH)
            .padding(.vertical, cardPadV)
            .background(RoundedRectangle(cornerRadius: cardRadius).fill(palette.surface))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, hMargin)
    }

    private func isDayPast(_ weekday: Int, today: Int) -> Bool {
        let monOrder: [Int: Int] = [2: 0, 3: 1, 4: 2, 5: 3, 6: 4, 7: 5, 1: 6]
        guard let dayIdx = monOrder[weekday], let todayIdx = monOrder[today] else { return false }
        return dayIdx < todayIdx
    }

    // MARK: - Daily Verse

    @ViewBuilder
    private var dailyVerseSection: some View {
        if let verse = vm.dailyVerse {
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("VERSE OF THE DAY")

                Button {
                    onDailyVerseTap()
                    HapticService.lightImpact()
                } label: {
                    HStack(alignment: .top, spacing: 0) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(palette.accent.opacity(0.45))
                            .frame(width: 3)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("\u{201C}\(verse.text)\u{201D}")
                                .font(.system(size: 14, weight: .regular, design: .serif))
                                .foregroundStyle(palette.textPrimary)
                                .lineSpacing(2)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)

                            HStack {
                                Text(verse.reference)
                                    .font(.system(size: 12, weight: .medium, design: .serif))
                                    .italic()
                                    .foregroundStyle(palette.accent)
                                Spacer()
                                HStack(spacing: 4) {
                                    Text("Read")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .foregroundStyle(palette.accent)
                            }
                        }
                        .padding(.leading, 10)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: cardRadius).fill(palette.surface))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, hMargin)
        }
    }

    // MARK: - Reading Plans (Compact)

    private var readingPlansSection: some View {
        let plans = vm.dashboardReadingPlans
        let isPro = vm.profile.isPro

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel("READING PLANS")
                Spacer()
                Button {
                    showReadingPlans = true
                    HapticService.selection()
                } label: {
                    HStack(spacing: 3) {
                        Text("See All")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundStyle(palette.textMuted)
                }
            }
            .padding(.horizontal, hMargin)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(plans) { plan in
                        Button {
                            if plan.isProOnly && !isPro {
                                showPaywall = true
                            } else {
                                showReadingPlans = true
                            }
                            HapticService.lightImpact()
                        } label: {
                            compactPlanCard(plan: plan, isPro: isPro)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, hMargin)
            }
        }
    }

    private func compactPlanCard(plan: ReadingPlan, isPro: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: plan.iconName.isEmpty ? "book.fill" : plan.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.accent)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(palette.accentSoft))

                Spacer()

                if plan.isProOnly && !isPro {
                    HStack(spacing: 2) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 8, weight: .semibold))
                        Text("PRO")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .tracking(0.5)
                    }
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(palette.accent.opacity(0.12)))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(plan.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)

                Text("\(plan.totalDays) days")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textMuted)
            }
        }
        .padding(12)
        .frame(width: 150)
        .background(RoundedRectangle(cornerRadius: cardRadius).fill(palette.surface))
        .overlay(RoundedRectangle(cornerRadius: cardRadius).stroke(palette.border.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Quick Actions (Your Journey)

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let hasContent = vm.continueReading != nil || vm.activeReadingPlan != nil || vm.prayerJournalSummary != nil

            if hasContent {
                sectionLabel("YOUR JOURNEY")
                    .padding(.horizontal, hMargin)

                VStack(spacing: innerGap) {
                    continueReadingRow
                    readingPlanRow
                    prayerJournalRow
                }
                .padding(.horizontal, hMargin)
            }
        }
    }

    @ViewBuilder
    private var continueReadingRow: some View {
        if let reading = vm.continueReading {
            Button {
                onContinueReading()
                HapticService.lightImpact()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(palette.accentSoft)
                        Image(systemName: "book.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(palette.accent)
                    }
                    .frame(width: iconSize, height: iconSize)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Continue Reading")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .foregroundStyle(palette.textMuted)

                        HStack(spacing: 4) {
                            Text("\(reading.bookName) \(reading.chapter)")
                                .font(.system(size: 14, weight: .medium, design: .serif))
                                .foregroundStyle(palette.textPrimary)
                            Text("\u{00B7} Verse \(reading.verse)")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(palette.textMuted)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, cardPadH)
                .padding(.vertical, cardPadV)
                .background(RoundedRectangle(cornerRadius: cardRadius).fill(palette.surface))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var readingPlanRow: some View {
        if let plan = vm.activeReadingPlan {
            Button {
                showReadingPlans = true
                HapticService.lightImpact()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(palette.border.opacity(0.3), lineWidth: 2.5)
                        Circle()
                            .trim(from: 0, to: CGFloat(plan.day) / CGFloat(max(plan.total, 1)))
                            .stroke(palette.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(Double(plan.day) / Double(max(plan.total, 1)) * 100))%")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.textMuted)
                    }
                    .frame(width: iconSize, height: iconSize)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.name)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)
                        Text("Day \(plan.day) of \(plan.total)")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(palette.textMuted)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, cardPadH)
                .padding(.vertical, cardPadV)
                .background(RoundedRectangle(cornerRadius: cardRadius).fill(palette.surface))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var prayerJournalRow: some View {
        if let prayer = vm.prayerJournalSummary {
            Button {
                onOpenJournal()
                HapticService.lightImpact()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(palette.accentSoft)
                        Image(systemName: "pencil.and.scribble")
                            .font(.system(size: 13))
                            .foregroundStyle(palette.accent)
                    }
                    .frame(width: iconSize, height: iconSize)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Prayer Journal")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .foregroundStyle(palette.textMuted)

                        HStack(spacing: 4) {
                            Text("\(prayer.total) prayer\(prayer.total == 1 ? "" : "s")")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(palette.textPrimary)
                            if prayer.answered > 0 {
                                Text("\u{00B7} \(prayer.answered) answered")
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundStyle(palette.success)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, cardPadH)
                .padding(.vertical, cardPadV)
                .background(RoundedRectangle(cornerRadius: cardRadius).fill(palette.surface))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Sanctuary

    private var sanctuarySection: some View {
        Button {
            onOpenSanctuary()
            HapticService.lightImpact()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.accent)
                    .frame(width: iconSize, height: iconSize)
                    .background(Circle().fill(palette.accentSoft))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sanctuary")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textPrimary)

                    Text(soundscapeService.isPlaying
                         ? "Now playing: \(soundscapeService.currentSoundscape.displayName)"
                         : "Tap to enter")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, cardPadH)
            .padding(.vertical, cardPadV)
            .background(RoundedRectangle(cornerRadius: cardRadius).fill(palette.surface))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, hMargin)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(1.5)
            .foregroundStyle(palette.textMuted)
    }
}
