import SwiftUI
import SwiftData

struct MyProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ProgressViewModel?
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    ProgressContentView(vm: vm, appeared: $appeared)
                } else {
                    ProgressIndicatorView()
                }
            }
            .background(palette.background)
            .scrollContentBackground(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("My Progress")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(palette.textMuted)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(palette.surface)
                            )
                    }
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = ProgressViewModel(modelContext: modelContext)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(BPAnimation.spring) {
                        appeared = true
                    }
                }
            }
        }
    }
}

// MARK: - Content

private struct ProgressContentView: View {
    @Bindable var vm: ProgressViewModel
    @Binding var appeared: Bool
    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    // Animated counters
    @State private var animatedStreak: Int = 0
    @State private var animatedLongest: Int = 0
    @State private var animatedChapters: Int = 0
    @State private var animatedVerses: Int = 0
    @State private var animatedPlans: Int = 0
    @State private var animatedChats: Int = 0
    @State private var ringProgress: CGFloat = 0
    @State private var heatmapAppeared = false

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    private let dayWeekdays = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                heroStreakSection
                weekActivityStrip
                insightsSection
                statsGrid
                monthlyHeatmap
                recentActivityList
                Spacer(minLength: 40)
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Hero Streak Section

    private var heroStreakSection: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 16)

            // Circular ring with streak count
            ZStack {
                // Outer glow
                Circle()
                    .fill(palette.accent.opacity(0.04))
                    .frame(width: 200, height: 200)

                // Background ring
                Circle()
                    .stroke(palette.border.opacity(0.2), lineWidth: 7)
                    .frame(width: 160, height: 160)

                // Progress ring (days active this week / 7)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        AngularGradient(
                            colors: [
                                palette.accent.opacity(0.6),
                                palette.accent,
                                palette.accent.opacity(0.8)
                            ],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: palette.accent.opacity(0.2), radius: 6, y: 2)

                // Inner content
                VStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(palette.accent)

                    Text("\(animatedStreak)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                        .contentTransition(.numericText())

                    Text("day streak")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                }
            }

            // Longest streak pill
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [palette.accent, palette.accent.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                Text("Longest: \(animatedLongest) days")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(palette.surfaceElevated)
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
            )
            .overlay(
                Capsule()
                    .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
            )

            Spacer(minLength: 8)
        }
        .frame(height: 300)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Week Activity Strip

    private var weekActivityStrip: some View {
        let today = Calendar.current.component(.weekday, from: Date())

        return VStack(alignment: .leading, spacing: 14) {
            Text("THIS WEEK")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(palette.textMuted)

            HStack(spacing: 0) {
                ForEach(Array(zip(dayLabels, dayWeekdays)), id: \.1) { label, weekday in
                    let isActive = vm.activeDays.contains(weekday)
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
                                            colors: [palette.accent, palette.accent.opacity(0.75)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                    .shadow(color: palette.accent.opacity(0.3), radius: 4, y: 2)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                            } else if isToday {
                                Circle()
                                    .stroke(palette.accent, lineWidth: 2)
                                    .frame(width: 36, height: 36)

                                Circle()
                                    .fill(palette.accent.opacity(0.08))
                                    .frame(width: 36, height: 36)
                            } else {
                                Circle()
                                    .fill(palette.surfaceElevated)
                                    .frame(width: 36, height: 36)
                                    .shadow(color: .black.opacity(0.03), radius: 3, y: 1)
                                    .overlay(
                                        Circle().stroke(palette.border.opacity(0.15), lineWidth: 0.5)
                                    )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(palette.surfaceElevated)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(palette.border.opacity(0.2), lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(BPAnimation.spring.delay(0.08), value: appeared)
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        let daysActive = vm.activeDays.count
        let totalActions = vm.chaptersReadTotal + vm.versesSavedTotal + vm.planDaysTotal + vm.aiChatsTotal

        return VStack(alignment: .leading, spacing: 14) {
            Text("INSIGHTS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(palette.textMuted)

            VStack(spacing: 12) {
                insightRow(
                    icon: "chart.line.uptrend.xyaxis",
                    text: daysActive >= 5
                        ? "Incredible week! You\u{2019}ve been active \(daysActive) out of 7 days."
                        : daysActive >= 3
                            ? "Good momentum! \(daysActive) active days this week."
                            : daysActive >= 1
                                ? "You showed up this week. Keep building the habit."
                                : "Start your journey today \u{2014} even one verse counts."
                )

                if vm.streakCount >= 7 {
                    insightRow(
                        icon: "flame.fill",
                        text: "Your \(vm.streakCount)-day streak shows real dedication. God sees your faithfulness."
                    )
                }

                if totalActions > 50 {
                    insightRow(
                        icon: "sparkles",
                        text: "You\u{2019}ve taken \(totalActions) faith actions. Your spiritual growth is compounding."
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(palette.surfaceElevated)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(palette.border.opacity(0.2), lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(BPAnimation.spring.delay(0.12), value: appeared)
    }

    private func insightRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.accent)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(palette.accent.opacity(0.1))
                )

            Text(text)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(palette.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ALL TIME")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(palette.textMuted)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                animatedStatCard(
                    icon: "book.fill",
                    count: animatedChapters,
                    label: "Chapters Read",
                    delay: 0.0
                )
                animatedStatCard(
                    icon: "bookmark.fill",
                    count: animatedVerses,
                    label: "Verses Saved",
                    delay: 0.06
                )
                animatedStatCard(
                    icon: "checkmark.circle.fill",
                    count: animatedPlans,
                    label: "Plan Days",
                    delay: 0.12
                )
                animatedStatCard(
                    icon: "bubble.left.fill",
                    count: animatedChats,
                    label: "AI Chats",
                    delay: 0.18
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(BPAnimation.spring.delay(0.16), value: appeared)
    }

    private func animatedStatCard(icon: String, count: Int, label: String, delay: Double) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.accent)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle().fill(palette.accent.opacity(0.1))
                    )

                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                        .contentTransition(.numericText())

                    Text(label)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(palette.border.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Monthly Heatmap

    private var monthlyHeatmap: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(currentMonthName.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(palette.textMuted)

                Spacer()

                // Legend
                HStack(spacing: 4) {
                    Text("Less")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textMuted)

                    ForEach([0, 1, 2, 4], id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatmapColor(for: level))
                            .frame(width: 10, height: 10)
                    }

                    Text("More")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                }
            }

            VStack(spacing: 3) {
                // Day labels
                HStack(spacing: 3) {
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.textMuted)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Calendar grid
                let cells = heatmapCells(from: vm.heatmapData)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 3) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(heatmapColor(for: cell.count))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                if let dayNum = cell.dayNumber {
                                    Text("\(dayNum)")
                                        .font(.system(size: 9, weight: cell.count > 0 ? .bold : .medium, design: .rounded))
                                        .foregroundStyle(cell.count > 0 ? .white : palette.textMuted)
                                }
                            }
                            .opacity(heatmapAppeared ? 1 : 0)
                            .scaleEffect(heatmapAppeared ? 1 : 0.5)
                            .animation(
                                .spring(response: 0.3, dampingFraction: 0.7).delay(Double(index) * 0.008),
                                value: heatmapAppeared
                            )
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(palette.surfaceElevated)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(palette.border.opacity(0.2), lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(BPAnimation.spring.delay(0.2), value: appeared)
    }

    // MARK: - Recent Activity

    private var recentActivityList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("RECENT ACTIVITY")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(palette.textMuted)

            if vm.recentActivity.isEmpty {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(palette.accent.opacity(0.06))
                            .frame(width: 90, height: 90)

                        Circle()
                            .fill(palette.accent.opacity(0.04))
                            .frame(width: 64, height: 64)

                        Image(systemName: "leaf")
                            .font(.system(size: 28, weight: .thin))
                            .foregroundStyle(palette.accent)
                    }

                    VStack(spacing: 8) {
                        Text("Your journey starts here")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.textPrimary)

                        Text("Read a chapter, save a verse, or write\na prayer to begin tracking your progress.")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(palette.textMuted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(palette.surfaceElevated)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(vm.recentActivity.prefix(12).enumerated()), id: \.element.id) { index, event in
                        activityRow(event, index: index, isLast: index == min(vm.recentActivity.count, 12) - 1)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(palette.surfaceElevated)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(palette.border.opacity(0.2), lineWidth: 0.5)
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(BPAnimation.spring.delay(0.24), value: appeared)
    }

    private func activityRow(_ event: ActivityEvent, index: Int, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline
            VStack(spacing: 0) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [palette.accent, palette.accent.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)

                if !isLast {
                    Rectangle()
                        .fill(palette.accent.opacity(0.15))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 8)

            // Icon
            Image(systemName: event.type.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.accent)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(palette.accent.opacity(0.1))
                )

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(event.type.displayName)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                if !event.detail.isEmpty {
                    Text(event.detail)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(relativeTime(event.createdAt))
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(palette.textMuted)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Animations

    private func startAnimations() {
        // Streak count-up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            animateCount(to: vm.streakCount, current: $animatedStreak, duration: 0.6)
            animateCount(to: vm.longestStreak, current: $animatedLongest, duration: 0.6)
        }

        // Ring animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let weekProgress = CGFloat(vm.activeDays.count) / 7.0
            withAnimation(.easeOut(duration: 1.0)) {
                ringProgress = weekProgress
            }
        }

        // Stats count-up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            animateCount(to: vm.chaptersReadTotal, current: $animatedChapters, duration: 0.5)
            animateCount(to: vm.versesSavedTotal, current: $animatedVerses, duration: 0.5)
            animateCount(to: vm.planDaysTotal, current: $animatedPlans, duration: 0.5)
            animateCount(to: vm.aiChatsTotal, current: $animatedChats, duration: 0.5)
        }

        // Heatmap staggered entrance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            heatmapAppeared = true
        }
    }

    private func animateCount(to target: Int, current: Binding<Int>, duration: Double) {
        guard target > 0 else { return }
        let steps = min(target, 15)
        let interval = duration / Double(steps)
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                withAnimation(.snappy(duration: 0.15)) {
                    current.wrappedValue = Int(Double(target) * Double(i) / Double(steps))
                }
            }
        }
    }

    // MARK: - Helpers

    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }

    private struct HeatmapCell {
        let dayNumber: Int?
        let count: Int
    }

    private func heatmapCells(from data: [Date: Int]) -> [HeatmapCell] {
        let calendar = Calendar.current
        let now = Date()
        let comps = calendar.dateComponents([.year, .month], from: now)
        guard let firstOfMonth = calendar.date(from: comps) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30

        var cells: [HeatmapCell] = []

        for _ in 0..<(firstWeekday - 1) {
            cells.append(HeatmapCell(dayNumber: nil, count: 0))
        }

        for day in 1...daysInMonth {
            let dateComps = DateComponents(year: comps.year, month: comps.month, day: day)
            let date = calendar.date(from: dateComps) ?? now
            let startOfDay = calendar.startOfDay(for: date)
            let count = data[startOfDay] ?? 0
            cells.append(HeatmapCell(dayNumber: day, count: count))
        }

        return cells
    }

    private func heatmapColor(for count: Int) -> Color {
        switch count {
        case 0: palette.surface
        case 1: palette.accent.opacity(0.3)
        case 2...3: palette.accent.opacity(0.6)
        default: palette.accent
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        let days = Int(interval / 86400)
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days)d ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Loading Placeholder

private struct ProgressIndicatorView: View {
    @Environment(\.bpPalette) private var palette

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(palette.accent.opacity(0.06))
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(palette.accent.opacity(0.04))
                    .frame(width: 72, height: 72)

                SwiftUI.ProgressView()
                    .tint(palette.accent)
                    .scaleEffect(1.1)
            }

            Text("Loading progress...")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textMuted)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
