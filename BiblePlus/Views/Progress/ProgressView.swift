import SwiftUI
import SwiftData

struct MyProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ProgressViewModel?
    @State private var showContent = false

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    progressContent(vm)
                } else {
                    ProgressIndicatorView()
                }
            }
            .background(palette.background)
            .navigationTitle("My Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(palette.textMuted)
                    }
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = ProgressViewModel(modelContext: modelContext)
                }
                withAnimation(BPAnimation.spring.delay(0.15)) {
                    showContent = true
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func progressContent(_ vm: ProgressViewModel) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                streakHeader(vm)
                weekDotsRow(vm)
                statsGrid(vm)
                monthlyHeatmap(vm)
                recentActivityList(vm)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    // MARK: - 1. Streak Header

    private func streakHeader(_ vm: ProgressViewModel) -> some View {
        HStack(spacing: 14) {
            // Current streak
            VStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(palette.accent)

                Text("\(vm.streakCount)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Text("Current Streak")
                    .font(BPFont.caption)
                    .foregroundStyle(palette.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(palette.surface)
            )

            // Longest streak
            VStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(palette.accent)

                Text("\(vm.longestStreak)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Text("Longest Streak")
                    .font(BPFont.caption)
                    .foregroundStyle(palette.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(palette.surface)
            )
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 10)
    }

    // MARK: - 2. This Week

    private func weekDotsRow(_ vm: ProgressViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THIS WEEK")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(palette.textMuted)

            HStack(spacing: 0) {
                ForEach(weekDays, id: \.weekday) { item in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(vm.activeDays.contains(item.weekday) ? palette.accent : palette.surface)
                            .frame(width: 32, height: 32)
                            .overlay {
                                if vm.activeDays.contains(item.weekday) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }

                        Text(item.label)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(palette.surface)
            )
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 10)
        .animation(BPAnimation.spring.delay(0.05), value: showContent)
    }

    private var weekDays: [(weekday: Int, label: String)] {
        // Sunday = 1 in Calendar, but display Mon-Sun
        [
            (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S"), (1, "S")
        ]
    }

    // MARK: - 3. Stats Grid

    private func statsGrid(_ vm: ProgressViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ALL TIME")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(palette.textMuted)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ], spacing: 14) {
                statCard(icon: "book.fill", count: vm.chaptersReadTotal, label: "Chapters Read", index: 0)
                statCard(icon: "bookmark.fill", count: vm.versesSavedTotal, label: "Verses Saved", index: 1)
                statCard(icon: "checkmark.circle.fill", count: vm.planDaysTotal, label: "Plan Days", index: 2)
                statCard(icon: "bubble.left.fill", count: vm.aiChatsTotal, label: "AI Chats", index: 3)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 10)
        .animation(BPAnimation.spring.delay(0.1), value: showContent)
    }

    private func statCard(icon: String, count: Int, label: String, index: Int) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(palette.accent)

            Text("\(count)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(palette.textPrimary)

            Text(label)
                .font(BPFont.caption)
                .foregroundStyle(palette.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(palette.surface)
        )
    }

    // MARK: - 4. Monthly Heatmap

    private func monthlyHeatmap(_ vm: ProgressViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currentMonthName.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(palette.textMuted)

            VStack(spacing: 4) {
                // Day labels
                HStack(spacing: 4) {
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.textMuted)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Calendar grid
                let cells = heatmapCells(from: vm.heatmapData)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(cells.indices, id: \.self) { index in
                        let cell = cells[index]
                        RoundedRectangle(cornerRadius: 4)
                            .fill(heatmapColor(for: cell.count))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                if let dayNum = cell.dayNumber {
                                    Text("\(dayNum)")
                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                        .foregroundStyle(cell.count > 0 ? .white : palette.textMuted)
                                }
                            }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(palette.surface)
            )
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 10)
        .animation(BPAnimation.spring.delay(0.15), value: showContent)
    }

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

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) // 1=Sunday
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30

        var cells: [HeatmapCell] = []

        // Leading empty cells
        for _ in 0..<(firstWeekday - 1) {
            cells.append(HeatmapCell(dayNumber: nil, count: 0))
        }

        // Day cells
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
        case 0: palette.background
        case 1: palette.accent.opacity(0.3)
        case 2...3: palette.accent.opacity(0.6)
        default: palette.accent
        }
    }

    // MARK: - 5. Recent Activity

    private func recentActivityList(_ vm: ProgressViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT ACTIVITY")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(palette.textMuted)

            if vm.recentActivity.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "leaf")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(palette.textMuted)

                    Text("Your journey starts here")
                        .font(BPFont.body)
                        .foregroundStyle(palette.textMuted)

                    Text("Read a chapter, save a verse, or ask the AI companion to get started.")
                        .font(BPFont.caption)
                        .foregroundStyle(palette.textMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(palette.surface)
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(vm.recentActivity.enumerated()), id: \.element.id) { index, event in
                        activityRow(event, isLast: index == vm.recentActivity.count - 1)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(palette.surface)
                )
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 10)
        .animation(BPAnimation.spring.delay(0.2), value: showContent)
    }

    private func activityRow(_ event: ActivityEvent, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline dot + line
            VStack(spacing: 0) {
                Circle()
                    .fill(palette.accent)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)

                if !isLast {
                    Rectangle()
                        .fill(palette.accent.opacity(0.2))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 8)

            // Icon
            Image(systemName: event.type.icon)
                .font(.system(size: 14))
                .foregroundStyle(palette.accent)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(palette.accentSoft)
                )

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(event.type.displayName)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                if !event.detail.isEmpty {
                    Text(event.detail)
                        .font(BPFont.caption)
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
    var body: some View {
        SwiftUI.ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
