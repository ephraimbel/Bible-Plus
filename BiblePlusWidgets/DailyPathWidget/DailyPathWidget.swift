import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Entry

struct DailyPathEntry: TimelineEntry {
    let date: Date
    let pathName: String?
    let themeLabel: String?
    let currentDay: Int
    let totalDays: Int
    let completedDays: [Int]
    let completionFraction: Double
    let pathID: String?
    let gradientColors: [String]
    let isEmpty: Bool

    static let placeholder = DailyPathEntry(
        date: Date(),
        pathName: "Peace in Anxious Times",
        themeLabel: "Trust before understanding",
        currentDay: 5,
        totalDays: 14,
        completedDays: [1, 2, 3, 4],
        completionFraction: 4.0 / 14.0,
        pathID: "peace-in-anxious-times",
        gradientColors: ["#C9A96E", "#8B7355"],
        isEmpty: false
    )

    static let empty = DailyPathEntry(
        date: Date(),
        pathName: nil,
        themeLabel: nil,
        currentDay: 0,
        totalDays: 14,
        completedDays: [],
        completionFraction: 0,
        pathID: nil,
        gradientColors: SanctuaryBackground.allBackgrounds[0].gradientColors,
        isEmpty: true
    )
}

// MARK: - Provider

struct DailyPathProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyPathEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyPathEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(currentEntry() ?? .empty)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyPathEntry>) -> Void) {
        let entry = currentEntry() ?? .empty
        let nextReload = WidgetTimeWindow.startOfNextDay()
        let timeline = Timeline(entries: [entry], policy: .after(nextReload))
        completion(timeline)
    }

    private func currentEntry() -> DailyPathEntry? {
        guard let container = try? SharedModelContainer.create() else { return nil }
        let modelContext = ModelContext(container)

        let progressDescriptor = FetchDescriptor<UserPathProgress>(
            predicate: #Predicate { $0.isActive == true && $0.completedDate == nil },
            sortBy: [SortDescriptor(\.lastActiveDate, order: .reverse)]
        )
        guard let progress = (try? modelContext.fetch(progressDescriptor))?.first else { return nil }

        let targetID = progress.pathID
        let pathDescriptor = FetchDescriptor<DailyPath>(
            predicate: #Predicate { $0.id == targetID }
        )
        guard let path = (try? modelContext.fetch(pathDescriptor))?.first else { return nil }

        let currentDay = progress.nextDay(totalDays: path.totalDays)
        let fraction = progress.completionFraction(totalDays: path.totalDays)
        let themeLabel = path.day(currentDay)?.themeLabel

        return DailyPathEntry(
            date: Date(),
            pathName: path.name,
            themeLabel: themeLabel,
            currentDay: currentDay,
            totalDays: path.totalDays,
            completedDays: progress.completedDays,
            completionFraction: fraction,
            pathID: path.id,
            gradientColors: path.gradientColors.isEmpty
                ? SanctuaryBackground.allBackgrounds[0].gradientColors
                : path.gradientColors,
            isEmpty: false
        )
    }
}

// MARK: - Widget Configuration

struct DailyPathWidget: Widget {
    let kind = "DailyPathWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyPathProvider()) { entry in
            DailyPathWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Daily Path")
        .description("Your next day on the journey — one tap to begin.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}
