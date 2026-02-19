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
                .foregroundStyle(.white.opacity(0.08))
                .offset(x: 80, y: -10)

            VStack(spacing: 14) {
                // Icon in glass circle
                Image(systemName: plan.iconName.isEmpty ? "book.fill" : plan.iconName)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                Text(plan.name)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

                Text(plan.planDescription)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            .padding(.vertical, 36)
        }
        .frame(minHeight: 240)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
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

                // Restart option
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
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Text("Unlock all \(viewModel.allPlans.filter { $0.isProOnly }.count) premium plans and more.")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.accent.opacity(0.2), lineWidth: 0.5)
        )
        .onTapGesture {
            HapticService.lightImpact()
            viewModel.showPaywall = true
        }
    }

    // MARK: - Day List

    private var dayList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DAILY READINGS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(palette.textMuted)
                .padding(.horizontal, 8)
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.element.day) { index, day in
                    let isDayCompleted = progress?.completedDays.contains(day.day) ?? false
                    let isCurrentDay = !isDayCompleted && (progress?.nextDay(totalDays: plan.totalDays) == day.day)

                    dayRow(day: day, isDayCompleted: isDayCompleted, isCurrentDay: isCurrentDay)
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
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
            )
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
                            .fill(
                                LinearGradient(
                                    colors: [palette.accent, palette.accent.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                            .shadow(color: palette.accent.opacity(0.25), radius: 3, y: 1)

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

                VStack(alignment: .leading, spacing: 3) {
                    Text(day.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(isDayCompleted ? palette.textMuted : palette.textPrimary)

                    Text(day.readings.map { $0.displayReference }.joined(separator: " · "))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isCurrentDay ? palette.accent.opacity(0.04) : .clear)
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
