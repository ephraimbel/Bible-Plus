import SwiftUI
import SwiftData
import WidgetKit
import AppIntents

// MARK: - Entry

struct LockScreenWidgetEntry: TimelineEntry {
    let date: Date
    let shortText: String  // <=40 chars for inline
    let displayText: String
    let verseReference: String?
    let contentID: UUID?

    static let placeholder = LockScreenWidgetEntry(
        date: Date(),
        shortText: "The Lord is my shepherd",
        displayText: "The Lord is my shepherd; I shall not want.",
        verseReference: "Psalm 23:1",
        contentID: nil
    )
}

// MARK: - Provider

struct LockScreenWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LockScreenWidgetEntry {
        .placeholder
    }

    func snapshot(for configuration: ContentTypeIntent, in context: Context) async -> LockScreenWidgetEntry {
        if context.isPreview { return .placeholder }
        return currentEntry(allowedTypes: configuration.contentType.allowedContentTypes) ?? .placeholder
    }

    func timeline(for configuration: ContentTypeIntent, in context: Context) async -> Timeline<LockScreenWidgetEntry> {
        let allowedTypes = configuration.contentType.allowedContentTypes

        guard let container = try? SharedModelContainer.create() else {
            return Timeline(entries: [.placeholder], policy: .after(WidgetTimeWindow.startOfNextDay()))
        }

        let modelContext = ModelContext(container)
        let profileDescriptor = FetchDescriptor<UserProfile>()
        guard let profile = (try? modelContext.fetch(profileDescriptor))?.first else {
            return Timeline(entries: [.placeholder], policy: .after(WidgetTimeWindow.startOfNextDay()))
        }

        // Single verse of the day — stays all day, refreshes at midnight
        var entries: [LockScreenWidgetEntry] = []

        if let votd = WidgetContentProvider.dailyInspirationEntry(
            profile: profile,
            modelContext: modelContext,
            allowedTypes: allowedTypes
        ) {
            entries.append(LockScreenWidgetEntry(
                date: Date(),
                shortText: votd.shortText,
                displayText: votd.displayText,
                verseReference: votd.verseReference,
                contentID: votd.contentID
            ))
        }

        let nextReload = WidgetTimeWindow.startOfNextDay()
        return Timeline(entries: entries.isEmpty ? [.placeholder] : entries, policy: .after(nextReload))
    }

    private func currentEntry(allowedTypes: Set<ContentType>? = nil) -> LockScreenWidgetEntry? {
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

        let text = WidgetContentProvider.personalizedText(template: content.templateText, firstName: profile.firstName)

        // Truncate at word boundary for inline widget
        let shortText: String
        if text.count <= 40 {
            shortText = text
        } else {
            let prefix = text.prefix(40)
            if let lastSpace = prefix.lastIndex(of: " ") {
                shortText = String(prefix[prefix.startIndex..<lastSpace]) + "\u{2026}"
            } else {
                shortText = String(prefix) + "\u{2026}"
            }
        }

        return LockScreenWidgetEntry(
            date: Date(),
            shortText: shortText,
            displayText: text,
            verseReference: content.verseReference,
            contentID: content.id
        )
    }
}

// MARK: - Widget Configuration

struct BiblePlusLockScreenWidget: Widget {
    let kind = "BiblePlusLockScreenWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ContentTypeIntent.self, provider: LockScreenWidgetProvider()) { entry in
            LockScreenWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Daily Inspiration")
        .description("A personalized verse, quote, or prayer that refreshes daily.")
        .supportedFamilies([.accessoryInline, .accessoryRectangular])
    }
}
