import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Entry

struct DashboardEntry: TimelineEntry {
    let date: Date
    let currentStreak: Int
    let hasActivityToday: Bool
    let planName: String?
    let planFraction: Double
    let planNextDay: Int
    let chaptersRead: Int
    let versesSaved: Int
    let backgroundGradient: [String]
    let backgroundImageData: Data?

    static let placeholder = DashboardEntry(
        date: Date(),
        currentStreak: 12,
        hasActivityToday: true,
        planName: "Psalms of Peace",
        planFraction: 0.43,
        planNextDay: 4,
        chaptersRead: 8,
        versesSaved: 15,
        backgroundGradient: SanctuaryBackground.allBackgrounds[0].gradientColors,
        backgroundImageData: nil
    )
}

// MARK: - Provider

struct DashboardProvider: TimelineProvider {
    func placeholder(in context: Context) -> DashboardEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DashboardEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(currentEntry() ?? .placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DashboardEntry>) -> Void) {
        let entry = currentEntry() ?? .placeholder
        let nextReload = WidgetTimeWindow.nextTwoHourBoundary()
        completion(Timeline(entries: [entry], policy: .after(nextReload)))
    }

    private func currentEntry() -> DashboardEntry? {
        guard let container = try? SharedModelContainer.create() else { return nil }
        let modelContext = ModelContext(container)

        // Profile
        let profileDescriptor = FetchDescriptor<UserProfile>()
        guard let profile = (try? modelContext.fetch(profileDescriptor))?.first else { return nil }

        let hasActivityToday: Bool
        if let lastActive = profile.lastActiveDate {
            hasActivityToday = Calendar.current.isDateInToday(lastActive)
        } else {
            hasActivityToday = false
        }

        // Active reading plan
        var planName: String?
        var planFraction: Double = 0
        var planNextDay: Int = 0

        let progressDescriptor = FetchDescriptor<UserPlanProgress>(
            predicate: #Predicate { $0.isActive && $0.completedDate == nil }
        )
        if let progress = (try? modelContext.fetch(progressDescriptor))?.first {
            let targetPlanID = progress.planID
            let planDescriptor = FetchDescriptor<ReadingPlan>(
                predicate: #Predicate { $0.id == targetPlanID }
            )
            if let plan = (try? modelContext.fetch(planDescriptor))?.first {
                planName = plan.name
                planFraction = progress.completionFraction(totalDays: plan.totalDays)
                planNextDay = progress.nextDay(totalDays: plan.totalDays)
            }
        }

        // Count chapters read (all time)
        let chapterType = ActivityEventType.chapterRead.rawValue
        let chapterDescriptor = FetchDescriptor<ActivityEvent>(
            predicate: #Predicate { $0.typeRaw == chapterType }
        )
        let chaptersRead = (try? modelContext.fetch(chapterDescriptor))?.count ?? 0

        // Count verses saved (all time)
        let savedDescriptor = FetchDescriptor<SavedBibleVerse>()
        let versesSaved = (try? modelContext.fetch(savedDescriptor))?.count ?? 0

        // Background: read from UserDefaults (App Group) — always reliable
        let bgColors = WidgetBackgroundService.loadGradientColors()
            ?? SanctuaryBackground.allBackgrounds[0].gradientColors
        let imageData = WidgetBackgroundService.loadWidgetBackgroundImageData()

        return DashboardEntry(
            date: Date(),
            currentStreak: profile.streakCount,
            hasActivityToday: hasActivityToday,
            planName: planName,
            planFraction: planFraction,
            planNextDay: planNextDay,
            chaptersRead: chaptersRead,
            versesSaved: versesSaved,
            backgroundGradient: bgColors,
            backgroundImageData: imageData
        )
    }
}

// MARK: - Widget Configuration

struct DashboardWidget: Widget {
    let kind = "DashboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DashboardProvider()) { entry in
            DashboardWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackgroundView(
                        gradientColors: entry.backgroundGradient,
                        imageData: entry.backgroundImageData
                    )
                }
        }
        .configurationDisplayName("Faith Dashboard")
        .description("Your streak, reading, and plan progress at a glance.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}
