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

    static let placeholder = HomeWidgetEntry(
        date: Date(),
        window: .gratitude,
        displayText: "The Lord is my shepherd; I shall not want.",
        verseReference: "Psalm 23:1",
        contentType: .verse,
        contentID: nil,
        backgroundGradient: SanctuaryBackground.allBackgrounds[0].gradientColors
    )
}

// MARK: - Provider

struct HomeWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomeWidgetEntry {
        .placeholder
    }

    func snapshot(for configuration: ContentTypeIntent, in context: Context) async -> HomeWidgetEntry {
        if context.isPreview { return .placeholder }

        let offset = WidgetBackgroundService.loadContentOffset()

        // Fast path: if user navigated (offset > 0) and cache is fresh, skip SwiftData entirely
        if offset > 0, let cached = WidgetContentProvider.cachedContentAtOffset(offset) {
            return entryFromCached(cached)
        }

        // Slow path: full SwiftData fetch
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

        let offset = WidgetBackgroundService.loadContentOffset()

        // Auto-reset offset when time window has changed (cache is stale)
        if offset > 0 {
            let existingCache = WidgetBackgroundService.loadContentCache()
            if existingCache == nil || existingCache!.isStale {
                WidgetBackgroundService.saveContentOffset(0)
            }
        }

        // Build + cache the deterministic content list (single SwiftData fetch)
        let cache = WidgetContentProvider.buildAndCacheContentList(
            profile: profile,
            modelContext: modelContext,
            allowedTypes: allowedTypes
        )

        // Background colors
        let bgColors = WidgetBackgroundService.loadGradientColors()
            ?? SanctuaryBackground.allBackgrounds[0].gradientColors

        var entries: [HomeWidgetEntry] = []

        // If user navigated, use cached item for the first (immediate) entry
        let currentOffset = WidgetBackgroundService.loadContentOffset()
        if currentOffset > 0, let cache, !cache.items.isEmpty {
            let index = currentOffset % cache.items.count
            let item = cache.items[index]
            entries.append(HomeWidgetEntry(
                date: Date(),
                window: WidgetTimeWindow.current(),
                displayText: item.displayText,
                verseReference: item.verseReference,
                contentType: ContentType(rawValue: item.contentType) ?? .verse,
                contentID: UUID(uuidString: item.id),
                backgroundGradient: bgColors
            ))
        }

        // Generate remaining timeline entries via single-fetch helper
        let widgetEntries = WidgetContentProvider.homeScreenTimelineEntries(
            profile: profile,
            modelContext: modelContext,
            allowedTypes: allowedTypes
        )

        let timelineEntries: [HomeWidgetEntry] = widgetEntries.map { entry in
            HomeWidgetEntry(
                date: entry.date,
                window: entry.window,
                displayText: entry.displayText,
                verseReference: entry.verseReference,
                contentType: entry.contentType,
                contentID: entry.contentID,
                backgroundGradient: bgColors
            )
        }

        // If we added a cached first entry, skip the first timeline entry (same timeslot)
        if !entries.isEmpty && !timelineEntries.isEmpty {
            entries.append(contentsOf: timelineEntries.dropFirst())
        } else {
            entries.append(contentsOf: timelineEntries)
        }

        // Reload after 24 hours
        let nextReload = Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? WidgetTimeWindow.nextTwoHourBoundary()
        return Timeline(entries: entries.isEmpty ? [.placeholder] : entries, policy: .after(nextReload))
    }

    // MARK: - Private

    /// Build entry from cached content (no SwiftData needed)
    private func entryFromCached(_ cached: CachedWidgetContent) -> HomeWidgetEntry {
        let bgColors = WidgetBackgroundService.loadGradientColors()
            ?? SanctuaryBackground.allBackgrounds[0].gradientColors

        return HomeWidgetEntry(
            date: Date(),
            window: WidgetTimeWindow.current(),
            displayText: cached.displayText,
            verseReference: cached.verseReference,
            contentType: ContentType(rawValue: cached.contentType) ?? .verse,
            contentID: UUID(uuidString: cached.id),
            backgroundGradient: bgColors
        )
    }

    /// Full SwiftData fetch for initial load (offset == 0) or stale cache
    private func currentEntry(allowedTypes: Set<ContentType>? = nil) -> HomeWidgetEntry? {
        guard let container = try? SharedModelContainer.create() else { return nil }
        let modelContext = ModelContext(container)
        let profileDescriptor = FetchDescriptor<UserProfile>()
        guard let profile = (try? modelContext.fetch(profileDescriptor))?.first else { return nil }

        let window = WidgetTimeWindow.current()

        let content = WidgetContentProvider.contentForWidget(
            window: window,
            profile: profile,
            modelContext: modelContext,
            allowedTypes: allowedTypes
        )

        guard let content else { return nil }

        let bgColors = WidgetBackgroundService.loadGradientColors()
            ?? SanctuaryBackground.allBackgrounds[0].gradientColors
        let text = WidgetContentProvider.personalizedText(template: content.templateText, firstName: profile.firstName)

        return HomeWidgetEntry(
            date: Date(),
            window: window,
            displayText: text,
            verseReference: content.verseReference,
            contentType: content.type,
            contentID: content.id,
            backgroundGradient: bgColors
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
                    WidgetBackgroundView(gradientColors: entry.backgroundGradient)
                }
        }
        .configurationDisplayName("Daily Inspiration")
        .description("Prayers, verses, and devotionals refreshed every 2 hours.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
