import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Entry

struct LockScreenWidgetEntry: TimelineEntry {
    let date: Date
    let shortText: String  // ≤40 chars for inline
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

struct LockScreenWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScreenWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (LockScreenWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(currentEntry() ?? .placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenWidgetEntry>) -> Void) {
        guard let container = try? SharedModelContainer.create() else {
            let timeline = Timeline(entries: [LockScreenWidgetEntry.placeholder], policy: .after(WidgetTimeWindow.startOfNextDay()))
            completion(timeline)
            return
        }

        let modelContext = ModelContext(container)
        let profileDescriptor = FetchDescriptor<UserProfile>()
        guard let profile = (try? modelContext.fetch(profileDescriptor))?.first else {
            let timeline = Timeline(entries: [LockScreenWidgetEntry.placeholder], policy: .after(WidgetTimeWindow.startOfNextDay()))
            completion(timeline)
            return
        }

        // Single verse of the day — stays all day, refreshes at midnight
        var entries: [LockScreenWidgetEntry] = []

        if let votd = WidgetContentProvider.dailyInspirationEntry(profile: profile, modelContext: modelContext) {
            entries.append(LockScreenWidgetEntry(
                date: Date(),
                shortText: votd.shortText,
                displayText: votd.displayText,
                verseReference: votd.verseReference,
                contentID: votd.contentID
            ))
        }

        let nextReload = WidgetTimeWindow.startOfNextDay()
        let timeline = Timeline(entries: entries.isEmpty ? [.placeholder] : entries, policy: .after(nextReload))
        completion(timeline)
    }

    private func currentEntry() -> LockScreenWidgetEntry? {
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

        let text = WidgetContentProvider.personalizedText(template: content.templateText, firstName: profile.firstName)

        return LockScreenWidgetEntry(
            date: Date(),
            shortText: String(text.prefix(40)),
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
        StaticConfiguration(kind: kind, provider: LockScreenWidgetProvider()) { entry in
            LockScreenWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Daily Inspiration")
        .description("A personalized verse, quote, or prayer that refreshes daily.")
        .supportedFamilies([.accessoryInline, .accessoryRectangular])
    }
}
