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
    let backgroundImageData: Data?

    static let placeholder = StreakWidgetEntry(
        date: Date(),
        currentStreak: 7,
        longestStreak: 14,
        hasActivityToday: true,
        backgroundGradient: SanctuaryBackground.allBackgrounds[0].gradientColors,
        backgroundImageData: nil
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

        let effectiveBgID = profile.widgetSelectedBackgroundID ?? profile.selectedBackgroundID
        let background = SanctuaryBackground.background(for: effectiveBgID)
            ?? SanctuaryBackground.allBackgrounds[0]

        return StreakWidgetEntry(
            date: Date(),
            currentStreak: profile.streakCount,
            longestStreak: profile.longestStreak,
            hasActivityToday: hasActivityToday,
            backgroundGradient: background.gradientColors,
            backgroundImageData: WidgetBackgroundService.loadWidgetBackgroundImageData()
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
                    WidgetBackgroundView(
                        gradientColors: entry.backgroundGradient,
                        imageData: entry.backgroundImageData
                    )
                }
        }
        .configurationDisplayName("Days in the Word")
        .description("Track your daily faithfulness in scripture, prayer, and reflection.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}
