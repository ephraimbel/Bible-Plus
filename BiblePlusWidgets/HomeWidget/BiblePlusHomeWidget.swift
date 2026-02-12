import SwiftUI
import SwiftData
import WidgetKit

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

struct HomeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> HomeWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (HomeWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(currentEntry() ?? .placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HomeWidgetEntry>) -> Void) {
        guard let container = try? SharedModelContainer.create() else {
            let timeline = Timeline(entries: [HomeWidgetEntry.placeholder], policy: .after(WidgetTimeWindow.nextBoundary()))
            completion(timeline)
            return
        }

        let modelContext = ModelContext(container)
        let profileDescriptor = FetchDescriptor<UserProfile>()
        guard let profile = (try? modelContext.fetch(profileDescriptor))?.first else {
            let timeline = Timeline(entries: [HomeWidgetEntry.placeholder], policy: .after(WidgetTimeWindow.nextBoundary()))
            completion(timeline)
            return
        }

        let widgetEntries = WidgetContentProvider.timelineEntries(profile: profile, modelContext: modelContext)

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

        let nextReload = WidgetTimeWindow.nextBoundary()
        let timeline = Timeline(entries: entries.isEmpty ? [.placeholder] : entries, policy: .after(nextReload))
        completion(timeline)
    }

    private func currentEntry() -> HomeWidgetEntry? {
        guard let container = try? SharedModelContainer.create() else { return nil }
        let modelContext = ModelContext(container)
        let profileDescriptor = FetchDescriptor<UserProfile>()
        guard let profile = (try? modelContext.fetch(profileDescriptor))?.first else { return nil }

        let window = WidgetTimeWindow.current()
        guard let content = WidgetContentProvider.contentForWidget(
            window: window,
            profile: profile,
            modelContext: modelContext
        ) else { return nil }

        let background = SanctuaryBackground.background(for: profile.selectedBackgroundID)
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
        StaticConfiguration(kind: kind, provider: HomeWidgetProvider()) { entry in
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
        .description("Personalized prayers and verses that change throughout the day.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
