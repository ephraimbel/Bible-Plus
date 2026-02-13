import SwiftUI
import SwiftData

struct PlanDetailView: View {
    let plan: ReadingPlan
    @Bindable var viewModel: ReadingPlansViewModel
    let isPro: Bool
    let onReadChapter: (String, Int) -> Void

    @Environment(\.bpPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    @State private var showNextDay = false
    @State private var showAbandonConfirm = false

    private var progress: UserPlanProgress? {
        viewModel.latestProgressForPlan(plan.id)
    }

    private var isCompleted: Bool {
        viewModel.isCompleted(plan.id)
    }

    private var days: [PlanDay] { plan.days }

    private var gradientColors: [Color] {
        plan.gradientColors.map { Color(hex: $0) }
    }

    private var nextDayData: PlanDay? {
        guard let progress else { return nil }
        let next = progress.nextDay(totalDays: plan.totalDays)
        return days.first(where: { $0.day == next })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero header
                heroHeader

                // Stats row
                statsRow
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                // CTA button
                ctaButton
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                // Pro upsell for locked plans
                if plan.isProOnly && !isPro {
                    proUpsellBanner
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                }

                // Day list
                dayList
                    .padding(.top, 24)
                    .padding(.horizontal, 16)

                // Leave plan
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
            if let nextDayData, let progress {
                PlanDayView(
                    plan: plan,
                    day: nextDayData,
                    isDayCompleted: progress.completedDays.contains(nextDayData.day),
                    viewModel: viewModel,
                    isPro: isPro,
                    onReadChapter: onReadChapter
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
            withAnimation(BPAnimation.spring.delay(0.2)) {
                showContent = true
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors.isEmpty ? [palette.accent, palette.accent.opacity(0.7)] : gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Background icon
            Image(systemName: plan.iconName.isEmpty ? "book.fill" : plan.iconName)
                .font(.system(size: 120, weight: .thin))
                .foregroundStyle(.white.opacity(0.1))
                .offset(x: 80, y: -10)

            VStack(spacing: 12) {
                Image(systemName: plan.iconName.isEmpty ? "book.fill" : plan.iconName)
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.white)

                Text(plan.name)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

                Text(plan.planDescription)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            .padding(.vertical, 32)
        }
        .frame(minHeight: 220)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 16) {
            statBadge(icon: "calendar", text: "\(plan.totalDays) days")

            statBadge(icon: "tag", text: plan.category)

            if let progress, !isCompleted {
                statBadge(
                    icon: "chart.bar.fill",
                    text: "\(progress.completedDays.count)/\(plan.totalDays)"
                )
            }
        }
    }

    private func statBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(palette.accent)
            Text(text)
                .font(BPFont.caption)
                .foregroundStyle(palette.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(palette.surface)
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
                        .font(BPFont.button)
                        .foregroundStyle(palette.success)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(palette.success.opacity(0.12))
                )

                // Restart option
                Button {
                    HapticService.lightImpact()
                    viewModel.restartPlan(plan, isPro: isPro)
                } label: {
                    Text("Start Again")
                        .font(BPFont.caption)
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
                .font(.system(size: 20))
                .foregroundStyle(palette.accent)

            VStack(alignment: .leading, spacing: 3) {
                Text("Pro Plan")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Text("Unlock all \(viewModel.allPlans.filter { $0.isProOnly }.count) premium plans, unlimited concurrent plans, and more.")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.textMuted)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(palette.accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(palette.accent.opacity(0.2), lineWidth: 1)
        )
        .onTapGesture {
            HapticService.lightImpact()
            viewModel.showPaywall = true
        }
    }

    // MARK: - Day List

    private var dayList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Daily Readings")
                .font(BPFont.button)
                .foregroundStyle(palette.textPrimary)
                .padding(.horizontal, 8)
                .padding(.bottom, 12)

            ForEach(Array(days.enumerated()), id: \.element.day) { index, day in
                let isDayCompleted = progress?.completedDays.contains(day.day) ?? false
                let isCurrentDay = !isDayCompleted && (progress?.nextDay(totalDays: plan.totalDays) == day.day)

                dayRow(day: day, isDayCompleted: isDayCompleted, isCurrentDay: isCurrentDay)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 10)
                    .animation(BPAnimation.staggered(index: index), value: showContent)

                if index < days.count - 1 {
                    Divider()
                        .overlay(palette.border)
                        .padding(.leading, 44)
                }
            }
        }
    }

    private func dayRow(day: PlanDay, isDayCompleted: Bool, isCurrentDay: Bool) -> some View {
        NavigationLink {
            PlanDayView(
                plan: plan,
                day: day,
                isDayCompleted: isDayCompleted,
                viewModel: viewModel,
                isPro: isPro,
                onReadChapter: onReadChapter
            )
        } label: {
            HStack(spacing: 14) {
                // Checkmark / day number circle
                ZStack {
                    Circle()
                        .fill(isDayCompleted ? palette.success : (isCurrentDay ? palette.accent : palette.surface))
                        .frame(width: 32, height: 32)

                    if isDayCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(day.day)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(isCurrentDay ? .white : palette.textMuted)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(day.title)
                        .font(BPFont.button)
                        .foregroundStyle(isDayCompleted ? palette.textMuted : palette.textPrimary)

                    Text(day.readings.map { $0.displayReference }.joined(separator: " · "))
                        .font(BPFont.caption)
                        .foregroundStyle(palette.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textMuted.opacity(0.5))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isCurrentDay ? palette.accent.opacity(0.06) : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Leave Plan

    private var leavePlanButton: some View {
        Button {
            HapticService.lightImpact()
            showAbandonConfirm = true
        } label: {
            Text("Leave Plan")
                .font(BPFont.caption)
                .foregroundStyle(palette.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
    }
}
