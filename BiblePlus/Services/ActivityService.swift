import Foundation
import SwiftData

@MainActor
enum ActivityService {

    // MARK: - Logging

    static func log(
        _ type: ActivityEventType,
        detail: String = "",
        in context: ModelContext
    ) {
        let event = ActivityEvent(type: type, detail: detail)
        context.insert(event)
        try? context.save()
    }

    // MARK: - Today

    static func activityCountToday(in context: ModelContext) -> Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<ActivityEvent>(
            predicate: #Predicate { $0.createdAt >= startOfDay }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    static func hasActivityToday(in context: ModelContext) -> Bool {
        activityCountToday(in: context) > 0
    }

    // MARK: - Stats

    static func totalCount(
        of type: ActivityEventType,
        in context: ModelContext
    ) -> Int {
        let raw = type.rawValue
        let descriptor = FetchDescriptor<ActivityEvent>(
            predicate: #Predicate { $0.typeRaw == raw }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Heatmap

    static func heatmapData(
        days: Int = 35,
        in context: ModelContext
    ) -> [Date: Int] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<ActivityEvent>(
            predicate: #Predicate { $0.createdAt >= startDate },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        guard let events = try? context.fetch(descriptor) else { return [:] }

        var map: [Date: Int] = [:]
        for event in events {
            let day = calendar.startOfDay(for: event.createdAt)
            map[day, default: 0] += 1
        }
        return map
    }

    // MARK: - Recent Activity

    static func recentActivity(
        limit: Int = 15,
        in context: ModelContext
    ) -> [ActivityEvent] {
        var descriptor = FetchDescriptor<ActivityEvent>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Active Days This Week

    static func activeDaysThisWeek(in context: ModelContext) -> Set<Int> {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        ) ?? Date()
        let descriptor = FetchDescriptor<ActivityEvent>(
            predicate: #Predicate { $0.createdAt >= startOfWeek }
        )
        guard let events = try? context.fetch(descriptor) else { return [] }

        var days: Set<Int> = []
        for event in events {
            let weekday = calendar.component(.weekday, from: event.createdAt)
            days.insert(weekday)
        }
        return days
    }
}
