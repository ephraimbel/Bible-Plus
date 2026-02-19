import Foundation

struct NotificationContentItem: Codable {
    let id: String
    let category: String  // "prayer", "affirmation", "encouragement", "gratitude", "reflection", "blessing"
    let text: String
    let slots: [String]   // "morning", "midday", "evening", "bedtime"
    let burdens: [String] // maps to Burden enum rawValues
}

final class NotificationContentLoader {
    static let shared = NotificationContentLoader()

    private var cachedItems: [NotificationContentItem]?

    private init() {}

    func loadAll() -> [NotificationContentItem] {
        if let cached = cachedItems { return cached }

        guard let url = Bundle.main.url(forResource: "notification-content", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([NotificationContentItem].self, from: data)
        else { return [] }

        cachedItems = items
        return items
    }

    func items(forSlot slot: String) -> [NotificationContentItem] {
        loadAll().filter { $0.slots.contains(slot) }
    }

    func items(forCategory category: String) -> [NotificationContentItem] {
        loadAll().filter { $0.category == category }
    }

    func items(forBurden burden: String) -> [NotificationContentItem] {
        loadAll().filter { $0.burdens.contains(burden) }
    }

    func items(forSlot slot: String, category: String) -> [NotificationContentItem] {
        loadAll().filter { $0.slots.contains(slot) && $0.category == category }
    }
}
