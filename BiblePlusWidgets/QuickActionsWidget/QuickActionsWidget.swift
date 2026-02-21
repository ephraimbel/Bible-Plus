import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Entry

struct QuickActionsEntry: TimelineEntry {
    let date: Date
    let backgroundGradient: [String]

    static let placeholder = QuickActionsEntry(
        date: Date(),
        backgroundGradient: ["#C9A96E", "#8B6914"]
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
        completion(currentEntry() ?? .placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickActionsEntry>) -> Void) {
        let entry = currentEntry() ?? .placeholder
        let nextReload = WidgetTimeWindow.startOfNextDay()
        completion(Timeline(entries: [entry], policy: .after(nextReload)))
    }

    private func currentEntry() -> QuickActionsEntry? {
        guard let container = try? SharedModelContainer.create() else { return nil }
        let modelContext = ModelContext(container)

        let profileDescriptor = FetchDescriptor<UserProfile>()
        guard let profile = (try? modelContext.fetch(profileDescriptor))?.first else { return nil }

        let effectiveBgID = profile.widgetSelectedBackgroundID ?? profile.selectedBackgroundID
        let background = SanctuaryBackground.background(for: effectiveBgID)
            ?? SanctuaryBackground.allBackgrounds[0]

        return QuickActionsEntry(
            date: Date(),
            backgroundGradient: background.gradientColors
        )
    }
}

// MARK: - Widget Configuration

struct QuickActionsWidget: Widget {
    let kind = "QuickActionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickActionsProvider()) { entry in
            QuickActionsWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: entry.backgroundGradient.map { Color(hex: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        if let uiImage = WidgetBackgroundService.loadWidgetBackgroundImage() {
                            GeometryReader { geo in
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                            }
                        }
                    }
                    .overlay {
                        RadialGradient(
                            colors: [Color.clear, Color.black.opacity(0.25)],
                            center: .center,
                            startRadius: 80,
                            endRadius: 250
                        )
                    }
                }
        }
        .configurationDisplayName("Quick Actions")
        .description("Jump directly to Read, Plan, Ask, or Sanctuary.")
        .supportedFamilies([.systemSmall])
    }
}
