import Foundation
import SwiftData

@MainActor
@Observable
final class DailyPathHomeViewModel {
    var activePath: DailyPath?
    var progress: UserPathProgress?

    var currentDay: Int {
        guard let path = activePath else { return 1 }
        guard let progress else { return 1 }
        return progress.nextDay(totalDays: path.totalDays)
    }

    var completedDayNumbers: [Int] {
        progress?.completedDays ?? []
    }

    var totalDays: Int {
        activePath?.totalDays ?? 14
    }

    var pathTitle: String {
        activePath?.name ?? "Begin your path"
    }

    /// Theme of the day the user is currently on — the specific devotional
    /// topic shown beneath the series title on the home card.
    var currentDayTitle: String {
        activePath?.day(currentDay)?.themeLabel ?? ""
    }

    var hasStarted: Bool {
        progress != nil
    }

    /// True when the user has already finished a new day today and the path
    /// isn't fully complete — the home CTA shows a calm "back tomorrow" state.
    var completedToday: Bool {
        guard let progress, progress.completedDate == nil else { return false }
        return progress.completedNewDayToday()
    }

    /// Resolve the home CTA state. Reads the user's active UserPathProgress
    /// (if any) and the path it points to; otherwise recommends a path based
    /// on the user's profile (burden match 3x, season match 2x — same
    /// weights as FeedEngine for consistency).
    func refresh(modelContext: ModelContext, profile: UserProfile?) {
        let progressDescriptor = FetchDescriptor<UserPathProgress>(
            predicate: #Predicate { $0.isActive == true && $0.completedDate == nil },
            sortBy: [SortDescriptor(\.lastActiveDate, order: .reverse)]
        )
        let activeProgress = (try? modelContext.fetch(progressDescriptor)) ?? []

        if let first = activeProgress.first {
            let pathID = first.pathID
            let pathDescriptor = FetchDescriptor<DailyPath>(
                predicate: #Predicate { $0.id == pathID }
            )
            self.activePath = try? modelContext.fetch(pathDescriptor).first
            self.progress = first
            return
        }

        self.progress = nil
        self.activePath = Self.recommendPath(for: profile, modelContext: modelContext)
    }

    /// Bind this VM to a specific path (not whatever the home CTA would
    /// pick). Used by Settings → Daily Path so the user can drive any path
    /// — active, completed, or unstarted — through the same PathDetailView
    /// without having to first make it the home-selected path. Progress is
    /// hydrated if it exists for this path; otherwise left nil so the
    /// detail view shows the "Begin Day 1" CTA.
    func loadSpecific(path: DailyPath, modelContext: ModelContext) {
        self.activePath = path
        let pathID = path.id
        let progressDescriptor = FetchDescriptor<UserPathProgress>(
            predicate: #Predicate { $0.pathID == pathID && $0.completedDate == nil },
            sortBy: [SortDescriptor(\.lastActiveDate, order: .reverse)]
        )
        self.progress = (try? modelContext.fetch(progressDescriptor))?.first
    }

    /// Lazily create a UserPathProgress for the active path. Called when the
    /// user first taps into the path (opening PathDetailView or starting a
    /// day) so we don't write a progress row for users who only glance at
    /// the CTA without engaging. The first creation fires path_started for
    /// the conversion funnel; subsequent calls are no-ops (already started).
    @discardableResult
    func ensureProgress(modelContext: ModelContext) -> UserPathProgress? {
        if let progress { return progress }
        guard let path = activePath else { return nil }
        let new = UserPathProgress(pathID: path.id)
        modelContext.insert(new)
        try? modelContext.save()
        self.progress = new
        Analytics.track(.pathStarted, properties: [
            "path_id": path.id,
            "path_name": path.name,
            "total_days": "\(path.totalDays)"
        ])
        // Schedule the daily reminder so the habit loop kicks in immediately.
        NotificationService.shared.refreshDailyPathReminder(modelContext: modelContext)
        return new
    }

    private static func recommendPath(for profile: UserProfile?, modelContext: ModelContext) -> DailyPath? {
        let descriptor = FetchDescriptor<DailyPath>()
        guard let allPaths = try? modelContext.fetch(descriptor), !allPaths.isEmpty else {
            return nil
        }

        // Exclude paths the user has already finished. Without this, after
        // finishing the Anxiety path a user with the anxiety burden would be
        // re-recommended that same path on the very next refresh, which feels
        // like the app forgot what they just did.
        let completedDescriptor = FetchDescriptor<UserPathProgress>(
            predicate: #Predicate { $0.completedDate != nil }
        )
        let completedIDs = Set(((try? modelContext.fetch(completedDescriptor)) ?? []).map { $0.pathID })

        let unfinished = allPaths.filter { !completedIDs.contains($0.id) }
        let pool = unfinished.isEmpty ? allPaths : unfinished

        let candidates = (profile?.isPro ?? false) ? pool : pool.filter { !$0.isProOnly }
        guard !candidates.isEmpty else { return pool.first }
        guard let profile else { return candidates.first }

        let burdens = Set(profile.currentBurdens.map { $0.rawValue })
        let seasons = Set(profile.lifeSeasons.map { $0.rawValue })

        let scored: [(DailyPath, Int)] = candidates.map { path in
            let burdenMatch = Set(path.applicableBurdens).intersection(burdens).count
            let seasonMatch = Set(path.applicableSeasons).intersection(seasons).count
            return (path, burdenMatch * 3 + seasonMatch * 2)
        }
        return scored.max(by: { $0.1 < $1.1 })?.0 ?? candidates.first
    }
}
