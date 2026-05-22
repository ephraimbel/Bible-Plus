import SwiftUI
import SwiftData

struct PlanDetailView: View {
    let plan: ReadingPlan
    @Bindable var viewModel: ReadingPlansViewModel
    let isPro: Bool

    @Environment(\.bpPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    @State private var showNextDay = false
    @State private var showAbandonConfirm = false
    @State private var ringAnimationProgress: Double = 0
    /// Decoded once from `plan.daysJSON` on first render and refreshed when the
    /// plan identity changes. Avoids re-running JSONDecoder on every body eval.
    @State private var days: [PlanDay] = []

    private var progress: UserPlanProgress? {
        viewModel.latestProgressForPlan(plan.id)
    }

    private var isCompleted: Bool {
        viewModel.isCompleted(plan.id)
    }

    private var gradientColors: [Color] {
        plan.gradientColors.map { Color(hex: $0) }
    }

    private var nextDayData: PlanDay? {
        guard let progress else { return nil }
        let next = progress.nextDay(totalDays: plan.totalDays)
        return days.first(where: { $0.day == next })
    }

    /// Days at which a milestone (25/50/75%) falls. Only marked on plans long
    /// enough for milestones to feel meaningful — a 7-day plan doesn't need
    /// "you're 25% done" fanfare at day 2.
    private var milestoneDays: Set<Int> {
        guard plan.totalDays >= 8 else { return [] }
        var set = Set<Int>()
        for pct in [25, 50, 75] {
            let target = Int((Double(pct) / 100.0) * Double(plan.totalDays).rounded())
            set.insert(target)
        }
        return set
    }

    var body: some View {
        let _ = viewModel.refreshToken
        ScrollView {
            VStack(spacing: 0) {
                heroHeader

                // When the plan is active, the progress ring is the emotional
                // anchor — it replaces the stats row for a more momentum-
                // focused feel. Browse/completed states still get stats.
                if progress != nil, !isCompleted {
                    progressRingSection
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                } else {
                    statsRow
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                }

                ctaButton
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                if plan.isProOnly && !isPro {
                    proUpsellBanner
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                }

                dayList
                    .padding(.top, 24)
                    .padding(.horizontal, 16)

                if progress != nil && !isCompleted {
                    leavePlanButton
                        .padding(.top, 24)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 40)
        }
        .background(palette.background)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showNextDay) {
            if let nextDayData {
                PlanDayView(
                    plan: plan,
                    day: nextDayData,
                    viewModel: viewModel,
                    isPro: isPro
                )
            }
        }
        .alert("Leave Plan?", isPresented: $showAbandonConfirm) {
            Button("Leave", role: .destructive) {
                if let progress {
                    viewModel.abandonPlan(progress)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your progress will be saved. You can restart this plan anytime.")
        }
        .onAppear {
            if days.isEmpty {
                days = plan.days
            }
            withAnimation(BPAnimation.spring.delay(0.2)) {
                showContent = true
            }
            // Ring fills on appear and whenever progress changes.
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                ringAnimationProgress = progress?.completionFraction(totalDays: plan.totalDays) ?? 0
            }
        }
        .onChange(of: plan.id) { _, _ in
            days = plan.days
        }
        .onChange(of: progress?.completedDays.count ?? 0) { _, _ in
            withAnimation(.easeOut(duration: 0.6)) {
                ringAnimationProgress = progress?.completionFraction(totalDays: plan.totalDays) ?? 0
            }
        }
        .onChange(of: viewModel.navigateToPlanDayID) { _, newID in
            guard newID == plan.id else { return }
            viewModel.navigateToPlanDayID = nil
            showNextDay = true
        }
    }

    // MARK: - Hero Header

    /// Curated artwork for the plan. Explicit `imageKey` from seed JSON wins;
    /// fuzzy resolver is only a fallback for legacy data without a key set.
    private var planImage: UIImage? {
        if !plan.imageKey.isEmpty,
           let direct = BiblicalImageService.rawImage(for: plan.imageKey) {
            return direct
        }
        return BiblicalImageService.image(
            for: plan.id,
            context: "\(plan.name) \(plan.planDescription) \(plan.category)"
        )
    }

    private var heroHeader: some View {
        ZStack {
            if let image = planImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 32, opaque: true)
                    .overlay(Color.black.opacity(0.12))

                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LinearGradient(
                    colors: gradientColors.isEmpty
                        ? [palette.accent, palette.accent.opacity(0.7)]
                        : gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.15), location: 0.0),
                    .init(color: .black.opacity(0.45), location: 0.5),
                    .init(color: .black.opacity(0.78), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 12) {
                Spacer(minLength: 0)

                Text(plan.name)
                    .font(BPFont.elegantTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
                    .padding(.horizontal, 24)

                Text(plan.planDescription)
                    .font(BPFont.elegantBody)
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 1)
                    .padding(.horizontal, 32)
            }
            .padding(.vertical, 28)
        }
        .frame(minHeight: 280)
    }

