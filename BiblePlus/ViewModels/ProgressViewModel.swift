import Foundation
import SwiftData

@MainActor
@Observable
final class ProgressViewModel {

    // MARK: - State

    var streakCount: Int = 0
    var longestStreak: Int = 0
    var chaptersReadTotal: Int = 0
    var versesSavedTotal: Int = 0
    var planDaysTotal: Int = 0
    var aiChatsTotal: Int = 0
    var activeDays: Set<Int> = []
    var heatmapData: [Date: Int] = [:]
    var recentActivity: [ActivityEvent] = []

    private let modelContext: ModelContext

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadAll()
    }

    func loadAll() {
        let descriptor = FetchDescriptor<UserProfile>()
        if let profile = try? modelContext.fetch(descriptor).first {
            streakCount = profile.streakCount
            longestStreak = profile.longestStreak
        }

        chaptersReadTotal = ActivityService.totalCount(of: .chapterRead, in: modelContext)
            + ActivityService.totalCount(of: .audioChapterCompleted, in: modelContext)
        versesSavedTotal = ActivityService.totalCount(of: .verseSaved, in: modelContext)
        planDaysTotal = ActivityService.totalCount(of: .planDayCompleted, in: modelContext)
        aiChatsTotal = ActivityService.totalCount(of: .aiChatSent, in: modelContext)

        activeDays = ActivityService.activeDaysThisWeek(in: modelContext)
        heatmapData = ActivityService.heatmapData(days: 35, in: modelContext)
        recentActivity = ActivityService.recentActivity(limit: 15, in: modelContext)
    }
}
