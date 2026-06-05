import SwiftUI
import SwiftData

// MARK: - Path Library
//
// The browsable home for every Daily Path. The daily flow only ever shows one
// active path at a time, which hides the real breadth of the catalog (22
// journeys / 300+ days). This screen makes that depth visible: an editorial
// header that states the scale, then the paths grouped into broad emotional
// themes so a user can find the journey that fits where they are. Each card
// reflects its live state (in progress / completed / Pro). Tapping opens the
// same PathDetailView the rest of the app uses.
struct PathLibraryView: View {
    let isPro: Bool

    @Environment(\.bpPalette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var allPaths: [DailyPath] = []
    @State private var allProgress: [UserPathProgress] = []
    @State private var appeared = false

    // MARK: - Themes
    //
    // Broad, emotionally-resonant groupings of the granular per-path
    // categories. Order is intentional (calming → harder seasons → faith →
    // purpose → relationships). Any path whose id isn't listed falls into the
    // "More Journeys" catch-all so new content is never hidden.
    private struct Theme: Identifiable {
        let title: String
        let blurb: String
        let pathIDs: [String]
        var id: String { title }
    }

    private static let themes: [Theme] = [
        Theme(title: "Peace & Rest",
              blurb: "Quiet for an anxious mind",
              pathIDs: ["peace-in-anxious-times", "facing-fear", "learning-to-rest", "content-with-what-i-have"]),
        Theme(title: "Healing & Hope",
              blurb: "Through the hard seasons",
              pathIDs: ["walking-through-grief", "healing-from-anger", "learning-to-forgive", "when-life-isnt-fair"]),
        Theme(title: "Identity & Belonging",
              blurb: "Who you are in Him",
              pathIDs: ["am-i-enough", "when-i-feel-alone", "breaking-free", "finding-joy-again"]),
        Theme(title: "Faith & Prayer",
              blurb: "Drawing closer to God",
              pathIDs: ["starting-faith", "learning-to-pray", "knowing-gods-word", "trusting-in-uncertainty", "hearing-god"]),
        Theme(title: "Purpose & Gratitude",
              blurb: "Living with meaning",
              pathIDs: ["walking-in-purpose", "a-grateful-heart"]),
        Theme(title: "Relationships",
              blurb: "Loving the people closest to you",
              pathIDs: ["hard-conversations", "stronger-marriage", "faithful-parenting"]),
    ]

    // MARK: - Derived data

    private var pathByID: [String: DailyPath] {
        Dictionary(allPaths.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Most recent progress row per path id.
    private var progressByPath: [String: UserPathProgress] {
        var map: [String: UserPathProgress] = [:]
        for p in allProgress {
            if let existing = map[p.pathID] {
                let a = p.lastActiveDate ?? .distantPast
                let b = existing.lastActiveDate ?? .distantPast
                if a > b { map[p.pathID] = p }
            } else {
                map[p.pathID] = p
            }
        }
        return map
    }

    private var totalDays: Int {
        allPaths.reduce(0) { $0 + $1.totalDays }
    }

    /// A rendered section: a theme plus the paths present for it, with its
    /// display order baked in (avoids tuple key-paths in ForEach).
    private struct ThemeGroup: Identifiable {
        let id: String
        let title: String
        let blurb: String
        let paths: [DailyPath]
        let order: Int
    }

    /// Themes that have paths present (in defined order), followed by a
    /// catch-all for any path not assigned to a theme so new content is never
    /// hidden.
    private var themeGroups: [ThemeGroup] {
        var groups: [ThemeGroup] = []
        for theme in Self.themes {
            let paths = theme.pathIDs.compactMap { pathByID[$0] }
            guard !paths.isEmpty else { continue }
            groups.append(ThemeGroup(id: theme.title, title: theme.title,
                                     blurb: theme.blurb, paths: paths, order: groups.count))
        }
        let assigned = Set(Self.themes.flatMap { $0.pathIDs })
        let leftovers = allPaths.filter { !assigned.contains($0.id) }.sorted { $0.name < $1.name }
        if !leftovers.isEmpty {
            groups.append(ThemeGroup(id: "More Journeys", title: "More Journeys",
                                     blurb: "Fresh paths to explore", paths: leftovers, order: groups.count))
        }
        return groups
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    header

                    ForEach(themeGroups) { group in
                        themeSection(group)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 44)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Journeys")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
            }
            .onAppear {
                reload()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(BPAnimation.spring) { appeared = true }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DAILY PATHS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2.6)
                .foregroundStyle(palette.accent)

            Text("Find your next journey")
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(allPaths.count) guided journeys · \(totalDays) days of devotionals, five quiet minutes at a time.")
                .font(.system(size: 15, design: .serif))
                .italic()
                .foregroundStyle(palette.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(BPAnimation.spring.delay(0.04), value: appeared)
    }

    // MARK: - Theme Section

    private func themeSection(_ group: ThemeGroup) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                // Editorial department numeral — large, faint gold serif. Adds
                // magazine-style structure and a gold thread without an icon.
                Text(String(format: "%02d", group.order + 1))
                    .font(.custom("Baskerville-SemiBold", size: 34))
                    .foregroundStyle(palette.accent.opacity(0.5))
                    .frame(minWidth: 30, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title)
                        .font(.system(size: 19, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                    Text(group.blurb)
                        .font(.system(size: 13, design: .serif))
                        .italic()
                        .foregroundStyle(palette.textMuted)
                }
            }

            VStack(spacing: 10) {
                ForEach(group.paths) { path in
                    NavigationLink {
                        pathDetailDestination(for: path)
                    } label: {
                        PathLibraryCard(
                            path: path,
                            progress: progressByPath[path.id],
                            isLockedForFree: path.isProOnly && !isPro,
                            palette: palette
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(BPAnimation.spring.delay(0.08 + Double(min(group.order, 6)) * 0.05), value: appeared)
    }

    // MARK: - Navigation

    @ViewBuilder
    private func pathDetailDestination(for path: DailyPath) -> some View {
        // Per-navigation VM so the detail view owns its state without leaking
        // back into the home CTA's VM (mirrors PathSettingsSheet).
        let vm = DailyPathHomeViewModel()
        PathDetailView(path: path, homeVM: vm, isPro: isPro)
            .onAppear {
                vm.loadSpecific(path: path, modelContext: modelContext)
            }
    }

    private func reload() {
        allPaths = (try? modelContext.fetch(FetchDescriptor<DailyPath>())) ?? []
        allProgress = (try? modelContext.fetch(FetchDescriptor<UserPathProgress>())) ?? []
    }
}

// MARK: - Path Library Card

private struct PathLibraryCard: View {
    let path: DailyPath
    let progress: UserPathProgress?
    let isLockedForFree: Bool
    let palette: BPColorPalette

    private var isCompleted: Bool { progress?.completedDate != nil }

    private var inProgress: Bool {
        guard let progress, progress.completedDate == nil else { return false }
        return !progress.completedDays.isEmpty
    }

    private var fraction: Double {
        progress?.completionFraction(totalDays: path.totalDays) ?? 0
    }

    private var dayLine: String {
        let next = progress?.nextDay(totalDays: path.totalDays) ?? 1
        return "Day \(next) of \(path.totalDays)"
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(path.name)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(isLockedForFree ? palette.textSecondary : palette.textPrimary)
                    .lineLimit(1)

                Text(path.pathDescription)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)

                metaLine
                    .padding(.top, 2)
            }

            Spacer(minLength: 8)

            trailing
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            inProgress ? palette.accent.opacity(0.35) : palette.border.opacity(0.4),
                            lineWidth: inProgress ? 1.0 : 0.6
                        )
                )
                .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
        )
        .opacity(isCompleted ? 0.82 : 1.0)
    }

    @ViewBuilder
    private var metaLine: some View {
        if inProgress {
            VStack(alignment: .leading, spacing: 4) {
                Text(dayLine)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(palette.accent)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(palette.border.opacity(0.35)).frame(height: 3)
                        Capsule().fill(palette.accent).frame(width: max(4, geo.size.width * CGFloat(fraction)), height: 3)
                    }
                }
                .frame(height: 3)
            }
        } else {
            Text("\(path.totalDays) days · about 5 minutes a day")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(palette.textMuted)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if isCompleted {
            badge("COMPLETED")
        } else if isLockedForFree {
            badge("PRO")
        } else {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.textMuted)
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .bold))
            .tracking(1.0)
            .foregroundStyle(palette.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(palette.accent.opacity(0.12)))
    }
}
