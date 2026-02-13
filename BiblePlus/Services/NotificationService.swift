import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    /// Number of days to schedule ahead. Each day gets unique content per slot.
    private let scheduleDays = 7

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    // MARK: - Schedule

    func scheduleDaily(profile: UserProfile, content: [PrayerContent]) {
        let center = UNUserNotificationCenter.current()
        let name = profile.firstName.isEmpty ? "Friend" : profile.firstName
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for slot in profile.prayerTimes {
            let items = selectMultipleContent(
                count: scheduleDays,
                for: slot,
                profile: profile,
                content: content,
                name: name
            )

            for dayOffset in 0..<scheduleDays {
                guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
                let item = items[dayOffset % items.count]

                let notifContent = UNMutableNotificationContent()
                notifContent.title = "Bible+"
                notifContent.subtitle = slot.notificationPreview(name: name)
                notifContent.body = item.text
                notifContent.sound = .default
                if let contentID = item.contentID {
                    notifContent.userInfo = ["contentID": contentID.uuidString]
                }

                var dateComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
                dateComponents.hour = scheduleHour(for: slot)
                dateComponents.minute = scheduleMinute(for: slot)

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: dateComponents,
                    repeats: false
                )

                let request = UNNotificationRequest(
                    identifier: "prayer-\(slot.rawValue)-day\(dayOffset)",
                    content: notifContent,
                    trigger: trigger
                )

                center.add(request)
            }
        }
    }

    func reschedule(profile: UserProfile, content: [PrayerContent]) {
        cancelAll()
        guard !profile.prayerTimes.isEmpty else { return }
        scheduleDaily(profile: profile, content: content)
    }

    /// Reschedule from value-type snapshot (safe to call from init where SwiftData models may cross boundaries)
    func rescheduleFromSnapshot(
        prayerTimes: [PrayerTimeSlot],
        firstName: String,
        burdens: [Burden],
        seasons: [LifeSeason],
        faithLevel: FaithLevel?,
        isPro: Bool,
        content: [PrayerContent]
    ) async {
        cancelAll()
        guard !prayerTimes.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        let name = firstName.isEmpty ? "Friend" : firstName
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for slot in prayerTimes {
            let items = selectMultipleContentFromValues(
                count: scheduleDays,
                for: slot,
                name: name,
                burdens: burdens,
                seasons: seasons,
                faithLevel: faithLevel,
                isPro: isPro,
                content: content
            )

            for dayOffset in 0..<scheduleDays {
                guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
                let item = items[dayOffset % items.count]

                let notifContent = UNMutableNotificationContent()
                notifContent.title = "Bible+"
                notifContent.subtitle = slot.notificationPreview(name: name)
                notifContent.body = item.text
                notifContent.sound = .default
                if let contentID = item.contentID {
                    notifContent.userInfo = ["contentID": contentID.uuidString]
                }

                var dateComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
                dateComponents.hour = scheduleHour(for: slot)
                dateComponents.minute = scheduleMinute(for: slot)

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: dateComponents,
                    repeats: false
                )

                let request = UNNotificationRequest(
                    identifier: "prayer-\(slot.rawValue)-day\(dayOffset)",
                    content: notifContent,
                    trigger: trigger
                )

                try? await center.add(request)
            }
        }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Schedule Times

    private func scheduleHour(for slot: PrayerTimeSlot) -> Int {
        switch slot {
        case .morning:  7
        case .midday:   12
        case .evening:  19
        case .bedtime:  21
        }
    }

    private func scheduleMinute(for slot: PrayerTimeSlot) -> Int {
        switch slot {
        case .morning:  0
        case .midday:   15
        case .evening:  0
        case .bedtime:  30
        }
    }

    // MARK: - Content Selection

    private struct SelectedContent {
        let text: String
        let contentID: UUID?
    }

    /// Select N unique content items for varied daily notifications.
    private func selectMultipleContent(
        count: Int,
        for slot: PrayerTimeSlot,
        profile: UserProfile,
        content: [PrayerContent],
        name: String
    ) -> [SelectedContent] {
        let candidates = content.filter { $0.timeOfDay.contains(slot) && (!$0.isProOnly || profile.isPro) }
        let pool = candidates.isEmpty
            ? content.filter { !$0.isProOnly || profile.isPro }
            : candidates
        guard !pool.isEmpty else {
            return Array(repeating: SelectedContent(text: "Open your heart to God's word today.", contentID: nil), count: count)
        }

        let userBurdens = Set(profile.currentBurdens)
        let userSeasons = Set(profile.lifeSeasons)

        let scored = pool.map { item -> (PrayerContent, Double) in
            var score = 1.0
            if !userBurdens.isEmpty && !Set(item.applicableBurdens).isDisjoint(with: userBurdens) { score *= 3.0 }
            if !userSeasons.isEmpty && !Set(item.applicableSeasons).isDisjoint(with: userSeasons) { score *= 2.0 }
            if item.faithLevelMin.numericValue <= profile.faithLevel.numericValue { score *= 1.3 }
            return (item, score)
        }

        // Sort by score descending, then pick top candidates with shuffle for variety
        let topItems = scored.sorted { $0.1 > $1.1 }.prefix(max(count * 2, pool.count))
        let shuffled = topItems.shuffled()

        var results: [SelectedContent] = []
        var usedIDs: Set<UUID> = []

        for (item, _) in shuffled {
            guard results.count < count else { break }
            guard !usedIDs.contains(item.id) else { continue }
            usedIDs.insert(item.id)
            results.append(formatContent(item, name: name))
        }

        // Fill remaining slots if we don't have enough unique items
        while results.count < count {
            let item = shuffled[results.count % shuffled.count].0
            results.append(formatContent(item, name: name))
        }

        return results
    }

    /// Value-type version that doesn't reference UserProfile directly
    private func selectMultipleContentFromValues(
        count: Int,
        for slot: PrayerTimeSlot,
        name: String,
        burdens: [Burden],
        seasons: [LifeSeason],
        faithLevel: FaithLevel?,
        isPro: Bool,
        content: [PrayerContent]
    ) -> [SelectedContent] {
        let candidates = content.filter { $0.timeOfDay.contains(slot) && (!$0.isProOnly || isPro) }
        let pool = candidates.isEmpty
            ? content.filter { !$0.isProOnly || isPro }
            : candidates
        guard !pool.isEmpty else {
            return Array(repeating: SelectedContent(text: "Open your heart to God's word today.", contentID: nil), count: count)
        }

        let userBurdens = Set(burdens)
        let userSeasons = Set(seasons)

        let scored = pool.map { item -> (PrayerContent, Double) in
            var score = 1.0
            if !userBurdens.isEmpty && !Set(item.applicableBurdens).isDisjoint(with: userBurdens) { score *= 3.0 }
            if !userSeasons.isEmpty && !Set(item.applicableSeasons).isDisjoint(with: userSeasons) { score *= 2.0 }
            if item.faithLevelMin.numericValue <= (faithLevel?.numericValue ?? FaithLevel.justCurious.numericValue) { score *= 1.3 }
            return (item, score)
        }

        let topItems = scored.sorted { $0.1 > $1.1 }.prefix(max(count * 2, pool.count))
        let shuffled = topItems.shuffled()

        var results: [SelectedContent] = []
        var usedIDs: Set<UUID> = []

        for (item, _) in shuffled {
            guard results.count < count else { break }
            guard !usedIDs.contains(item.id) else { continue }
            usedIDs.insert(item.id)
            results.append(formatContent(item, name: name))
        }

        while results.count < count {
            let item = shuffled[results.count % shuffled.count].0
            results.append(formatContent(item, name: name))
        }

        return results
    }

    private func formatContent(_ item: PrayerContent, name: String) -> SelectedContent {
        let text: String
        if let verse = item.verseText, let ref = item.verseReference {
            text = "\"\(verse)\" — \(ref)"
        } else {
            text = item.templateText.replacingOccurrences(of: "{name}", with: name)
        }
        return SelectedContent(text: text, contentID: item.id)
    }
}

// MARK: - Notification Deep Link

extension Notification.Name {
    static let notificationDeepLink = Notification.Name("NotificationDeepLink")
    static let scriptureDeepLink = Notification.Name("ScriptureDeepLink")
    static let scriptureBibleNavigate = Notification.Name("ScriptureBibleNavigate")
}
