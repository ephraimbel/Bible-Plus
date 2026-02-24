import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Entry

struct GreetingWidgetEntry: TimelineEntry {
    let date: Date
    let greeting: String
    let firstName: String
    let encouragement: String
    let timeIcon: String
    let backgroundGradient: [String]

    static let placeholder = GreetingWidgetEntry(
        date: Date(),
        greeting: "Good morning",
        firstName: "Friend",
        encouragement: "God's mercies are new today",
        timeIcon: "sunrise",
        backgroundGradient: SanctuaryBackground.allBackgrounds[0].gradientColors
    )
}

// MARK: - Encouragements

private let encouragements: [String] = [
    "God's mercies are new today",
    "You are deeply loved",
    "His grace is sufficient for you",
    "Walk in faith, not by sight",
    "The Lord goes before you",
    "Be still and know He is God",
    "His plans for you are good",
    "You are never alone",
    "Let His peace guard your heart",
    "Trust in the Lord with all your heart",
    "Joy comes in the morning",
    "He will never leave you",
    "Your prayers are heard",
    "His love endures forever",
    "Cast your cares upon Him",
    "You are fearfully and wonderfully made",
    "He makes all things new",
    "Rest in His faithfulness",
    "His strength is made perfect in weakness",
    "Let your light shine today",
]

// MARK: - Provider

struct GreetingWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GreetingWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (GreetingWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(currentEntry() ?? .placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GreetingWidgetEntry>) -> Void) {
        let entry = currentEntry() ?? .placeholder
        let nextReload = WidgetTimeWindow.nextBoundary()
        completion(Timeline(entries: [entry], policy: .after(nextReload)))
    }

    private func currentEntry() -> GreetingWidgetEntry? {
        guard let container = try? SharedModelContainer.create() else { return nil }
        let modelContext = ModelContext(container)

        let profileDescriptor = FetchDescriptor<UserProfile>()
        guard let profile = (try? modelContext.fetch(profileDescriptor))?.first else { return nil }

        let window = WidgetTimeWindow.current()
        let firstName = profile.firstName.isEmpty ? "Friend" : profile.firstName

        let greeting: String
        let timeIcon: String
        switch window {
        case .gratitude:
            greeting = "Good morning"
            timeIcon = "sunrise"
        case .strength:
            greeting = "Good morning"
            timeIcon = "sun.max"
        case .pause, .intercession:
            greeting = "Good afternoon"
            timeIcon = "sun.max.fill"
        case .reflection:
            greeting = "Good evening"
            timeIcon = "sunset"
        case .peace:
            greeting = "Good night"
            timeIcon = "moon.stars"
        }

        // Deterministic encouragement based on day-of-year
        let cal = Calendar.current
        let dayOfYear = cal.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = dayOfYear % encouragements.count

        // Background: read from UserDefaults (App Group)
        let bgColors = WidgetBackgroundService.loadGradientColors()
            ?? SanctuaryBackground.allBackgrounds[0].gradientColors

        return GreetingWidgetEntry(
            date: Date(),
            greeting: greeting,
            firstName: firstName,
            encouragement: encouragements[index],
            timeIcon: timeIcon,
            backgroundGradient: bgColors
        )
    }
}

// MARK: - Widget Configuration

struct GreetingWidget: Widget {
    let kind = "GreetingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GreetingWidgetProvider()) { entry in
            GreetingWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Greeting")
        .description("A personalized greeting with daily encouragement.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}
