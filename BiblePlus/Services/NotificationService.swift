import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()
    private init() {}

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

        for slot in profile.prayerTimes {
            let body = selectContent(
                for: slot,
                profile: profile,
                content: content,
                name: name
            )

            let notifContent = UNMutableNotificationContent()
            notifContent.title = "Bible+"
            notifContent.subtitle = slot.notificationPreview(name: name)
            notifContent.body = body.text
            notifContent.sound = .default
            if let contentID = body.contentID {
                notifContent.userInfo = ["contentID": contentID.uuidString]
            }

            var dateComponents = DateComponents()
            dateComponents.hour = scheduleHour(for: slot)
            dateComponents.minute = scheduleMinute(for: slot)

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )

            let request = UNNotificationRequest(
                identifier: "prayer-\(slot.rawValue)",
                content: notifContent,
                trigger: trigger
            )

            center.add(request)
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

        for slot in prayerTimes {
            let body = selectContentFromValues(
                for: slot,
                name: name,
                burdens: burdens,
                seasons: seasons,
                faithLevel: faithLevel,
                content: content
            )

            let notifContent = UNMutableNotificationContent()
            notifContent.title = "Bible+"
            notifContent.subtitle = slot.notificationPreview(name: name)
            notifContent.body = body.text
            notifContent.sound = .default
            if let contentID = body.contentID {
                notifContent.userInfo = ["contentID": contentID.uuidString]
            }

            var dateComponents = DateComponents()
            dateComponents.hour = scheduleHour(for: slot)
            dateComponents.minute = scheduleMinute(for: slot)

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )

            let request = UNNotificationRequest(
                identifier: "prayer-\(slot.rawValue)",
                content: notifContent,
                trigger: trigger
            )

            try? await center.add(request)
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

    private func selectContent(
        for slot: PrayerTimeSlot,
        profile: UserProfile,
        content: [PrayerContent],
        name: String
    ) -> SelectedContent {
        // Filter content relevant to this time slot
        let candidates = content.filter { item in
            item.timeOfDay.contains(slot)
        }

        // If no time-filtered results, fall back to all content
        let pool = candidates.isEmpty ? content : candidates
        guard !pool.isEmpty else {
            return SelectedContent(
                text: "Open your heart to God's word today.",
                contentID: nil
            )
        }

        // Score using simplified FeedEngine logic
        let userBurdens = Set(profile.currentBurdens)
        let userSeasons = Set(profile.lifeSeasons)

        let scored = pool.map { item -> (PrayerContent, Double) in
            var score = 1.0

            // Burden match: 3x
            let itemBurdens = Set(item.applicableBurdens)
            if !userBurdens.isEmpty && !itemBurdens.isDisjoint(with: userBurdens) {
                score *= 3.0
            }

            // Season match: 2x
            let itemSeasons = Set(item.applicableSeasons)
            if !userSeasons.isEmpty && !itemSeasons.isDisjoint(with: userSeasons) {
                score *= 2.0
            }

            // Faith level match: 1.3x
            if item.faithLevelMin.rawValue <= profile.faithLevel.rawValue {
                score *= 1.3
            }

            // Add jitter for variety
            score *= Double.random(in: 0.8...1.2)

            return (item, score)
        }

        let best = scored.max(by: { $0.1 < $1.1 })?.0 ?? pool[0]

        // Build notification body text
        let text: String
        if let verse = best.verseText, let ref = best.verseReference {
            text = "\(verse) — \(ref)"
        } else {
            text = best.templateText.replacingOccurrences(of: "{name}", with: name)
        }

        return SelectedContent(text: text, contentID: best.id)
    }

    /// Value-type version that doesn't reference UserProfile directly
    private func selectContentFromValues(
        for slot: PrayerTimeSlot,
        name: String,
        burdens: [Burden],
        seasons: [LifeSeason],
        faithLevel: FaithLevel?,
        content: [PrayerContent]
    ) -> SelectedContent {
        let candidates = content.filter { $0.timeOfDay.contains(slot) }
        let pool = candidates.isEmpty ? content : candidates
        guard !pool.isEmpty else {
            return SelectedContent(text: "Open your heart to God's word today.", contentID: nil)
        }

        let userBurdens = Set(burdens)
        let userSeasons = Set(seasons)

        let scored = pool.map { item -> (PrayerContent, Double) in
            var score = 1.0
            if !userBurdens.isEmpty && !Set(item.applicableBurdens).isDisjoint(with: userBurdens) { score *= 3.0 }
            if !userSeasons.isEmpty && !Set(item.applicableSeasons).isDisjoint(with: userSeasons) { score *= 2.0 }
            if item.faithLevelMin.rawValue <= (faithLevel?.rawValue ?? FaithLevel.justCurious.rawValue) { score *= 1.3 }
            score *= Double.random(in: 0.8...1.2)
            return (item, score)
        }

        let best = scored.max(by: { $0.1 < $1.1 })?.0 ?? pool[0]
        let text: String
        if let verse = best.verseText, let ref = best.verseReference {
            text = "\(verse) — \(ref)"
        } else {
            text = best.templateText.replacingOccurrences(of: "{name}", with: name)
        }
        return SelectedContent(text: text, contentID: best.id)
    }
}

// MARK: - Notification Deep Link

extension Notification.Name {
    static let notificationDeepLink = Notification.Name("NotificationDeepLink")
}