    // MARK: - Progress Ring Section (active plan)

    private var progressRingSection: some View {
        let frac = progress?.completionFraction(totalDays: plan.totalDays) ?? 0
        let completed = progress?.completedDays.count ?? 0
        let remaining = max(0, plan.totalDays - completed)
        let pct = Int((frac * 100).rounded())

        return HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(palette.accent.opacity(0.12), lineWidth: 6)
                    .frame(width: 84, height: 84)

                Circle()
                    .trim(from: 0, to: CGFloat(ringAnimationProgress))
                    .stroke(
                        AngularGradient(
                            colors: [palette.accent, palette.accent.opacity(0.85), palette.accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 84, height: 84)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: palette.accent.opacity(0.3), radius: 4)

                VStack(spacing: 0) {
                    Text("\(pct)%")
                        .font(BPFont.elegantHeadingLarge)
                        .foregroundStyle(palette.textPrimary)
                    Text("done")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.success)
                    Text("\(completed) of \(plan.totalDays) days")
                        .font(.custom("Georgia-Bold", size: 13))
                        .foregroundStyle(palette.textPrimary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.accent)
                    Text(remaining == 1 ? "1 day remaining" : "\(remaining) days remaining")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "tag")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textMuted)
                    Text(plan.category)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
        )
    }

    // MARK: - Stats Row (browse / completed)

    private var statsRow: some View {
        HStack(spacing: 12) {
            statBadge(icon: "calendar", text: "\(plan.totalDays) days")

            statBadge(icon: "tag", text: plan.category)

            if isCompleted {
                statBadge(icon: "checkmark.seal.fill", text: "Completed")
            }
        }
    }

    private func statBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.accent)
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
        .overlay(
            Capsule()
                .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - CTA Button

    @ViewBuilder
    private var ctaButton: some View {
        if isCompleted {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(palette.success)
                    Text("Completed")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.success)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(palette.success.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(palette.success.opacity(0.2), lineWidth: 0.5)
                )

                Button {
                    HapticService.lightImpact()
                    viewModel.restartPlan(plan, isPro: isPro)
                } label: {
                    Text("Start Again")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.accent)
                }
            }
        } else if let progress {
            let nextDay = progress.nextDay(totalDays: plan.totalDays)
            GoldButton(title: "Continue — Day \(nextDay)", showGlow: true) {
                showNextDay = true
            }
        } else {
            if plan.isProOnly && !isPro {
                GoldButton(title: "Unlock with Pro") {
                    viewModel.showPaywall = true
                }
            } else {
                GoldButton(title: "Start Plan", showGlow: true) {
                    viewModel.startPlan(plan, isPro: isPro)
                }
            }
        }
    }

    // MARK: - Pro Upsell Banner

    private var proUpsellBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "crown.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.accent.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("Pro Plan")
                    .font(.custom("Georgia-Bold", size: 14))
                    .foregroundStyle(palette.textPrimary)

                Text("Unlock all \(viewModel.allPlans.filter { $0.isProOnly }.count) premium plans and more.")
                    .font(.custom("Georgia", size: 12))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.textMuted.opacity(0.4))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.accent.opacity(0.15), lineWidth: 0.5)
        )
        .onTapGesture {
            HapticService.lightImpact()
            viewModel.showPaywall = true
        }
    }

    // MARK: - Day List

    /// Plans ≥14 days chunk into "Week 1", "Week 2" sections so the scroll
    /// doesn't feel like a 30-row wall of titles. Short plans keep the single
    /// flat list.
    private var useWeekGrouping: Bool { plan.totalDays >= 14 }

    private var dayList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle().fill(palette.accent.opacity(0.1))
                    )

                Text("DAILY READINGS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(palette.textMuted)

                VStack { Divider() }
                    .padding(.leading, 4)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)

            if useWeekGrouping {
                weekGroupedList
            } else {
                flatList
            }
        }
    }

    // MARK: Day List — Flat

    private var flatList: some View {
        VStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element.day) { index, day in
                dayRow(day: day)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 10)
                    .animation(BPAnimation.staggered(index: index), value: showContent)

                if index < days.count - 1 {
                    Rectangle()
                        .fill(palette.border.opacity(0.12))
                        .frame(height: 0.5)
                        .padding(.leading, 52)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: Day List — Week-Grouped

    /// Chunk `days` into groups of 7 for the week-grouping layout. The final
    /// group may contain fewer than 7 (e.g. a 16-day plan → 7 + 7 + 2).
    private var weekChunks: [[PlanDay]] {
        stride(from: 0, to: days.count, by: 7).map {
            Array(days[$0..<min($0 + 7, days.count)])
        }
    }

    private var weekGroupedList: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(weekChunks.enumerated()), id: \.offset) { weekIndex, chunk in
                weekSection(weekIndex: weekIndex, days: chunk)
            }
        }
    }

    private func weekSection(weekIndex: Int, days chunk: [PlanDay]) -> some View {
        let weekNumber = weekIndex + 1
        let completedInWeek = chunk.filter { progress?.completedDays.contains($0.day) ?? false }.count
        let allCompleteInWeek = completedInWeek == chunk.count && !chunk.isEmpty

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("WEEK \(weekNumber)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(palette.accent)

                if progress != nil {
                    Text("\(completedInWeek)/\(chunk.count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            allCompleteInWeek ? palette.success : palette.textMuted
                        )
                }

                Spacer()

                if allCompleteInWeek {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.success)
                }
            }
            .padding(.horizontal, 14)

            VStack(spacing: 0) {
                ForEach(Array(chunk.enumerated()), id: \.element.day) { dayIndex, day in
                    dayRow(day: day)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)
                        .animation(
                            BPAnimation.staggered(index: weekIndex * 7 + dayIndex),
                            value: showContent
                        )

                    if dayIndex < chunk.count - 1 {
                        Rectangle()
                            .fill(palette.border.opacity(0.12))
                            .frame(height: 0.5)
                            .padding(.leading, 52)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(palette.surfaceElevated)
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(palette.border.opacity(0.1), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Day Row

    private func dayRow(day: PlanDay) -> some View {
        let isDayCompleted = progress?.completedDays.contains(day.day) ?? false
        let isCurrentDay = !isDayCompleted && (progress?.nextDay(totalDays: plan.totalDays) == day.day)
        let hasReflection = progress?.reflection(for: day.day) != nil
        let isMilestone = milestoneDays.contains(day.day)

        return NavigationLink {
            PlanDayView(
                plan: plan,
                day: day,
                viewModel: viewModel,
                isPro: isPro
            )
        } label: {
            HStack(spacing: 14) {
                dayNumberCircle(day: day, isDayCompleted: isDayCompleted, isCurrentDay: isCurrentDay)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(day.title)
                            .font(.custom("Georgia-Bold", size: 14))
                            .foregroundStyle(isDayCompleted ? palette.textMuted : palette.textPrimary)
                            .lineLimit(1)

                        if isMilestone {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(palette.accent.opacity(0.8))
                        }

                        if hasReflection {
                            Image(systemName: "pencil.line")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(palette.accent.opacity(0.6))
                        }
                    }

                    Text(day.readings.map { $0.displayReference }.joined(separator: " · "))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.textMuted.opacity(0.4))
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isCurrentDay ? palette.accent.opacity(0.04) : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func dayNumberCircle(day: PlanDay, isDayCompleted: Bool, isCurrentDay: Bool) -> some View {
        ZStack {
            if isDayCompleted {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [palette.success, palette.success.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: palette.success.opacity(0.25), radius: 3, y: 1)

                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            } else if isCurrentDay {
                Circle()
                    .fill(palette.accent.opacity(0.08))
                    .frame(width: 40, height: 40)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [palette.accent, palette.accent.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: palette.accent.opacity(0.3), radius: 4, y: 1)

                Text("\(day.day)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .fill(palette.surface)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(palette.border.opacity(0.2), lineWidth: 0.5)
                    )

                Text("\(day.day)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textMuted)
            }
        }
    }

    // MARK: - Leave Plan

    private var leavePlanButton: some View {
        Button {
            HapticService.lightImpact()
            showAbandonConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 14, weight: .medium))
                Text("Leave Plan")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .foregroundStyle(palette.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
            )
        }
    }
}
