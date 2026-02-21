import SwiftUI
import SwiftData
import WidgetKit
import AppIntents

// MARK: - Entry

struct HomeWidgetEntry: TimelineEntry {
    let date: Date
    let window: WidgetTimeWindow
    let displayText: String
    let verseReference: String?
    let contentType: ContentType
    let contentID: UUID?
    let backgroundGradient: [String]
    let backgroundImageData: Data?

    static let placeholder = HomeWidgetEntry(
        date: Date(),
        window: .gratitude,
        displayText: "The Lord is my shepherd; I shall not want.",
        verseReference: "Psalm 23:1",
        contentType: .verse,
        contentID: nil,
        backgroundGradient: SanctuaryBackground.allBackgrounds[0].gradientColors,
        backgroundImageData: nil
    )
}

// MARK: - Provider

struct HomeWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomeWidgetEntry {
        .placeholder
    }

    func snapshot(for configuration: ContentTypeIntent, in context: Context) async -> HomeWidgetEntry {
        if context.isPreview { return .placeholder }
        return currentEntry(allowedTypes: configuration.contentType.allowedContentTypes) ?? .placeholder
    }

    func timeline(for configuration: ContentTypeIntent, in context: Context) async -> Timeline<HomeWidgetEntry> {
        let allowedTypes = configuration.contentType.allowedContentTypes

        guard let container = try? SharedModelContainer.create() else {
            return Timeline(entries: [.placeholder], policy: .after(WidgetTimeWindow.nextTwoHourBoundary()))
        }

        let modelContext = ModelContext(container)
        let profileDescriptor = FetchDescriptor<UserProfile>()
        guard let profile = (try? modelContext.fetch(profileDescriptor))?.first else {
            return Timeline(entries: [.placeholder], policy: .after(WidgetTimeWindow.nextTwoHourBoundary()))
        }

        // 2-hour rotation with mixed content (verses, prayers, quotes, devotionals)
        let widgetEntries = WidgetContentProvider.homeScreenTimelineEntries(
            profile: profile,
            modelContext: modelContext,
            allowedTypes: allowedTypes
        )

        // Background: read from UserDefaults (App Group) — always reliable
        let bgColors = WidgetBackgroundService.loadGradientColors()
            ?? SanctuaryBackground.allBackgrounds[0].gradientColors
        let imageData = WidgetBackgroundService.loadWidgetBackgroundImageData()
        let entries: [HomeWidgetEntry] = widgetEntries.map { entry in
            HomeWidgetEntry(
                date: entry.date,
                window: entry.window,
                displayText: entry.displayText,
                verseReference: entry.verseReference,
                contentType: entry.contentType,
                contentID: entry.contentID,
                backgroundGradient: bgColors,
                backgroundImageData: imageData
            )
        }

        // Reload after the last entry expires (or 24 hours from now)
        let nextReload = Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? WidgetTimeWindow.nextTwoHourBoundary()
        return Timeline(entries: entries.isEmpty ? [.placeholder] : entries, policy: .after(nextReload))
    }

    private func currentEntry(allowedTypes: Set<ContentType>? = nil) -> HomeWidgetEntry? {
        guard let container = try? SharedModelContainer.create() else { return nil }
        let modelContext = ModelContext(container)
        let profileDescriptor = FetchDescriptor<UserProfile>()
        guard let profile = (try? modelContext.fetch(profileDescriptor))?.first else { return nil }

        let window = WidgetTimeWindow.current()
        let offset = WidgetBackgroundService.loadContentOffset()

        let content: PrayerContent?
        if offset > 0 {
            content = WidgetContentProvider.contentForWidgetWithOffset(
                offset: offset,
                window: window,
                profile: profile,
                modelContext: modelContext,
                allowedTypes: allowedTypes
            )
        } else {
            content = WidgetContentProvider.contentForWidget(
                window: window,
                profile: profile,
                modelContext: modelContext,
                allowedTypes: allowedTypes
            )
        }

        guard let content else { return nil }

        // Background: read from UserDefaults (App Group) — always reliable
        let bgColors = WidgetBackgroundService.loadGradientColors()
            ?? SanctuaryBackground.allBackgrounds[0].gradientColors
        let imageData = WidgetBackgroundService.loadWidgetBackgroundImageData()
        let text = WidgetContentProvider.personalizedText(template: content.templateText, firstName: profile.firstName)

        return HomeWidgetEntry(
            date: Date(),
            window: window,
            displayText: text,
            verseReference: content.verseReference,
            contentType: content.type,
            contentID: content.id,
            backgroundGradient: bgColors,
            backgroundImageData: imageData
        )
    }
}

// MARK: - Widget Configuration

struct BiblePlusHomeWidget: Widget {
    let kind = "BiblePlusHomeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ContentTypeIntent.self, provider: HomeWidgetProvider()) { entry in
            HomeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackgroundView(
                        gradientColors: entry.backgroundGradient,
                        imageData: entry.backgroundImageData
                    )
                }
        }
        .configurationDisplayName("Daily Inspiration")
        .description("Prayers, verses, and devotionals refreshed every 2 hours.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
