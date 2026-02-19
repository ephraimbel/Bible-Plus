import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Entry

struct StreakWidgetEntry: TimelineEntry {
    let date: Date
    let currentStreak: Int
    let longestStreak: Int
    let hasActivityToday: Bool
    let backgroundGradient: [String]

    static let placeholder = StreakWidgetEntry(
        date: Date(),
        currentStreak: 7,
        longestStreak: 14,
        hasActivityToday: true,
        backgroundGradient: ["#C9A96E", "#8B6914"]
    )
}

// MARK: - Provider

struct StreakWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(currentEntry() ?? .placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakWidgetEntry>) -> Void) {
        let entry = currentEntry() ?? .placeholder

        // Refresh at midnight so streak resets correctly
        let nextReload = WidgetTimeWindow.startOfNextDay()
        let timeline = Timeline(entries: [entry], policy: .after(nextReload))
        completion(timeline)
    }

    private func currentEntry() -> StreakWidgetEntry? {
        guard let container = try? SharedModelContainer.create() else { return nil }
        let modelContext = ModelContext(container)
        let profileDescriptor = FetchDescriptor<UserProfile>()
        guard let profile = (try? modelContext.fetch(profileDescriptor))?.first else { return nil }

        let hasActivityToday: Bool
        if let lastActive = profile.lastActiveDate {
            hasActivityToday = Calendar.current.isDateInToday(lastActive)
        } else {
            hasActivityToday = false
        }

        let background = SanctuaryBackground.background(for: profile.selectedBackgroundID)
            ?? SanctuaryBackground.allBackgrounds[0]

        return StreakWidgetEntry(
            date: Date(),
            currentStreak: profile.streakCount,
            longestStreak: profile.longestStreak,
            hasActivityToday: hasActivityToday,
            backgroundGradient: background.gradientColors
        )
    }
}

// MARK: - Widget Configuration

struct StreakWidget: Widget {
    let kind = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakWidgetProvider()) { entry in
            StreakWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: entry.backgroundGradient.map { Color(hex: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Daily Streak")
        .description("Track your daily streak and stay consistent.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}
