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

    static let placeholder = DashboardEntry(
        date: Date(),
        currentStreak: 12,
        hasActivityToday: true,
        planName: "Psalms of Peace",
        planFraction: 0.43,
        planNextDay: 4,
        chaptersRead: 8,
        versesSaved: 15,
        backgroundGradient: ["#C9A96E", "#8B6914"]
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

        // Background
        let effectiveBgID = profile.widgetSelectedBackgroundID ?? profile.selectedBackgroundID
        let background = SanctuaryBackground.background(for: effectiveBgID)
            ?? SanctuaryBackground.allBackgrounds[0]

        return DashboardEntry(
            date: Date(),
            currentStreak: profile.streakCount,
            hasActivityToday: hasActivityToday,
            planName: planName,
            planFraction: planFraction,
            planNextDay: planNextDay,
            chaptersRead: chaptersRead,
            versesSaved: versesSaved,
            backgroundGradient: background.gradientColors
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
                    ZStack {
                        LinearGradient(
                            colors: entry.backgroundGradient.map { Color(hex: $0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        if let uiImage = WidgetBackgroundService.loadWidgetBackgroundImage() {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        RadialGradient(
                            colors: [Color.clear, Color.black.opacity(0.25)],
                            center: .center,
                            startRadius: 80,
                            endRadius: 250
                        )
                    }
                }
        }
        .configurationDisplayName("Faith Dashboard")
        .description("Your streak, reading, and plan progress at a glance.")
        .supportedFamilies([.systemMedium])
    }
}
