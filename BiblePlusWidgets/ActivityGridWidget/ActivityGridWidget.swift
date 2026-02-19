import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Entry

struct ActivityGridEntry: TimelineEntry {
    let date: Date
    let currentStreak: Int
    let activeDays: Set<Int> // weekday 1 (Sunday) through 7 (Saturday)
    let hasActivityToday: Bool
    let backgroundGradient: [String]

    static let placeholder = ActivityGridEntry(
        date: Date(),
        currentStreak: 5,
        activeDays: [2, 3, 4, 5, 6], // Mon–Fri
        hasActivityToday: true,
        backgroundGradient: ["#C9A96E", "#8B6914"]
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
        completion(currentEntry() ?? .placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ActivityGridEntry>) -> Void) {
        let entry = currentEntry() ?? .placeholder
        let nextReload = WidgetTimeWindow.startOfNextDay()
        completion(Timeline(entries: [entry], policy: .after(nextReload)))
    }

    private func currentEntry() -> ActivityGridEntry? {
        guard let container = try? SharedModelContainer.create() else { return nil }
        let modelContext = ModelContext(container)

        let profileDescriptor = FetchDescriptor<UserProfile>()
        guard let profile = (try? modelContext.fetch(profileDescriptor))?.first else { return nil }

        let activeDays = fetchActiveDaysThisWeek(modelContext: modelContext)

        let hasActivityToday: Bool
        if let lastActive = profile.lastActiveDate {
            hasActivityToday = Calendar.current.isDateInToday(lastActive)
        } else {
            hasActivityToday = false
        }

        let effectiveBgID = profile.widgetSelectedBackgroundID ?? profile.selectedBackgroundID
        let background = SanctuaryBackground.background(for: effectiveBgID)
            ?? SanctuaryBackground.allBackgrounds[0]

        return ActivityGridEntry(
            date: Date(),
            currentStreak: profile.streakCount,
            activeDays: activeDays,
            hasActivityToday: hasActivityToday,
            backgroundGradient: background.gradientColors
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
                    LinearGradient(
                        colors: entry.backgroundGradient.map { Color(hex: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Weekly Activity")
        .description("See your streak and active days this week.")
        .supportedFamilies([.systemSmall])
    }
}
