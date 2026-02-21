import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Entry

struct PlanProgressEntry: TimelineEntry {
    let date: Date
    let planName: String?
    let currentDay: Int
    let totalDays: Int
    let completionFraction: Double
    let gradientColors: [String]
    let backgroundImageData: Data?
    let planID: String?
    let isEmpty: Bool

    static let placeholder = PlanProgressEntry(
        date: Date(),
        planName: "Psalms of Peace",
        currentDay: 3,
        totalDays: 7,
        completionFraction: 0.43,
        gradientColors: SanctuaryBackground.allBackgrounds[0].gradientColors,
        backgroundImageData: nil,
        planID: nil,
        isEmpty: false
    )

    static let empty = PlanProgressEntry(
        date: Date(),
        planName: nil,
        currentDay: 0,
        totalDays: 0,
        completionFraction: 0,
        gradientColors: SanctuaryBackground.allBackgrounds[0].gradientColors,
        backgroundImageData: nil,
        planID: nil,
        isEmpty: true
    )
}

// MARK: - Provider

struct PlanProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlanProgressEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (PlanProgressEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(currentEntry() ?? .empty)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlanProgressEntry>) -> Void) {
        let entry = currentEntry() ?? .empty

        // Refresh at midnight
        let nextReload = WidgetTimeWindow.startOfNextDay()
        let timeline = Timeline(entries: [entry], policy: .after(nextReload))
        completion(timeline)
    }

    private func currentEntry() -> PlanProgressEntry? {
        guard let container = try? SharedModelContainer.create() else { return nil }
        let modelContext = ModelContext(container)

        // Find active plan progress
        let progressDescriptor = FetchDescriptor<UserPlanProgress>(
            predicate: #Predicate { $0.isActive && $0.completedDate == nil }
        )
        guard let progress = (try? modelContext.fetch(progressDescriptor))?.first else { return nil }

        // Find the matching reading plan
        let targetPlanID = progress.planID
        let planDescriptor = FetchDescriptor<ReadingPlan>(
            predicate: #Predicate { $0.id == targetPlanID }
        )
        guard let plan = (try? modelContext.fetch(planDescriptor))?.first else { return nil }

        let fraction = progress.completionFraction(totalDays: plan.totalDays)
        let nextDay = progress.nextDay(totalDays: plan.totalDays)

        // Background: read from UserDefaults (App Group) — always reliable
        let bgColors = WidgetBackgroundService.loadGradientColors()
            ?? SanctuaryBackground.allBackgrounds[0].gradientColors
        let imageData = WidgetBackgroundService.loadWidgetBackgroundImageData()

        return PlanProgressEntry(
            date: Date(),
            planName: plan.name,
            currentDay: nextDay,
            totalDays: plan.totalDays,
            completionFraction: fraction,
            gradientColors: bgColors,
            backgroundImageData: imageData,
            planID: plan.id,
            isEmpty: false
        )
    }
}

// MARK: - Widget Configuration

struct PlanProgressWidget: Widget {
    let kind = "PlanProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlanProgressProvider()) { entry in
            PlanProgressEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackgroundView(
                        gradientColors: entry.gradientColors,
                        imageData: entry.backgroundImageData
                    )
                }
        }
        .configurationDisplayName("Reading Plan")
        .description("Track your reading plan progress at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
