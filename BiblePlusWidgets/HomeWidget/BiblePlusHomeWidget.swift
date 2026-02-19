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

        let entries: [HomeWidgetEntry] = widgetEntries.map { entry in
            HomeWidgetEntry(
                date: entry.date,
                window: entry.window,
                displayText: entry.displayText,
                verseReference: entry.verseReference,
                contentType: entry.contentType,
                contentID: entry.contentID,
                backgroundGradient: entry.backgroundGradient
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
        guard let content = WidgetContentProvider.contentForWidget(
            window: window,
            profile: profile,
            modelContext: modelContext,
            allowedTypes: allowedTypes
        ) else { return nil }

        let effectiveBgID = profile.widgetSelectedBackgroundID ?? profile.selectedBackgroundID
        let background = SanctuaryBackground.background(for: effectiveBgID)
            ?? SanctuaryBackground.allBackgrounds[0]
        let text = WidgetContentProvider.personalizedText(template: content.templateText, firstName: profile.firstName)

        return HomeWidgetEntry(
            date: Date(),
            window: window,
            displayText: text,
            verseReference: content.verseReference,
            contentType: content.type,
            contentID: content.id,
            backgroundGradient: background.gradientColors
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
                    ZStack {
                        // Gradient base (always present as fallback)
                        LinearGradient(
                            colors: entry.backgroundGradient.map { Color(hex: $0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        // Background image from shared container (video frame or static image)
                        if let uiImage = WidgetBackgroundService.loadWidgetBackgroundImage() {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }

                        // Subtle vignette for text readability
                        RadialGradient(
                            colors: [Color.clear, Color.black.opacity(0.25)],
                            center: .center,
                            startRadius: 80,
                            endRadius: 250
                        )
                    }
                }
        }
        .configurationDisplayName("Daily Inspiration")
        .description("Prayers, verses, and devotionals refreshed every 2 hours.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
