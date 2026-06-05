import SwiftUI
import SwiftData

// MARK: - Path Settings Sheet
//
// Path-management surface presented from Settings → Daily Path. Lists every
// path in the bundle, labels their state (Active / Completed / Pro-locked /
// Unstarted), and lets the user drive any of them through the same
// PathDetailView. Switching between paths is implicit — opening a different
// path just makes it the most-recently-active and home will pick it up.
//
// This view is intentionally read-mostly. The destructive actions (restart,
// abandon) live inside the detail view itself, where the user has full
// context for what they're undoing.

struct PathSettingsSheet: View {
    let isPro: Bool

    @Environment(\.bpPalette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var allPaths: [DailyPath] = []
    @State private var allProgress: [UserPathProgress] = []

    private var activePaths: [(DailyPath, UserPathProgress)] {
        allProgress
            .filter { $0.isActive && $0.completedDate == nil }
            .compactMap { p in allPaths.first(where: { $0.id == p.pathID }).map { ($0, p) } }
            .sorted { $0.1.lastActiveDate ?? .distantPast > $1.1.lastActiveDate ?? .distantPast }
    }

    private var completedPathIDs: Set<String> {
        Set(allProgress.filter { $0.completedDate != nil }.map { $0.pathID })
    }

    private var activePathIDs: Set<String> {
        Set(allProgress.filter { $0.isActive && $0.completedDate == nil }.map { $0.pathID })
    }

    private var browsePaths: [DailyPath] {
        // Sort: unstarted free first, then unstarted Pro, then completed.
        // Active paths show in their own section above, so we exclude them
        // here to avoid double-rendering.
        let nonActive = allPaths.filter { !activePathIDs.contains($0.id) }
        return nonActive.sorted { a, b in
            let aCompleted = completedPathIDs.contains(a.id)
            let bCompleted = completedPathIDs.contains(b.id)
            if aCompleted != bCompleted { return !aCompleted }
            if a.isProOnly != b.isProOnly { return !a.isProOnly }
            return a.name < b.name
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if !activePaths.isEmpty {
                        activeSection
                    }
                    browseSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Daily Path")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
            }
            .onAppear { reload() }
        }
    }

    private func reload() {
        allPaths = (try? modelContext.fetch(FetchDescriptor<DailyPath>())) ?? []
        allProgress = (try? modelContext.fetch(FetchDescriptor<UserPathProgress>())) ?? []
    }

    // MARK: - Sections

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("IN PROGRESS")

            VStack(spacing: 10) {
                ForEach(activePaths, id: \.0.id) { (path, progress) in
                    NavigationLink {
                        pathDetailDestination(for: path)
                    } label: {
                        ActivePathRow(
                            path: path,
                            progress: progress,
                            palette: palette
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var browseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("ALL PATHS")

            VStack(spacing: 10) {
                ForEach(browsePaths) { path in
                    NavigationLink {
                        pathDetailDestination(for: path)
                    } label: {
                        BrowsePathRow(
                            path: path,
                            isCompleted: completedPathIDs.contains(path.id),
                            isLockedForFree: path.isProOnly && !isPro,
                            palette: palette
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.8)
            .foregroundStyle(palette.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func pathDetailDestination(for path: DailyPath) -> some View {
        // Per-navigation VM so the detail view has its own state without
        // leaking back into the home CTA's VM. After the user navigates
        // away, the home dashboard's onAppear refresh picks up any new
        // progress they created here.
        let vm = DailyPathHomeViewModel()
        PathDetailView(path: path, homeVM: vm, isPro: isPro)
            .onAppear {
                vm.loadSpecific(path: path, modelContext: modelContext)
            }
    }
}

// MARK: - Active Path Row

private struct ActivePathRow: View {
    let path: DailyPath
    let progress: UserPathProgress
    let palette: BPColorPalette

    private var gradientColors: [Color] {
        path.gradientColors.isEmpty
            ? [palette.accent, palette.accent.opacity(0.6)]
            : path.gradientColors.map { Color(hex: $0) }
    }

    private var fraction: Double {
        progress.completionFraction(totalDays: path.totalDays)
    }

    private var dayLine: String {
        let next = progress.nextDay(totalDays: path.totalDays)
        return "Day \(next) of \(path.totalDays)"
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .shadow(color: gradientColors.first?.opacity(0.35) ?? .clear, radius: 8)

                Image(systemName: path.iconName.isEmpty ? "leaf.fill" : path.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(path.name)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)

                Text(dayLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textSecondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(palette.border.opacity(0.3))
                            .frame(height: 3)
                        Capsule()
                            .fill(palette.accent)
                            .frame(width: geo.size.width * CGFloat(fraction), height: 3)
                    }
                }
                .frame(height: 3)
                .padding(.top, 2)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.textMuted)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(palette.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(palette.accent.opacity(0.35), lineWidth: 0.8)
                )
        )
    }
}

// MARK: - Browse Path Row

private struct BrowsePathRow: View {
    let path: DailyPath
    let isCompleted: Bool
    let isLockedForFree: Bool
    let palette: BPColorPalette

    private var stateBadge: (String, Color)? {
        if isCompleted { return ("COMPLETED", palette.accent) }
        if isLockedForFree { return ("PRO", palette.accent) }
        return nil
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(palette.accent.opacity(isLockedForFree ? 0.08 : 0.14))
                    .frame(width: 40, height: 40)

                Image(systemName: isLockedForFree
                      ? "lock.fill"
                      : (path.iconName.isEmpty ? "leaf.fill" : path.iconName))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(path.name)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(isLockedForFree ? palette.textSecondary : palette.textPrimary)
                    .lineLimit(1)

                Text("\(path.totalDays) days · \(path.pathDescription)")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let (badge, color) = stateBadge {
                Text(badge)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(color.opacity(0.12))
                    )
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textMuted)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(palette.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(palette.border.opacity(0.3), lineWidth: 0.5)
                )
        )
        .opacity(isCompleted ? 0.78 : 1.0)
    }
}
