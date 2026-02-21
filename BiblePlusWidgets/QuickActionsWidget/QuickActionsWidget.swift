import SwiftUI
import WidgetKit

// MARK: - Entry

struct QuickActionsEntry: TimelineEntry {
    let date: Date
    let backgroundGradient: [String]
    let backgroundImageData: Data?

    static let placeholder = QuickActionsEntry(
        date: Date(),
        backgroundGradient: SanctuaryBackground.allBackgrounds[0].gradientColors,
        backgroundImageData: nil
    )
}

// MARK: - Provider

struct QuickActionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickActionsEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickActionsEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickActionsEntry>) -> Void) {
        let entry = currentEntry()
        let nextReload = WidgetTimeWindow.startOfNextDay()
        completion(Timeline(entries: [entry], policy: .after(nextReload)))
    }

    /// Always returns an entry. Background comes from UserDefaults (App Group) —
    /// no SwiftData needed for this widget since it only needs the background.
    private func currentEntry() -> QuickActionsEntry {
        let bgColors = WidgetBackgroundService.loadGradientColors()
            ?? SanctuaryBackground.allBackgrounds[0].gradientColors
        let imageData = WidgetBackgroundService.loadWidgetBackgroundImageData()

        return QuickActionsEntry(
            date: Date(),
            backgroundGradient: bgColors,
            backgroundImageData: imageData
        )
    }
}

// MARK: - Widget Configuration

struct QuickActionsWidget: Widget {
    let kind = "QuickActionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickActionsProvider()) { entry in
            QuickActionsWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Quick Actions")
        .description("Jump directly to Read, Plan, Ask, or Sanctuary.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
