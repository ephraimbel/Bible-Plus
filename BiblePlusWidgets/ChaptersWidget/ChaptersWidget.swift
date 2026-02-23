import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Entry

struct ChaptersWidgetEntry: TimelineEntry {
    let date: Date
    let chaptersThisWeek: Int
    let weeklyGoal: Int
    let backgroundGradient: [String]
    let backgroundImageData: Data?

    static let placeholder = ChaptersWidgetEntry(
        date: Date(),
        chaptersThisWeek: 4,
        weeklyGoal: 7,
        backgroundGradient: SanctuaryBackground.allBackgrounds[0].gradientColors,
        backgroundImageData: nil
    )
}

// MARK: - Provider

struct ChaptersWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChaptersWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ChaptersWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(currentEntry() ?? .placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChaptersWidgetEntry>) -> Void) {
        let entry = currentEntry() ?? .placeholder
        let nextReload = WidgetTimeWindow.startOfNextDay()
        completion(Timeline(entries: [entry], policy: .after(nextReload)))
    }

    private func currentEntry() -> ChaptersWidgetEntry? {
        guard let container = try? SharedModelContainer.create() else { return nil }
        let modelContext = ModelContext(container)

        let cal = Calendar.current
        guard let startOfWeek = cal.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return nil
        }

        let chapterType = ActivityEventType.chapterRead.rawValue
        let descriptor = FetchDescriptor<ActivityEvent>(
            predicate: #Predicate { $0.createdAt >= startOfWeek && $0.typeRaw == chapterType }
        )
        let count = (try? modelContext.fetch(descriptor))?.count ?? 0

        // Background: read from UserDefaults (App Group)
        let bgColors = WidgetBackgroundService.loadGradientColors()
            ?? SanctuaryBackground.allBackgrounds[0].gradientColors
        let imageData = WidgetBackgroundService.loadWidgetBackgroundImageData()

        return ChaptersWidgetEntry(
            date: Date(),
            chaptersThisWeek: count,
            weeklyGoal: 7,
            backgroundGradient: bgColors,
            backgroundImageData: imageData
        )
    }
}

// MARK: - Widget Configuration

struct ChaptersWidget: Widget {
    let kind = "ChaptersWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChaptersWidgetProvider()) { entry in
            ChaptersWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Chapters Read")
        .description("Track chapters read this week.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
        .contentMarginsDisabled()
    }
}
