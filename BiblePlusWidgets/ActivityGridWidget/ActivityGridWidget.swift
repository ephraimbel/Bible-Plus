import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Entry

struct ActivityGridEntry: TimelineEntry {
    let date: Date
    let currentStreak: Int
    let activeDays: Set<Int> // weekday 1 (Sunday) through 7 (Saturday)
    let backgroundGradient: [String]
    let backgroundImageData: Data?

    static let placeholder = ActivityGridEntry(
        date: Date(),
        currentStreak: 5,
        activeDays: [2, 3, 4, 5, 6], // Mon-Fri
        backgroundGradient: SanctuaryBackground.allBackgrounds[0].gradientColors,
        backgroundImageData: nil
    )
}

// MARK: - Provider

struct ActivityGridProvider: TimelineProvider {
    func placeholder(in context: Context) -> ActivityGridEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ActivityGridEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ActivityGridEntry>) -> Void) {
        let entry = currentEntry()
        let nextReload = WidgetTimeWindow.startOfNextDay()
        completion(Timeline(entries: [entry], policy: .after(nextReload)))
    }

    /// Always returns an entry — never nil. Background comes from UserDefaults (App Group),
    /// streak/activity data comes from SwiftData. If SwiftData fails, uses defaults with
    /// the correct background.
    private func currentEntry() -> ActivityGridEntry {
        // Background: read from UserDefaults (App Group) — always reliable
        let bgColors = WidgetBackgroundService.loadGradientColors()
            ?? SanctuaryBackground.allBackgrounds[0].gradientColors
        let imageData = WidgetBackgroundService.loadWidgetBackgroundImageData()

        // Streak + activity data: read from SwiftData (best effort)
        var streak = 0
        var activeDays: Set<Int> = []

        if let container = try? SharedModelContainer.create() {
            let modelContext = ModelContext(container)
            let profileDescriptor = FetchDescriptor<UserProfile>()
            if let profile = (try? modelContext.fetch(profileDescriptor))?.first {
                streak = profile.streakCount
            }
            activeDays = fetchActiveDaysThisWeek(modelContext: modelContext)
        }

        return ActivityGridEntry(
            date: Date(),
            currentStreak: streak,
            activeDays: activeDays,
            backgroundGradient: bgColors,
            backgroundImageData: imageData
        )
    }

    private func fetchActiveDaysThisWeek(modelContext: ModelContext) -> Set<Int> {
        let cal = Calendar.current
        let now = Date()
        guard let startOfWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start else {
            return []
        }

        let descriptor = FetchDescriptor<ActivityEvent>(
            predicate: #Predicate { $0.createdAt >= startOfWeek }
        )
        guard let events = try? modelContext.fetch(descriptor) else { return [] }

        var days = Set<Int>()
        for event in events {
            let weekday = cal.component(.weekday, from: event.createdAt)
            days.insert(weekday)
        }
        return days
    }
}

// MARK: - Widget Configuration

struct ActivityGridWidget: Widget {
    let kind = "ActivityGridWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ActivityGridProvider()) { entry in
            ActivityGridWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackgroundView(
                        gradientColors: entry.backgroundGradient,
                        imageData: entry.backgroundImageData
                    )
                }
        }
        .configurationDisplayName("Weekly Activity")
        .description("See your streak and active days this week.")
        .supportedFamilies([.systemSmall])
    }
}
