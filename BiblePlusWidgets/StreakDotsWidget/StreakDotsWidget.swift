import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Entry

struct StreakDotsEntry: TimelineEntry {
    let date: Date
    let currentStreak: Int
    let activeDays: Set<Int> // Calendar weekday: 1=Sun..7=Sat

    static let placeholder = StreakDotsEntry(
        date: Date(),
        currentStreak: 5,
        activeDays: [2, 3, 4, 5, 6]
    )
}

// MARK: - Provider

struct StreakDotsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakDotsEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakDotsEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(currentEntry() ?? .placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakDotsEntry>) -> Void) {
        let entry = currentEntry() ?? .placeholder
        let nextReload = WidgetTimeWindow.startOfNextDay()
        completion(Timeline(entries: [entry], policy: .after(nextReload)))
    }

    private func currentEntry() -> StreakDotsEntry? {
        guard let container = try? SharedModelContainer.create() else { return nil }
        let modelContext = ModelContext(container)

        let profileDescriptor = FetchDescriptor<UserProfile>()
        guard let profile = (try? modelContext.fetch(profileDescriptor))?.first else { return nil }

        let activeDays = fetchActiveDaysThisWeek(modelContext: modelContext)

        return StreakDotsEntry(
            date: Date(),
            currentStreak: profile.streakCount,
            activeDays: activeDays
        )
    }

    private func fetchActiveDaysThisWeek(modelContext: ModelContext) -> Set<Int> {
        let cal = Calendar.current
        guard let startOfWeek = cal.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return []
        }

        let descriptor = FetchDescriptor<ActivityEvent>(
            predicate: #Predicate { $0.createdAt >= startOfWeek }
        )
        guard let events = try? modelContext.fetch(descriptor) else { return [] }

        var days = Set<Int>()
        for event in events {
            days.insert(cal.component(.weekday, from: event.createdAt))
        }
        return days
    }
}

// MARK: - Widget Configuration

struct StreakDotsWidget: Widget {
    let kind = "StreakDotsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakDotsProvider()) { entry in
            StreakDotsWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Streak & Week")
        .description("Your streak with daily activity dots on the lock screen.")
        .supportedFamilies([.accessoryRectangular])
    }
}
