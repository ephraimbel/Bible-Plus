import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    /// Number of days to schedule ahead. Each day gets unique content per slot.
    private let scheduleDays = 7

    static let devotionalCategoryIdentifier = "DEVOTIONAL_PUSH"

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

    // MARK: - Categories

    func registerCategories() {
        let copyAction = UNNotificationAction(
            identifier: "COPY_ACTION",
            title: "Copy Text",
            options: []
        )

        let saveAction = UNNotificationAction(
            identifier: "SAVE_ACTION",
            title: "Save",
            options: [.authenticationRequired]
        )

        let category = UNNotificationCategory(
            identifier: Self.devotionalCategoryIdentifier,
            actions: [copyAction, saveAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
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
                notifContent.title = slot.prayerTimeTitle(name: name)
                notifContent.subtitle = item.text
                notifContent.sound = UNNotificationSound(named: UNNotificationSoundName("prayerAlarm.m4a"))
                notifContent.categoryIdentifier = Self.devotionalCategoryIdentifier

                var userInfo: [String: Any] = [:]
                if let contentID = item.contentID {
                    userInfo["contentID"] = contentID.uuidString
                }
                if let bookName = item.bibleBookName, let chapter = item.bibleChapter {
                    userInfo["bookName"] = bookName
                    userInfo["chapter"] = chapter
                }
                notifContent.userInfo = userInfo

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
        content: [PrayerContent],
        streakCount: Int = 0,
        streakReminderEnabled: Bool = true,
        planReminderEnabled: Bool = true,
        activePlanName: String? = nil,
        activePlanID: String? = nil,
        activePlanNextDay: Int? = nil,
        activePlanTotalDays: Int? = nil,
        faithBoostsEnabled: Bool = false,
        gentleRemindersEnabled: Bool = false
    ) async {
        cancelAll()

        let center = UNUserNotificationCenter.current()
        let name = firstName.isEmpty ? "Friend" : firstName
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Schedule prayer time notifications
        if !prayerTimes.isEmpty {
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
                    notifContent.title = slot.prayerTimeTitle(name: name)
                    notifContent.subtitle = item.text
                    notifContent.sound = UNNotificationSound(named: UNNotificationSoundName("prayerAlarm.m4a"))
                    notifContent.categoryIdentifier = Self.devotionalCategoryIdentifier

                    var userInfo: [String: Any] = [:]
                    if let contentID = item.contentID {
                        userInfo["contentID"] = contentID.uuidString
                    }
                    if let bookName = item.bibleBookName, let chapter = item.bibleChapter {
                        userInfo["bookName"] = bookName
                        userInfo["chapter"] = chapter
                    }
                    notifContent.userInfo = userInfo

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

        // Schedule streak reminders
        if streakReminderEnabled {
            scheduleStreakReminders(streakCount: streakCount, firstName: firstName)
        }

        // Schedule reading plan reminders
        if planReminderEnabled,
           let planName = activePlanName,
           let planID = activePlanID,
           let nextDay = activePlanNextDay,
           let totalDays = activePlanTotalDays {
            scheduleReadingPlanReminder(
                planName: planName,
                planID: planID,
                nextDay: nextDay,
                totalDays: totalDays,
                firstName: firstName
            )
        }

        // Schedule faith boost notifications
        if faithBoostsEnabled {
            scheduleFaithBoosts(
                name: name,
                burdens: burdens,
                seasons: seasons,
                faithLevel: faithLevel,
                isPro: isPro,
                content: content
            )
        }

        // Schedule gentle reminders (Pro only)
        if gentleRemindersEnabled {
            scheduleGentleReminders(name: name, burdens: burdens)
        }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Streak Reminders

    func scheduleStreakReminders(streakCount: Int, firstName: String) {
        let center = UNUserNotificationCenter.current()
        let name = firstName.isEmpty ? "Friend" : firstName
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let tier0Messages = [
            "Start your journey today, \(name). Open Bible+ to begin your streak.",
            "Today could be day one, \(name). God is waiting.",
            "A fresh start is calling, \(name). Begin your streak tonight.",
        ]

        let tier1Templates: [(Int) -> String] = [
            { "You're on a \($0)-day streak, \(name)! Don't let it slip away." },
            { "\($0) days strong, \(name). One more day builds the habit." },
            { "\(name), \($0) days in a row! Keep showing up." },
            { "Day \($0) of walking with God, \(name). Keep going." },
        ]

        let tier2Templates: [(Int) -> String] = [
            { "\($0)-day streak! Keep the fire burning, \(name)." },
            { "\(name), \($0) days of faithfulness! You're building something beautiful." },
            { "\($0) days and counting, \(name). This is becoming who you are." },
        ]

        let tier3Templates: [(Int) -> String] = [
            { "\(name), \($0) days! Your consistency is inspiring." },
            { "\($0)-day streak — \(name), you're a warrior of faith." },
            { "\(name), \($0) days of showing up. Heaven notices." },
        ]

        for dayOffset in 0..<scheduleDays {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Bible Plus"
            let projectedStreak = streakCount + dayOffset

            if projectedStreak == 0 {
                content.body = tier0Messages[dayOffset % tier0Messages.count]
            } else if projectedStreak < 7 {
                let template = tier1Templates[dayOffset % tier1Templates.count]
                content.body = template(projectedStreak)
            } else if projectedStreak < 30 {
                let template = tier2Templates[dayOffset % tier2Templates.count]
                content.body = template(projectedStreak)
            } else {
                let template = tier3Templates[dayOffset % tier3Templates.count]
                content.body = template(projectedStreak)
            }
            content.sound = .default

            var dateComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
            dateComponents.hour = 20
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: "streak-reminder-day\(dayOffset)",
                content: content,
                trigger: trigger
            )

            center.add(request)
        }
    }

    func cancelStreakReminders() {
        let identifiers = (0..<scheduleDays).map { "streak-reminder-day\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Reading Plan Reminders

    private let planScheduleDays = 3

    func scheduleReadingPlanReminder(
        planName: String,
        planID: String,
        nextDay: Int,
        totalDays: Int,
        firstName: String
    ) {
        let center = UNUserNotificationCenter.current()
        let name = firstName.isEmpty ? "Friend" : firstName
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for dayOffset in 0..<planScheduleDays {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let projectedDay = min(nextDay + dayOffset, totalDays)

            let content = UNMutableNotificationContent()
            content.title = "Bible Plus"
            content.body = "Day \(projectedDay) of \"\(planName)\" is waiting for you, \(name)."
            content.sound = .default
            content.categoryIdentifier = Self.devotionalCategoryIdentifier
            content.userInfo = ["deepLink": "readingPlan", "planID": planID]

            var dateComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
            dateComponents.hour = 9
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: "plan-reminder-day\(dayOffset)",
                content: content,
                trigger: trigger
            )

            center.add(request)
        }
    }

    func cancelPlanReminders() {
        let identifiers = (0..<planScheduleDays).map { "plan-reminder-day\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Faith Boosts

    private let faithBoostScheduleDays = 3
    private let faithBoostHours = [8, 10, 12, 14, 16, 18, 20, 22]

    private let faithBoostSubtitles: [String] = [
        "A word for your heart",
        "Strength for this moment",
        "{name}, take a breath",
        "God sees you right now",
        "A reminder of His love",
        "Pause and be still",
        "You're not alone, {name}",
        "His grace is enough",
        "Something for your soul",
        "A moment with God",
    ]

    func scheduleFaithBoosts(
        name: String,
        burdens: [Burden],
        seasons: [LifeSeason],
        faithLevel: FaithLevel?,
        isPro: Bool,
        content: [PrayerContent]
    ) {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let totalNeeded = faithBoostScheduleDays * faithBoostHours.count // 24
        let items = selectFaithBoostContent(
            count: totalNeeded,
            name: name,
            burdens: burdens,
            seasons: seasons,
            faithLevel: faithLevel,
            isPro: isPro,
            content: content
        )

        let subtitles = faithBoostSubtitles.map {
            $0.replacingOccurrences(of: "{name}", with: name)
        }.shuffled()

        var itemIndex = 0
        for dayOffset in 0..<faithBoostScheduleDays {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }

            for hour in faithBoostHours {
                let item = items[itemIndex % items.count]

                let notifContent = UNMutableNotificationContent()
                notifContent.title = "Bible Plus"
                notifContent.subtitle = subtitles[itemIndex % subtitles.count]
                notifContent.body = item.text
                notifContent.sound = .default
                notifContent.categoryIdentifier = Self.devotionalCategoryIdentifier

                var userInfo: [String: Any] = [:]
                if let contentID = item.contentID {
                    userInfo["contentID"] = contentID.uuidString
                }
                if let bookName = item.bibleBookName, let chapter = item.bibleChapter {
                    userInfo["bookName"] = bookName
                    userInfo["chapter"] = chapter
                }
                notifContent.userInfo = userInfo

                var dateComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
                dateComponents.hour = hour
                dateComponents.minute = 30  // Offset to :30 to avoid collision with streak reminders at :00

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: dateComponents,
                    repeats: false
                )

                let request = UNNotificationRequest(
                    identifier: "faith-boost-day\(dayOffset)-hour\(hour)",
                    content: notifContent,
                    trigger: trigger
                )

                center.add(request)
                itemIndex += 1
            }
        }
    }

    func cancelFaithBoosts() {
        var identifiers: [String] = []
        for dayOffset in 0..<faithBoostScheduleDays {
            for hour in faithBoostHours {
                identifiers.append("faith-boost-day\(dayOffset)-hour\(hour)")
            }
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Select content for faith boosts — draws from ALL time slots for variety throughout the day.
    private func selectFaithBoostContent(
        count: Int,
        name: String,
        burdens: [Burden],
        seasons: [LifeSeason],
        faithLevel: FaithLevel?,
        isPro: Bool,
        content: [PrayerContent]
    ) -> [SelectedContent] {
        let userBurdens = Set(burdens)
        let userSeasons = Set(seasons)

        // Use all content regardless of time slot
        let pool = content.filter { !$0.isProOnly || isPro }

        let scoredFeed: [(SelectedContent, Double)] = pool.map { item in
            var score = 1.0
            if !userBurdens.isEmpty && !Set(item.applicableBurdens).isDisjoint(with: userBurdens) { score *= 3.0 }
            if !userSeasons.isEmpty && !Set(item.applicableSeasons).isDisjoint(with: userSeasons) { score *= 2.0 }
            if item.faithLevelMin.numericValue <= (faithLevel?.numericValue ?? FaithLevel.justCurious.numericValue) { score *= 1.3 }
            return (formatContent(item, name: name), score)
        }

        // Score all curated verses across all time slots
        let scoredVerses = scoreAllCuratedVerses(burdens: userBurdens)

        // Score all notification content
        let scoredNotifContent = scoreAllNotificationContent(name: name, burdens: userBurdens)

        return mergeAndSelect(count: count, feedItems: scoredFeed, verseItems: scoredVerses, notifItems: scoredNotifContent)
    }

    // MARK: - Gentle Reminders (Pro)

    private let gentleReminderSlots: [(hour: Int, minute: Int)] = [
        (9, 30),
        (15, 0),
        (17, 30),
    ]

    private let gentleReminderSubtitles: [String] = [
        "{name}, take a breath",
        "A word for your heart",
        "God sees you right now",
        "Strength for this moment",
        "A reminder of His love",
        "{name}, you're not alone",
        "Pause and be still",
        "His grace is enough",
        "Something for your soul",
        "A moment with God",
    ]

    func scheduleGentleReminders(name: String, burdens: [Burden]) {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let userBurdens = Set(burdens)

        // Pull from notification-content.json (prayers, affirmations, encouragements)
        let allNotifItems = NotificationContentLoader.shared.loadAll()
            .filter { ["prayer", "affirmation", "encouragement"].contains($0.category) }

        let totalNeeded = scheduleDays * gentleReminderSlots.count

        // Score and select items
        let scored: [(SelectedContent, Double)] = allNotifItems.map { item in
            let text = item.text.replacingOccurrences(of: "{name}", with: name)
            let content = SelectedContent(text: text, notifContentID: item.id)
            var score = 1.0
            let itemBurdens = Set(item.burdens.compactMap { Burden(rawValue: $0) })
            if !userBurdens.isEmpty && !itemBurdens.isDisjoint(with: userBurdens) { score *= 3.0 }
            return (content, score)
        }

        let selected = mergeAndSelect(count: totalNeeded, feedItems: [], verseItems: [], notifItems: scored)

        let subtitles = gentleReminderSubtitles.map {
            $0.replacingOccurrences(of: "{name}", with: name)
        }.shuffled()

        var itemIndex = 0
        for dayOffset in 0..<scheduleDays {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }

            for (slotIndex, slot) in gentleReminderSlots.enumerated() {
                let item = selected[itemIndex % selected.count]

                let notifContent = UNMutableNotificationContent()
                notifContent.title = "Bible Plus"
                notifContent.subtitle = subtitles[itemIndex % subtitles.count]
                notifContent.body = item.text
                notifContent.sound = .default
                notifContent.categoryIdentifier = Self.devotionalCategoryIdentifier

                var dateComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
                dateComponents.hour = slot.hour
                dateComponents.minute = slot.minute

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: dateComponents,
                    repeats: false
                )

                let request = UNNotificationRequest(
                    identifier: "gentle-reminder-day\(dayOffset)-slot\(slotIndex)",
                    content: notifContent,
                    trigger: trigger
                )

                center.add(request)
                itemIndex += 1
            }
        }
    }

    func cancelGentleReminders() {
        var identifiers: [String] = []
        for dayOffset in 0..<scheduleDays {
            for slotIndex in 0..<gentleReminderSlots.count {
                identifiers.append("gentle-reminder-day\(dayOffset)-slot\(slotIndex)")
            }
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Notification Content Scoring

    /// Score notification-content.json items for a specific time slot.
    private func scoreNotificationContent(for slot: PrayerTimeSlot, name: String, burdens: Set<Burden>) -> [(SelectedContent, Double)] {
        let slotString = slot.rawValue
        let items = NotificationContentLoader.shared.items(forSlot: slotString)
        return items.map { item in
            let text = item.text.replacingOccurrences(of: "{name}", with: name)
            let content = SelectedContent(
                text: text,
                notifContentID: item.id
            )
            var score = 1.0
            let itemBurdens = Set(item.burdens.compactMap { Burden(rawValue: $0) })
            if !burdens.isEmpty && !itemBurdens.isDisjoint(with: burdens) { score *= 3.0 }
            score *= 1.1  // Slight boost for standalone content variety
            return (content, score)
        }
    }

    /// Score all notification-content.json items regardless of time slot.
    private func scoreAllNotificationContent(name: String, burdens: Set<Burden>) -> [(SelectedContent, Double)] {
        let items = NotificationContentLoader.shared.loadAll()
        return items.map { item in
            let text = item.text.replacingOccurrences(of: "{name}", with: name)
            let content = SelectedContent(
                text: text,
                notifContentID: item.id
            )
            var score = 1.0
            let itemBurdens = Set(item.burdens.compactMap { Burden(rawValue: $0) })
            if !burdens.isEmpty && !itemBurdens.isDisjoint(with: burdens) { score *= 3.0 }
            score *= 1.1
            return (content, score)
        }
    }

    /// Score all curated verses regardless of time slot (for faith boosts).
    private func scoreAllCuratedVerses(burdens: Set<Burden>) -> [(SelectedContent, Double)] {
        Self.curatedVerses.compactMap { cv in
            let verses = BibleRepository.shared.versesSync(book: cv.bookID, chapter: cv.chapter)
            guard let verse = verses.first(where: { $0.number == cv.verse }) else { return nil }
            let verseText = verse.text.count > 120
                ? String(verse.text.prefix(117)) + "..."
                : verse.text
            let text = "\"\(verseText)\" — \(cv.bookName) \(cv.chapter):\(cv.verse)"
            let content = SelectedContent(
                text: text,
                contentID: nil,
                bibleBookName: cv.bookName,
                bibleChapter: cv.chapter
            )

            var score = 1.0
            if !burdens.isEmpty && !Set(cv.burdens).isDisjoint(with: burdens) { score *= 3.0 }
            score *= 1.2

            return (content, score)
        }
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
        let bibleBookName: String?
        let bibleChapter: Int?
        let notifContentID: String?  // ID from notification-content.json

        init(text: String, contentID: UUID? = nil, bibleBookName: String? = nil, bibleChapter: Int? = nil, notifContentID: String? = nil) {
            self.text = text
            self.contentID = contentID
            self.bibleBookName = bibleBookName
            self.bibleChapter = bibleChapter
            self.notifContentID = notifContentID
        }
    }

    /// Select N unique content items for varied daily notifications, mixing feed content and Bible verses.
    private func selectMultipleContent(
        count: Int,
        for slot: PrayerTimeSlot,
        profile: UserProfile,
        content: [PrayerContent],
        name: String
    ) -> [SelectedContent] {
        let userBurdens = Set(profile.currentBurdens)
        let userSeasons = Set(profile.lifeSeasons)

        // Score feed content
        let candidates = content.filter { $0.timeOfDay.contains(slot) && (!$0.isProOnly || profile.isPro) }
        let pool = candidates.isEmpty
            ? content.filter { !$0.isProOnly || profile.isPro }
            : candidates

        let scoredFeed: [(SelectedContent, Double)] = pool.map { item in
            var score = 1.0
            if !userBurdens.isEmpty && !Set(item.applicableBurdens).isDisjoint(with: userBurdens) { score *= 3.0 }
            if !userSeasons.isEmpty && !Set(item.applicableSeasons).isDisjoint(with: userSeasons) { score *= 2.0 }
            if item.faithLevelMin.numericValue <= profile.faithLevel.numericValue { score *= 1.3 }
            return (formatContent(item, name: name), score)
        }

        // Score Bible verses
        let scoredVerses = scoreCuratedVerses(for: slot, burdens: userBurdens)

        // Score notification content (third source)
        let scoredNotifContent = scoreNotificationContent(for: slot, name: name, burdens: userBurdens)

        return mergeAndSelect(count: count, feedItems: scoredFeed, verseItems: scoredVerses, notifItems: scoredNotifContent)
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
        let userBurdens = Set(burdens)
        let userSeasons = Set(seasons)

        let candidates = content.filter { $0.timeOfDay.contains(slot) && (!$0.isProOnly || isPro) }
        let pool = candidates.isEmpty
            ? content.filter { !$0.isProOnly || isPro }
            : candidates

        let scoredFeed: [(SelectedContent, Double)] = pool.map { item in
            var score = 1.0
            if !userBurdens.isEmpty && !Set(item.applicableBurdens).isDisjoint(with: userBurdens) { score *= 3.0 }
            if !userSeasons.isEmpty && !Set(item.applicableSeasons).isDisjoint(with: userSeasons) { score *= 2.0 }
            if item.faithLevelMin.numericValue <= (faithLevel?.numericValue ?? FaithLevel.justCurious.numericValue) { score *= 1.3 }
            return (formatContent(item, name: name), score)
        }

        let scoredVerses = scoreCuratedVerses(for: slot, burdens: userBurdens)

        // Score notification content (third source)
        let scoredNotifContent = scoreNotificationContent(for: slot, name: name, burdens: userBurdens)

        return mergeAndSelect(count: count, feedItems: scoredFeed, verseItems: scoredVerses, notifItems: scoredNotifContent)
    }

    /// Merge feed, verse, and notification content items; filter recently-sent; pick top N; record sent.
    private func mergeAndSelect(
        count: Int,
        feedItems: [(SelectedContent, Double)],
        verseItems: [(SelectedContent, Double)],
        notifItems: [(SelectedContent, Double)] = []
    ) -> [SelectedContent] {
        let allItems = feedItems + verseItems + notifItems

        guard !allItems.isEmpty else {
            return Array(repeating: SelectedContent(text: "Open your heart to God's word today.", contentID: nil, bibleBookName: nil, bibleChapter: nil), count: count)
        }

        // Sort by score descending, then shuffle top candidates for variety
        let topItems = allItems.sorted { $0.1 > $1.1 }.prefix(max(count * 3, allItems.count))
        let shuffled = Array(topItems).shuffled()

        // Prefer items not recently sent
        let fresh = shuffled.filter { !wasRecentlySent(identifier: contentIdentifier(for: $0.0)) }
        let fallback = shuffled

        var results: [SelectedContent] = []
        var usedIdentifiers: Set<String> = []

        // Pick from fresh first
        for (item, _) in fresh {
            guard results.count < count else { break }
            let id = contentIdentifier(for: item)
            guard !usedIdentifiers.contains(id) else { continue }
            usedIdentifiers.insert(id)
            results.append(item)
        }

        // Fill from fallback if needed
        if results.count < count {
            for (item, _) in fallback {
                guard results.count < count else { break }
                let id = contentIdentifier(for: item)
                guard !usedIdentifiers.contains(id) else { continue }
                usedIdentifiers.insert(id)
                results.append(item)
            }
        }

        // Final fill if still short
        while results.count < count {
            let item = fallback[results.count % fallback.count].0
            results.append(item)
        }

        // Record all selected as sent
        for item in results {
            recordSent(identifier: contentIdentifier(for: item))
        }

        return results
    }

    private func contentIdentifier(for item: SelectedContent) -> String {
        if let id = item.contentID {
            return id.uuidString
        } else if let nid = item.notifContentID {
            return "notif-\(nid)"
        } else if let book = item.bibleBookName, let ch = item.bibleChapter {
            return "verse-\(book)-\(ch)"
        }
        return UUID().uuidString
    }

    private func formatContent(_ item: PrayerContent, name: String) -> SelectedContent {
        let text: String
        if let verse = item.verseText, let ref = item.verseReference {
            let trimmed = verse.count > 120 ? String(verse.prefix(117)) + "..." : verse
            text = "\"\(trimmed)\" — \(ref)"
        } else {
            text = item.templateText.replacingOccurrences(of: "{name}", with: name)
        }
        return SelectedContent(text: text, contentID: item.id, bibleBookName: nil, bibleChapter: nil)
    }

    // MARK: - Curated Bible Verses

    private struct CuratedVerse {
        let bookID: String
        let bookName: String
        let chapter: Int
        let verse: Int
        let slots: [PrayerTimeSlot]
        let burdens: [Burden]
    }

    // swiftlint:disable function_body_length
    private static let curatedVerses: [CuratedVerse] = [
        // MARK: Morning
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 118, verse: 24,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "LAM", bookName: "Lamentations", chapter: 3, verse: 23,
                     slots: [.morning], burdens: [.grief, .doubt]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 5, verse: 3,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 143, verse: 8,
                     slots: [.morning], burdens: [.loneliness]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 40, verse: 31,
                     slots: [.morning], burdens: [.health, .anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 90, verse: 14,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "MIC", bookName: "Micah", chapter: 6, verse: 8,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 19, verse: 14,
                     slots: [.morning], burdens: [.anger]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 57, verse: 8,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 30, verse: 5,
                     slots: [.morning], burdens: [.grief]),
        CuratedVerse(bookID: "NUM", bookName: "Numbers", chapter: 6, verse: 24,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 46, verse: 10,
                     slots: [.morning], burdens: [.anxiety]),

        // MARK: Anxiety & Worry
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 4, verse: 6,
                     slots: [.morning, .midday], burdens: [.anxiety]),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 5, verse: 7,
                     slots: [.midday, .evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 41, verse: 10,
                     slots: [.morning, .evening], burdens: [.anxiety, .doubt]),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 6, verse: 34,
                     slots: [.bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 55, verse: 22,
                     slots: [.midday], burdens: [.anxiety]),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 14, verse: 27,
                     slots: [.evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 94, verse: 19,
                     slots: [.midday], burdens: [.anxiety]),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 11, verse: 28,
                     slots: [.evening], burdens: [.anxiety, .health]),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 4, verse: 7,
                     slots: [.bedtime], burdens: [.anxiety]),

        // MARK: Grief & Loss
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 34, verse: 18,
                     slots: [.evening, .bedtime], burdens: [.grief]),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 5, verse: 4,
                     slots: [.morning], burdens: [.grief]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 147, verse: 3,
                     slots: [.evening], burdens: [.grief, .health]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 28,
                     slots: [.morning, .midday], burdens: [.grief, .doubt]),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 1, verse: 3,
                     slots: [.evening], burdens: [.grief]),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 21, verse: 4,
                     slots: [.bedtime], burdens: [.grief]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 56, verse: 8,
                     slots: [.evening], burdens: [.grief]),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 11, verse: 35,
                     slots: [.evening], burdens: [.grief]),

        // MARK: Doubt & Uncertainty
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 3, verse: 5,
                     slots: [.morning, .midday], burdens: [.doubt]),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 11, verse: 1,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 29, verse: 11,
                     slots: [.midday], burdens: [.doubt, .purpose]),
        CuratedVerse(bookID: "MRK", bookName: "Mark", chapter: 9, verse: 24,
                     slots: [.evening], burdens: [.doubt]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 38,
                     slots: [.bedtime], burdens: [.doubt, .loneliness]),
        CuratedVerse(bookID: "2TI", bookName: "2 Timothy", chapter: 1, verse: 7,
                     slots: [.morning], burdens: [.doubt, .anxiety]),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 13, verse: 8,
                     slots: [.midday], burdens: [.doubt]),

        // MARK: Loneliness
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 31, verse: 8,
                     slots: [.evening, .bedtime], burdens: [.loneliness]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 68, verse: 6,
                     slots: [.morning], burdens: [.loneliness]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 43, verse: 2,
                     slots: [.evening], burdens: [.loneliness, .grief]),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 28, verse: 20,
                     slots: [.bedtime], burdens: [.loneliness]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 27, verse: 10,
                     slots: [.evening], burdens: [.loneliness, .grief]),
        CuratedVerse(bookID: "JOS", bookName: "Joshua", chapter: 1, verse: 9,
                     slots: [.morning], burdens: [.loneliness, .doubt]),

        // MARK: Temptation
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 10, verse: 13,
                     slots: [.morning, .midday], burdens: [.temptation]),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 4, verse: 7,
                     slots: [.midday], burdens: [.temptation]),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 5, verse: 16,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 2, verse: 18,
                     slots: [.evening], burdens: [.temptation]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 11,
                     slots: [.morning], burdens: [.temptation]),

        // MARK: Financial
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 4, verse: 19,
                     slots: [.morning, .midday], burdens: [.financial]),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 6, verse: 33,
                     slots: [.morning], burdens: [.financial, .purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 25,
                     slots: [.evening], burdens: [.financial]),
        CuratedVerse(bookID: "MAL", bookName: "Malachi", chapter: 3, verse: 10,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 10, verse: 22,
                     slots: [.midday], burdens: [.financial]),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 8, verse: 18,
                     slots: [.morning], burdens: [.financial, .purpose]),

        // MARK: Health
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 17, verse: 14,
                     slots: [.morning], burdens: [.health]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 103, verse: 3,
                     slots: [.midday], burdens: [.health]),
        CuratedVerse(bookID: "3JN", bookName: "3 John", chapter: 1, verse: 2,
                     slots: [.morning], burdens: [.health]),
        CuratedVerse(bookID: "EXO", bookName: "Exodus", chapter: 23, verse: 25,
                     slots: [.midday], burdens: [.health]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 53, verse: 5,
                     slots: [.evening], burdens: [.health]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 41, verse: 3,
                     slots: [.bedtime], burdens: [.health]),

        // MARK: Relationships
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 13, verse: 4,
                     slots: [.morning, .evening], burdens: [.relationship]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 4, verse: 32,
                     slots: [.midday], burdens: [.relationship, .anger]),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 13,
                     slots: [.evening], burdens: [.relationship, .anger]),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 4, verse: 8,
                     slots: [.evening], burdens: [.relationship]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 17, verse: 17,
                     slots: [.morning], burdens: [.relationship, .loneliness]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 12, verse: 18,
                     slots: [.midday], burdens: [.relationship, .anger]),

        // MARK: Anger
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 1, verse: 19,
                     slots: [.morning, .midday], burdens: [.anger]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 4, verse: 26,
                     slots: [.evening], burdens: [.anger]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 15, verse: 1,
                     slots: [.midday], burdens: [.anger]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 14, verse: 29,
                     slots: [.morning], burdens: [.anger]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 8,
                     slots: [.evening], burdens: [.anger]),

        // MARK: Purpose
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 2, verse: 10,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 31,
                     slots: [.morning, .midday], burdens: [.purpose, .doubt]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 139, verse: 14,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 16, verse: 3,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 43, verse: 7,
                     slots: [.midday], burdens: [.purpose]),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 1, verse: 6,
                     slots: [.evening], burdens: [.purpose, .doubt]),

        // MARK: Bedtime / Peace
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 4, verse: 8,
                     slots: [.bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 91, verse: 1,
                     slots: [.bedtime], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 3, verse: 24,
                     slots: [.bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 121, verse: 4,
                     slots: [.bedtime], burdens: []),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 26, verse: 3,
                     slots: [.bedtime, .evening], burdens: [.anxiety, .doubt]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 23, verse: 4,
                     slots: [.bedtime, .evening], burdens: [.grief, .loneliness]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 127, verse: 2,
                     slots: [.bedtime], burdens: [.anxiety, .financial]),
        CuratedVerse(bookID: "ZEP", bookName: "Zephaniah", chapter: 3, verse: 17,
                     slots: [.bedtime], burdens: [.loneliness]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 63, verse: 6,
                     slots: [.bedtime], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 16, verse: 7,
                     slots: [.bedtime], burdens: [.doubt]),

        // MARK: Gratitude & Thanksgiving
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 100, verse: 4,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "1TH", bookName: "1 Thessalonians", chapter: 5, verse: 18,
                     slots: [.morning, .evening], burdens: []),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 15,
                     slots: [.morning], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 107, verse: 1,
                     slots: [.morning, .evening], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 136, verse: 1,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 9, verse: 1,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 5, verse: 20,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 95, verse: 2,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 106, verse: 1,
                     slots: [.morning, .midday], burdens: []),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 17,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 103, verse: 2,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 34, verse: 1,
                     slots: [.morning, .midday], burdens: []),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 4, verse: 4,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 145, verse: 3,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 50, verse: 14,
                     slots: [.evening], burdens: []),

        // MARK: Strength & Courage
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 40, verse: 29,
                     slots: [.morning, .midday], burdens: [.health, .anxiety]),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 4, verse: 13,
                     slots: [.morning, .midday], burdens: [.doubt, .purpose]),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 12, verse: 9,
                     slots: [.midday, .evening], burdens: [.health, .doubt]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 6, verse: 10,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 31, verse: 6,
                     slots: [.morning], burdens: [.loneliness, .doubt]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 18, verse: 32,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 28, verse: 7,
                     slots: [.morning, .midday], burdens: [.anxiety]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 41, verse: 13,
                     slots: [.midday], burdens: [.anxiety, .loneliness]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 27, verse: 1,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 73, verse: 26,
                     slots: [.evening], burdens: [.health, .grief]),
        CuratedVerse(bookID: "NEH", bookName: "Nehemiah", chapter: 8, verse: 10,
                     slots: [.morning, .midday], burdens: [.grief]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 31, verse: 24,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "2TI", bookName: "2 Timothy", chapter: 4, verse: 17,
                     slots: [.midday], burdens: [.loneliness]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 46, verse: 1,
                     slots: [.morning, .evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 12, verse: 2,
                     slots: [.morning], burdens: [.doubt, .anxiety]),

        // MARK: God's Love
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 5, verse: 8,
                     slots: [.morning, .evening], burdens: [.doubt]),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 31, verse: 3,
                     slots: [.bedtime], burdens: [.loneliness]),
        CuratedVerse(bookID: "1JN", bookName: "1 John", chapter: 4, verse: 19,
                     slots: [.morning], burdens: [.relationship]),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 3, verse: 16,
                     slots: [.morning, .evening], burdens: [.doubt]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 39,
                     slots: [.bedtime], burdens: [.loneliness, .doubt]),
        CuratedVerse(bookID: "1JN", bookName: "1 John", chapter: 4, verse: 16,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 86, verse: 15,
                     slots: [.midday], burdens: [.anger]),
        CuratedVerse(bookID: "1JN", bookName: "1 John", chapter: 3, verse: 1,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 36, verse: 7,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 37,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 3, verse: 18,
                     slots: [.evening], burdens: [.loneliness]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 103, verse: 8,
                     slots: [.midday], burdens: [.anger]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 54, verse: 10,
                     slots: [.bedtime], burdens: [.grief, .loneliness]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 136, verse: 26,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 2, verse: 20,
                     slots: [.morning], burdens: [.purpose]),

        // MARK: Wisdom
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 2, verse: 6,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 1, verse: 5,
                     slots: [.morning, .midday], burdens: [.doubt]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 4, verse: 7,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 9, verse: 10,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 2, verse: 3,
                     slots: [.midday], burdens: [.doubt]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 3, verse: 13,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 16, verse: 16,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 19, verse: 20,
                     slots: [.midday], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 105,
                     slots: [.evening], burdens: [.doubt]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 1, verse: 7,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 11, verse: 2,
                     slots: [.midday], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 30,
                     slots: [.midday], burdens: [.purpose]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 24, verse: 14,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 8, verse: 11,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "ECC", bookName: "Ecclesiastes", chapter: 7, verse: 12,
                     slots: [.midday], burdens: [.financial]),

        // MARK: Peace
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 16, verse: 33,
                     slots: [.morning, .evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 4, verse: 9,
                     slots: [.evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 29, verse: 11,
                     slots: [.evening, .bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 15, verse: 13,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "NUM", bookName: "Numbers", chapter: 6, verse: 26,
                     slots: [.bedtime], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 85, verse: 8,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 14,
                     slots: [.evening], burdens: [.relationship]),
        CuratedVerse(bookID: "2TH", bookName: "2 Thessalonians", chapter: 3, verse: 16,
                     slots: [.bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 11,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 32, verse: 17,
                     slots: [.evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 165,
                     slots: [.evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 5, verse: 9,
                     slots: [.midday], burdens: [.relationship, .anger]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 14, verse: 17,
                     slots: [.midday], burdens: []),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 5, verse: 22,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 14, verse: 1,
                     slots: [.evening, .bedtime], burdens: [.anxiety, .doubt]),

        // MARK: Hope
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 6, verse: 19,
                     slots: [.evening], burdens: [.doubt, .anxiety]),
        CuratedVerse(bookID: "LAM", bookName: "Lamentations", chapter: 3, verse: 25,
                     slots: [.morning], burdens: [.grief]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 33, verse: 22,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 130, verse: 5,
                     slots: [.evening], burdens: [.grief]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 5, verse: 5,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 42, verse: 11,
                     slots: [.evening], burdens: [.grief, .doubt]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 24,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 62, verse: 5,
                     slots: [.evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 71, verse: 14,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "MIC", bookName: "Micah", chapter: 7, verse: 7,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 1, verse: 3,
                     slots: [.morning], burdens: [.grief]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 39, verse: 7,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 146, verse: 5,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "TIT", bookName: "Titus", chapter: 2, verse: 13,
                     slots: [.evening], burdens: []),

        // MARK: Faith
        CuratedVerse(bookID: "MRK", bookName: "Mark", chapter: 11, verse: 24,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 10, verse: 17,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 5, verse: 7,
                     slots: [.morning, .midday], burdens: [.doubt]),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 17, verse: 20,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 11, verse: 6,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "1JN", bookName: "1 John", chapter: 5, verse: 4,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 21, verse: 22,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 3, verse: 11,
                     slots: [.midday], burdens: [.doubt]),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 20, verse: 29,
                     slots: [.evening], burdens: [.doubt]),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 10, verse: 23,
                     slots: [.evening], burdens: [.doubt]),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 1, verse: 8,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 4, verse: 20,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 12, verse: 2,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 2, verse: 17,
                     slots: [.midday], burdens: [.purpose]),
        CuratedVerse(bookID: "MRK", bookName: "Mark", chapter: 5, verse: 36,
                     slots: [.evening], burdens: [.anxiety, .doubt]),

        // MARK: Forgiveness
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 6, verse: 14,
                     slots: [.evening], burdens: [.anger, .relationship]),
        CuratedVerse(bookID: "1JN", bookName: "1 John", chapter: 1, verse: 9,
                     slots: [.bedtime], burdens: [.temptation]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 103, verse: 12,
                     slots: [.bedtime], burdens: [.temptation, .doubt]),
        CuratedVerse(bookID: "ACT", bookName: "Acts", chapter: 3, verse: 19,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 1, verse: 18,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "MIC", bookName: "Micah", chapter: 7, verse: 18,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 32, verse: 5,
                     slots: [.bedtime], burdens: [.temptation]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 1, verse: 7,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 8, verse: 12,
                     slots: [.bedtime], burdens: []),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 1,
                     slots: [.morning], burdens: [.temptation, .doubt]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 51, verse: 10,
                     slots: [.morning, .bedtime], burdens: [.temptation]),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 6, verse: 37,
                     slots: [.midday], burdens: [.relationship, .anger]),

        // MARK: Joy
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 16, verse: 11,
                     slots: [.morning], burdens: [.grief]),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 1, verse: 2,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 15, verse: 11,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 126, verse: 3,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 30, verse: 11,
                     slots: [.morning], burdens: [.grief]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 61, verse: 3,
                     slots: [.morning], burdens: [.grief]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 47, verse: 1,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "HAB", bookName: "Habakkuk", chapter: 3, verse: 18,
                     slots: [.morning], burdens: [.doubt, .financial]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 98, verse: 4,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 5, verse: 11,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 1, verse: 6,
                     slots: [.midday], burdens: [.grief]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 68, verse: 3,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 55, verse: 12,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 16, verse: 22,
                     slots: [.evening], burdens: [.grief]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 12, verse: 15,
                     slots: [.midday], burdens: [.relationship]),

        // MARK: Patience & Perseverance
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 1, verse: 3,
                     slots: [.morning, .midday], burdens: [.doubt]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 5, verse: 3,
                     slots: [.morning], burdens: [.health, .doubt]),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 6, verse: 9,
                     slots: [.midday], burdens: [.purpose]),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 10, verse: 36,
                     slots: [.midday], burdens: [.doubt]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 27, verse: 14,
                     slots: [.morning], burdens: [.anxiety]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 30, verse: 18,
                     slots: [.evening], burdens: [.doubt]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 7,
                     slots: [.evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 12, verse: 1,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "2PE", bookName: "2 Peter", chapter: 3, verse: 9,
                     slots: [.midday], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 40, verse: 1,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 5, verse: 11,
                     slots: [.midday], burdens: [.health]),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 1, verse: 11,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 5, verse: 7,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 25,
                     slots: [.midday], burdens: []),

        // MARK: Trust
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 56, verse: 3,
                     slots: [.morning, .bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "NAH", bookName: "Nahum", chapter: 1, verse: 7,
                     slots: [.evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 5,
                     slots: [.morning], burdens: [.anxiety, .purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 62, verse: 8,
                     slots: [.evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 9, verse: 10,
                     slots: [.morning], burdens: [.loneliness]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 20, verse: 7,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 112, verse: 7,
                     slots: [.midday], burdens: [.anxiety]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 26, verse: 4,
                     slots: [.morning], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 125, verse: 1,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 115, verse: 11,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 40, verse: 4,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 33, verse: 21,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 84, verse: 12,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 29, verse: 25,
                     slots: [.midday], burdens: [.anxiety]),

        // MARK: Protection
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 91, verse: 2,
                     slots: [.bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 121, verse: 7,
                     slots: [.bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "2TH", bookName: "2 Thessalonians", chapter: 3, verse: 3,
                     slots: [.morning, .bedtime], burdens: [.temptation]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 46, verse: 7,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 121, verse: 3,
                     slots: [.bedtime], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 32, verse: 7,
                     slots: [.evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 18, verse: 2,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 33, verse: 27,
                     slots: [.bedtime], burdens: [.loneliness]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 34, verse: 7,
                     slots: [.bedtime], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 91, verse: 4,
                     slots: [.bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 54, verse: 17,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 3, verse: 3,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 59, verse: 16,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 18, verse: 10,
                     slots: [.midday], burdens: [.anxiety]),

        // MARK: Provision
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 6, verse: 26,
                     slots: [.morning], burdens: [.financial, .anxiety]),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 9, verse: 8,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 34, verse: 10,
                     slots: [.midday], burdens: [.financial]),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 12, verse: 24,
                     slots: [.morning], burdens: [.financial, .anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 145, verse: 16,
                     slots: [.midday], burdens: [.financial]),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 6, verse: 31,
                     slots: [.morning], burdens: [.financial, .anxiety]),
        CuratedVerse(bookID: "GEN", bookName: "Genesis", chapter: 22, verse: 14,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 4,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 84, verse: 11,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 58, verse: 11,
                     slots: [.midday], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 132, verse: 15,
                     slots: [.evening], burdens: [.financial]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 111, verse: 5,
                     slots: [.midday], burdens: [.financial]),
        CuratedVerse(bookID: "JOL", bookName: "Joel", chapter: 2, verse: 26,
                     slots: [.evening], burdens: [.financial]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 65, verse: 9,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 7, verse: 11,
                     slots: [.morning], burdens: []),

        // MARK: Identity in Christ
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 2, verse: 9,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 1, verse: 12,
                     slots: [.morning], burdens: [.loneliness]),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 15, verse: 16,
                     slots: [.morning], burdens: [.purpose, .doubt]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 17,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 5, verse: 20,
                     slots: [.midday], burdens: [.purpose]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 1, verse: 4,
                     slots: [.morning], burdens: [.purpose, .doubt]),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 3,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 3, verse: 20,
                     slots: [.evening], burdens: [.purpose]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 43, verse: 1,
                     slots: [.morning], burdens: [.loneliness]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 3, verse: 12,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 1, verse: 5,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 6, verse: 19,
                     slots: [.morning], burdens: [.temptation, .health]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 16,
                     slots: [.evening], burdens: [.loneliness]),
        CuratedVerse(bookID: "1JN", bookName: "1 John", chapter: 3, verse: 2,
                     slots: [.evening], burdens: [.purpose]),

        // MARK: Comfort & Healing
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 23, verse: 2,
                     slots: [.evening, .bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 34, verse: 17,
                     slots: [.evening], burdens: [.grief]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 57, verse: 18,
                     slots: [.evening], burdens: [.health]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 107, verse: 20,
                     slots: [.morning], burdens: [.health]),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 1, verse: 4,
                     slots: [.midday], burdens: [.grief]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 73, verse: 23,
                     slots: [.evening], burdens: [.loneliness]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 66, verse: 13,
                     slots: [.evening], burdens: [.grief, .loneliness]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 116, verse: 7,
                     slots: [.evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 30, verse: 17,
                     slots: [.morning], burdens: [.health]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 10, verse: 17,
                     slots: [.evening], burdens: [.loneliness]),

        // MARK: Guidance & Direction
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 32, verse: 8,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 3, verse: 6,
                     slots: [.morning], burdens: [.purpose, .doubt]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 30, verse: 21,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 25, verse: 4,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 23,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 48, verse: 14,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 10, verse: 27,
                     slots: [.morning, .midday], burdens: [.doubt]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 25, verse: 9,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 48, verse: 17,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 143, verse: 10,
                     slots: [.morning], burdens: [.purpose]),

        // MARK: Obedience & Surrender
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 6, verse: 10,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 9, verse: 23,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 12, verse: 1,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "1SA", bookName: "1 Samuel", chapter: 15, verse: 22,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 14, verse: 15,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 4, verse: 10,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 51, verse: 17,
                     slots: [.evening], burdens: [.temptation]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 6, verse: 13,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 16, verse: 24,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 2, verse: 13,
                     slots: [.morning], burdens: [.purpose]),

        // MARK: Rest & Sabbath
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 11, verse: 29,
                     slots: [.evening, .bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 62, verse: 1,
                     slots: [.evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "EXO", bookName: "Exodus", chapter: 33, verse: 14,
                     slots: [.evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 7,
                     slots: [.evening, .bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 30, verse: 15,
                     slots: [.evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 131, verse: 2,
                     slots: [.bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 4, verse: 9,
                     slots: [.bedtime], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 23, verse: 3,
                     slots: [.evening], burdens: [.health]),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 6, verse: 16,
                     slots: [.evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "MRK", bookName: "Mark", chapter: 6, verse: 31,
                     slots: [.evening], burdens: []),

        // MARK: Unity & Community
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 133, verse: 1,
                     slots: [.morning], burdens: [.relationship]),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 10, verse: 25,
                     slots: [.morning], burdens: [.loneliness]),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 6, verse: 2,
                     slots: [.midday], burdens: [.relationship]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 12, verse: 10,
                     slots: [.midday], burdens: [.relationship]),
        CuratedVerse(bookID: "1TH", bookName: "1 Thessalonians", chapter: 5, verse: 11,
                     slots: [.midday], burdens: [.relationship, .loneliness]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 4, verse: 3,
                     slots: [.morning], burdens: [.relationship]),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 12, verse: 26,
                     slots: [.midday], burdens: [.loneliness]),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 2, verse: 3,
                     slots: [.morning], burdens: [.relationship]),

        // MARK: Generosity & Service
        CuratedVerse(bookID: "ACT", bookName: "Acts", chapter: 20, verse: 35,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 11, verse: 25,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 9, verse: 7,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 6, verse: 38,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 25, verse: 40,
                     slots: [.midday], burdens: [.purpose]),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 5, verse: 13,
                     slots: [.midday], burdens: [.purpose]),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 4, verse: 10,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 13, verse: 16,
                     slots: [.midday], burdens: []),

        // MARK: Marriage
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 5, verse: 25,
                     slots: [.morning, .evening], burdens: [.relationship]),
        CuratedVerse(bookID: "GEN", bookName: "Genesis", chapter: 2, verse: 24,
                     slots: [.evening], burdens: [.relationship]),
        CuratedVerse(bookID: "MRK", bookName: "Mark", chapter: 10, verse: 9,
                     slots: [.morning], burdens: [.relationship]),
        CuratedVerse(bookID: "SNG", bookName: "Song of Solomon", chapter: 8, verse: 7,
                     slots: [.evening], burdens: [.relationship]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 18, verse: 22,
                     slots: [.morning], burdens: [.relationship]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 31, verse: 10,
                     slots: [.morning], burdens: [.relationship]),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 7, verse: 3,
                     slots: [.evening], burdens: [.relationship]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 5, verse: 28,
                     slots: [.evening], burdens: [.relationship]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 5, verse: 33,
                     slots: [.morning], burdens: [.relationship]),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 19,
                     slots: [.evening], burdens: [.relationship]),
        CuratedVerse(bookID: "SNG", bookName: "Song of Solomon", chapter: 2, verse: 16,
                     slots: [.evening], burdens: [.relationship]),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 13, verse: 4,
                     slots: [.morning], burdens: [.relationship]),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 19, verse: 6,
                     slots: [.morning], burdens: [.relationship]),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 13, verse: 7,
                     slots: [.evening], burdens: [.relationship]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 5, verse: 18,
                     slots: [.evening], burdens: [.relationship]),
        CuratedVerse(bookID: "ECC", bookName: "Ecclesiastes", chapter: 4, verse: 9,
                     slots: [.morning], burdens: [.relationship, .loneliness]),
        CuratedVerse(bookID: "SNG", bookName: "Song of Solomon", chapter: 4, verse: 7,
                     slots: [.evening], burdens: [.relationship]),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 3, verse: 7,
                     slots: [.evening], burdens: [.relationship]),

        // MARK: Parenting
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 22, verse: 6,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 6, verse: 7,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 127, verse: 3,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 6, verse: 4,
                     slots: [.morning], burdens: [.anger]),
        CuratedVerse(bookID: "3JN", bookName: "3 John", chapter: 1, verse: 4,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 29, verse: 17,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 54, verse: 13,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 17, verse: 6,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 22, verse: 15,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 6, verse: 6,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 21,
                     slots: [.morning], burdens: [.anger]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 13, verse: 24,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 18, verse: 3,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 19, verse: 14,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 78, verse: 4,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 20, verse: 7,
                     slots: [.morning], burdens: [.purpose]),

        // MARK: Work & Diligence
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 23,
                     slots: [.morning, .midday], burdens: [.purpose]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 14, verse: 23,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "ECC", bookName: "Ecclesiastes", chapter: 9, verse: 10,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "2TH", bookName: "2 Thessalonians", chapter: 3, verse: 10,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 12, verse: 11,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 13, verse: 4,
                     slots: [.morning], burdens: [.financial, .purpose]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 12, verse: 24,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 10, verse: 4,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "GEN", bookName: "Genesis", chapter: 2, verse: 15,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "ECC", bookName: "Ecclesiastes", chapter: 3, verse: 13,
                     slots: [.midday], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 90, verse: 17,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 16, verse: 9,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 21, verse: 5,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 15, verse: 58,
                     slots: [.morning, .midday], burdens: [.purpose]),
        CuratedVerse(bookID: "2TI", bookName: "2 Timothy", chapter: 2, verse: 15,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 6, verse: 6,
                     slots: [.morning], burdens: [.financial]),

        // MARK: Worship
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 95, verse: 1,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 100, verse: 2,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 4, verse: 24,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 13, verse: 15,
                     slots: [.morning, .midday], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 150, verse: 6,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 29, verse: 2,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 96, verse: 9,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 12, verse: 2,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 63, verse: 3,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 99, verse: 5,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 66, verse: 4,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 86, verse: 9,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "EXO", bookName: "Exodus", chapter: 15, verse: 2,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 22, verse: 3,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 148, verse: 13,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 33, verse: 1,
                     slots: [.morning], burdens: []),

        // MARK: Salvation
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 10, verse: 9,
                     slots: [.morning, .evening], burdens: [.doubt]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 2, verse: 8,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "ACT", bookName: "Acts", chapter: 16, verse: 31,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "TIT", bookName: "Titus", chapter: 3, verse: 5,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 6, verse: 23,
                     slots: [.evening], burdens: [.doubt]),
        CuratedVerse(bookID: "ACT", bookName: "Acts", chapter: 4, verse: 12,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 14, verse: 6,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 5, verse: 24,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 10, verse: 13,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 10, verse: 28,
                     slots: [.evening, .bedtime], burdens: [.doubt, .anxiety]),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 5, verse: 17,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 3, verse: 17,
                     slots: [.evening], burdens: [.doubt]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 5, verse: 9,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "1JN", bookName: "1 John", chapter: 5, verse: 13,
                     slots: [.evening], burdens: [.doubt]),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 6, verse: 47,
                     slots: [.evening], burdens: [.doubt]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 1, verse: 13,
                     slots: [.morning], burdens: [.doubt]),

        // MARK: Prayer Life
        CuratedVerse(bookID: "1TH", bookName: "1 Thessalonians", chapter: 5, verse: 17,
                     slots: [.morning, .midday], burdens: []),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 7, verse: 7,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 5, verse: 16,
                     slots: [.morning], burdens: [.health]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 145, verse: 18,
                     slots: [.morning, .evening], burdens: [.loneliness]),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 33, verse: 3,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 26,
                     slots: [.evening], burdens: [.doubt]),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 6, verse: 6,
                     slots: [.morning, .bedtime], burdens: []),
        CuratedVerse(bookID: "1JN", bookName: "1 John", chapter: 5, verse: 14,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 5, verse: 2,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 55, verse: 17,
                     slots: [.morning, .midday, .evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 18, verse: 1,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 17, verse: 6,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "MRK", bookName: "Mark", chapter: 11, verse: 25,
                     slots: [.evening], burdens: [.relationship, .anger]),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 18, verse: 19,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 102, verse: 17,
                     slots: [.evening], burdens: [.grief]),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 15, verse: 7,
                     slots: [.morning], burdens: []),

        // MARK: Humility
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 2, verse: 5,
                     slots: [.morning], burdens: [.relationship]),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 5, verse: 6,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 22, verse: 4,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 23, verse: 12,
                     slots: [.midday], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 15, verse: 33,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "ZEP", bookName: "Zephaniah", chapter: 2, verse: 3,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 14, verse: 11,
                     slots: [.midday], burdens: []),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 18, verse: 4,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 27, verse: 2,
                     slots: [.midday], burdens: []),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 57, verse: 15,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 12,
                     slots: [.morning], burdens: [.relationship]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 16, verse: 18,
                     slots: [.midday], burdens: [.temptation]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 147, verse: 6,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 4, verse: 2,
                     slots: [.morning], burdens: [.relationship]),
        CuratedVerse(bookID: "2CH", bookName: "2 Chronicles", chapter: 7, verse: 14,
                     slots: [.evening], burdens: []),

        // MARK: Grace
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 2, verse: 9,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 6, verse: 14,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "TIT", bookName: "Titus", chapter: 2, verse: 11,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 4, verse: 16,
                     slots: [.morning, .midday], burdens: [.doubt, .temptation]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 3, verse: 24,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 8, verse: 9,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 1, verse: 16,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 5, verse: 20,
                     slots: [.evening], burdens: [.temptation]),
        CuratedVerse(bookID: "2PE", bookName: "2 Peter", chapter: 3, verse: 18,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 11, verse: 6,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "ACT", bookName: "Acts", chapter: 15, verse: 11,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "2TI", bookName: "2 Timothy", chapter: 1, verse: 9,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 5, verse: 17,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 1, verse: 4,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 9, verse: 14,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 5, verse: 10,
                     slots: [.evening], burdens: [.grief, .health]),

        // MARK: More Protection
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 91, verse: 11,
                     slots: [.bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 121, verse: 8,
                     slots: [.morning, .bedtime], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 5, verse: 12,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 17, verse: 8,
                     slots: [.bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 27, verse: 5,
                     slots: [.evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 61, verse: 3,
                     slots: [.evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "2SA", bookName: "2 Samuel", chapter: 22, verse: 3,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 91, verse: 10,
                     slots: [.bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 144, verse: 2,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 138, verse: 7,
                     slots: [.evening], burdens: [.anxiety]),

        // MARK: More Provision
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 23, verse: 1,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 36, verse: 8,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 68, verse: 19,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 33, verse: 16,
                     slots: [.midday], burdens: [.financial]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 34, verse: 9,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 28, verse: 12,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 3,
                     slots: [.morning], burdens: [.financial, .anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 104, verse: 28,
                     slots: [.evening], burdens: [.financial]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 23, verse: 5,
                     slots: [.evening], burdens: [.financial]),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 12, verse: 31,
                     slots: [.morning], burdens: [.financial, .anxiety]),

        // MARK: More Identity in Christ
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 3, verse: 26,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 2, verse: 6,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 3, verse: 18,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 14,
                     slots: [.morning], burdens: [.purpose, .doubt]),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 4, verse: 7,
                     slots: [.morning], burdens: [.purpose, .loneliness]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 2, verse: 19,
                     slots: [.morning], burdens: [.loneliness]),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 3, verse: 16,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 1, verse: 13,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 15, verse: 15,
                     slots: [.evening], burdens: [.loneliness]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 15,
                     slots: [.morning], burdens: [.anxiety, .loneliness]),

        // MARK: Spiritual Warfare
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 6, verse: 11,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 6, verse: 12,
                     slots: [.morning], burdens: [.temptation, .doubt]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 6, verse: 13,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 6, verse: 14,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 6, verse: 16,
                     slots: [.morning, .midday], burdens: [.temptation, .doubt]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 6, verse: 17,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 6, verse: 18,
                     slots: [.morning, .evening], burdens: [.temptation]),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 10, verse: 4,
                     slots: [.morning], burdens: [.temptation, .doubt]),
        CuratedVerse(bookID: "1JN", bookName: "1 John", chapter: 4, verse: 4,
                     slots: [.morning, .midday], burdens: [.temptation, .doubt]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 16, verse: 20,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 10, verse: 5,
                     slots: [.morning], burdens: [.temptation, .anxiety]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 54, verse: 15,
                     slots: [.evening], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 44, verse: 5,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 20, verse: 4,
                     slots: [.morning], burdens: [.anxiety]),
        CuratedVerse(bookID: "2CH", bookName: "2 Chronicles", chapter: 20, verse: 15,
                     slots: [.morning, .midday], burdens: [.anxiety, .doubt]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 13, verse: 12,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "1TI", bookName: "1 Timothy", chapter: 6, verse: 12,
                     slots: [.morning], burdens: [.temptation, .doubt]),
        CuratedVerse(bookID: "2TI", bookName: "2 Timothy", chapter: 4, verse: 7,
                     slots: [.evening], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 144, verse: 1,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 59, verse: 19,
                     slots: [.evening], burdens: [.temptation]),

        // MARK: Promises of God
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 1, verse: 20,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "JOS", bookName: "Joshua", chapter: 21, verse: 45,
                     slots: [.morning, .evening], burdens: [.doubt]),
        CuratedVerse(bookID: "2PE", bookName: "2 Peter", chapter: 1, verse: 4,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "NUM", bookName: "Numbers", chapter: 23, verse: 19,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 55, verse: 11,
                     slots: [.morning, .midday], burdens: [.doubt]),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 7, verse: 9,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "JOS", bookName: "Joshua", chapter: 23, verse: 14,
                     slots: [.evening], burdens: [.doubt]),
        CuratedVerse(bookID: "1KI", bookName: "1 Kings", chapter: 8, verse: 56,
                     slots: [.evening], burdens: [.doubt]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 46, verse: 10,
                     slots: [.morning], burdens: [.doubt, .purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 145, verse: 13,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 40, verse: 8,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 29, verse: 13,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 89, verse: 34,
                     slots: [.evening], burdens: [.doubt]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 4, verse: 21,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 138, verse: 8,
                     slots: [.morning, .evening], burdens: [.purpose]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 49, verse: 16,
                     slots: [.evening], burdens: [.loneliness]),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 32, verse: 27,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 105, verse: 8,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 25, verse: 1,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 6, verse: 18,
                     slots: [.morning], burdens: [.doubt]),

        // MARK: Creation & Nature
        CuratedVerse(bookID: "GEN", bookName: "Genesis", chapter: 1, verse: 1,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 19, verse: 1,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 1, verse: 20,
                     slots: [.morning, .midday], burdens: [.doubt]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 104, verse: 24,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 40, verse: 26,
                     slots: [.evening], burdens: [.doubt]),
        CuratedVerse(bookID: "JOB", bookName: "Job", chapter: 12, verse: 7,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 1, verse: 16,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 8, verse: 3,
                     slots: [.evening, .bedtime], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 104, verse: 33,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "GEN", bookName: "Genesis", chapter: 1, verse: 31,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 33, verse: 6,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 45, verse: 12,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 24, verse: 1,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "JOB", bookName: "Job", chapter: 37, verse: 5,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 19, verse: 2,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "NEH", bookName: "Nehemiah", chapter: 9, verse: 6,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 4, verse: 11,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "JOB", bookName: "Job", chapter: 38, verse: 4,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 8, verse: 1,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 11, verse: 3,
                     slots: [.morning], burdens: [.doubt]),

        // MARK: Heaven & Eternity
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 14, verse: 2,
                     slots: [.evening, .bedtime], burdens: [.grief]),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 2, verse: 9,
                     slots: [.evening, .bedtime], burdens: [.grief]),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 4, verse: 17,
                     slots: [.evening], burdens: [.grief, .health]),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 1, verse: 4,
                     slots: [.evening], burdens: [.grief]),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 14, verse: 3,
                     slots: [.bedtime], burdens: [.grief, .loneliness]),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 4, verse: 18,
                     slots: [.evening], burdens: [.doubt]),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 21, verse: 1,
                     slots: [.bedtime], burdens: [.grief]),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 22, verse: 5,
                     slots: [.bedtime], burdens: []),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 6, verse: 20,
                     slots: [.evening], burdens: [.financial]),
        CuratedVerse(bookID: "1TH", bookName: "1 Thessalonians", chapter: 4, verse: 17,
                     slots: [.bedtime], burdens: [.grief, .loneliness]),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 2,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "2TI", bookName: "2 Timothy", chapter: 4, verse: 8,
                     slots: [.evening], burdens: [.purpose]),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 7, verse: 17,
                     slots: [.bedtime], burdens: [.grief]),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 15, verse: 55,
                     slots: [.evening], burdens: [.grief]),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 11, verse: 25,
                     slots: [.morning, .evening], burdens: [.grief, .doubt]),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 21, verse: 3,
                     slots: [.bedtime], burdens: [.loneliness, .grief]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 25, verse: 8,
                     slots: [.evening], burdens: [.grief]),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 15, verse: 54,
                     slots: [.morning], burdens: [.grief]),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 3, verse: 21,
                     slots: [.evening], burdens: [.health]),
        CuratedVerse(bookID: "2PE", bookName: "2 Peter", chapter: 3, verse: 13,
                     slots: [.evening], burdens: []),

        // MARK: Children & Youth
        CuratedVerse(bookID: "1TI", bookName: "1 Timothy", chapter: 4, verse: 12,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 9,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "ECC", bookName: "Ecclesiastes", chapter: 12, verse: 1,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "LAM", bookName: "Lamentations", chapter: 3, verse: 27,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 99,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 20, verse: 11,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 71, verse: 5,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 148, verse: 12,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "2TI", bookName: "2 Timothy", chapter: 3, verse: 15,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 1, verse: 8,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 40, verse: 30,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 100,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 4, verse: 1,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 8, verse: 2,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 1, verse: 7,
                     slots: [.morning], burdens: [.doubt, .purpose]),
        CuratedVerse(bookID: "1SA", bookName: "1 Samuel", chapter: 2, verse: 26,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 23, verse: 24,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "DAN", bookName: "Daniel", chapter: 1, verse: 17,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 18, verse: 10,
                     slots: [.evening], burdens: []),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 2, verse: 52,
                     slots: [.morning], burdens: []),

        // MARK: Fear of the Lord
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 111, verse: 10,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 10, verse: 12,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 33, verse: 8,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 25, verse: 14,
                     slots: [.morning, .evening], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 34, verse: 11,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 128, verse: 1,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 14, verse: 27,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 14, verse: 26,
                     slots: [.morning], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 103, verse: 11,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 10, verse: 27,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 19, verse: 9,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 115, verse: 13,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 147, verse: 11,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 8, verse: 13,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 3, verse: 7,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "ACT", bookName: "Acts", chapter: 9, verse: 31,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 19, verse: 23,
                     slots: [.evening, .bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "MAL", bookName: "Malachi", chapter: 4, verse: 2,
                     slots: [.morning], burdens: [.health]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 112, verse: 1,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 33, verse: 6,
                     slots: [.morning], burdens: []),

        // MARK: Justice & Righteousness
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 1, verse: 17,
                     slots: [.morning, .midday], burdens: [.purpose]),
        CuratedVerse(bookID: "AMO", bookName: "Amos", chapter: 5, verse: 24,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 89, verse: 14,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 21, verse: 3,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 6,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 61, verse: 8,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 106, verse: 3,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 31, verse: 9,
                     slots: [.morning, .midday], burdens: [.purpose]),
        CuratedVerse(bookID: "ZEC", bookName: "Zechariah", chapter: 7, verse: 9,
                     slots: [.morning], burdens: [.relationship]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 82, verse: 3,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 28, verse: 5,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 56, verse: 1,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 11, verse: 7,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 29, verse: 7,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 5, verse: 6,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 140, verse: 12,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 58, verse: 6,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 22, verse: 3,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 72, verse: 4,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 23, verse: 23,
                     slots: [.midday], burdens: [.purpose]),

        // MARK: Thanksgiving (Expanded)
        CuratedVerse(bookID: "1CH", bookName: "1 Chronicles", chapter: 16, verse: 34,
                     slots: [.morning, .evening], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 69, verse: 30,
                     slots: [.morning], burdens: [.grief]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 7, verse: 17,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 30, verse: 12,
                     slots: [.morning, .evening], burdens: [.grief]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 105, verse: 1,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 75, verse: 1,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 116, verse: 17,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "1CH", bookName: "1 Chronicles", chapter: 16, verse: 8,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 92, verse: 1,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 138, verse: 1,
                     slots: [.morning, .evening], burdens: []),
        CuratedVerse(bookID: "DAN", bookName: "Daniel", chapter: 2, verse: 23,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 107, verse: 8,
                     slots: [.morning, .evening], burdens: []),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 12, verse: 28,
                     slots: [.morning], burdens: []),

        // MARK: Renewal & Transformation
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 43, verse: 19,
                     slots: [.morning], burdens: [.purpose, .doubt]),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 4, verse: 16,
                     slots: [.morning, .evening], burdens: [.health, .grief]),
        CuratedVerse(bookID: "EZK", bookName: "Ezekiel", chapter: 36, verse: 26,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 51, verse: 12,
                     slots: [.morning], burdens: [.grief, .temptation]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 6, verse: 4,
                     slots: [.morning], burdens: [.temptation, .purpose]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 4, verse: 23,
                     slots: [.morning], burdens: [.temptation]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 61, verse: 1,
                     slots: [.morning], burdens: [.grief]),
        CuratedVerse(bookID: "LAM", bookName: "Lamentations", chapter: 5, verse: 21,
                     slots: [.morning, .evening], burdens: [.doubt]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 4, verse: 24,
                     slots: [.morning], burdens: [.temptation, .purpose]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 43, verse: 18,
                     slots: [.morning], burdens: [.grief]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 80, verse: 19,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 10,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 21, verse: 5,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 104, verse: 30,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "JOL", bookName: "Joel", chapter: 2, verse: 25,
                     slots: [.morning], burdens: [.grief, .financial]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 42, verse: 9,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "EZK", bookName: "Ezekiel", chapter: 37, verse: 5,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 6, verse: 15,
                     slots: [.morning], burdens: [.purpose]),

        // MARK: Compassion & Mercy
        CuratedVerse(bookID: "LAM", bookName: "Lamentations", chapter: 3, verse: 22,
                     slots: [.morning], burdens: [.grief, .doubt]),
        CuratedVerse(bookID: "MIC", bookName: "Micah", chapter: 7, verse: 19,
                     slots: [.evening], burdens: [.temptation]),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 9, verse: 36,
                     slots: [.midday], burdens: [.relationship]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 103, verse: 13,
                     slots: [.morning, .evening], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 145, verse: 8,
                     slots: [.morning], burdens: [.anger]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 145, verse: 9,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "EXO", bookName: "Exodus", chapter: 34, verse: 6,
                     slots: [.morning], burdens: [.anger]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 116, verse: 5,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 5, verse: 7,
                     slots: [.morning, .midday], burdens: [.relationship]),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 6, verse: 36,
                     slots: [.midday], burdens: [.relationship]),
        CuratedVerse(bookID: "HOS", bookName: "Hosea", chapter: 6, verse: 6,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 2, verse: 13,
                     slots: [.midday], burdens: [.relationship]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 78, verse: 38,
                     slots: [.evening], burdens: [.temptation]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 49, verse: 13,
                     slots: [.morning], burdens: [.grief]),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 4, verse: 15,
                     slots: [.evening], burdens: [.temptation]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 103, verse: 4,
                     slots: [.morning], burdens: [.grief]),
        CuratedVerse(bookID: "JON", bookName: "Jonah", chapter: 4, verse: 2,
                     slots: [.evening], burdens: [.anger]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 111, verse: 4,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "DAN", bookName: "Daniel", chapter: 9, verse: 9,
                     slots: [.evening, .bedtime], burdens: [.temptation]),

        // MARK: More Morning Verses
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 59, verse: 17,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 92, verse: 2,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 108, verse: 2,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 88, verse: 13,
                     slots: [.morning], burdens: [.grief]),
        CuratedVerse(bookID: "MRK", bookName: "Mark", chapter: 1, verse: 35,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 63, verse: 1,
                     slots: [.morning], burdens: [.loneliness]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 130, verse: 6,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 50, verse: 4,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 147,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 8, verse: 17,
                     slots: [.morning], burdens: []),

        // MARK: More Bedtime Verses
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 91, verse: 5,
                     slots: [.bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 3, verse: 5,
                     slots: [.bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 121, verse: 5,
                     slots: [.bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "JOB", bookName: "Job", chapter: 11, verse: 18,
                     slots: [.bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 139, verse: 18,
                     slots: [.bedtime], burdens: [.loneliness]),
        CuratedVerse(bookID: "LEV", bookName: "Leviticus", chapter: 26, verse: 6,
                     slots: [.bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 139, verse: 12,
                     slots: [.bedtime], burdens: [.anxiety]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 42, verse: 8,
                     slots: [.bedtime], burdens: [.loneliness]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 121, verse: 6,
                     slots: [.bedtime], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 16, verse: 9,
                     slots: [.bedtime], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 149, verse: 5,
                     slots: [.bedtime], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 4, verse: 4,
                     slots: [.bedtime], burdens: [.anger]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 134, verse: 1,
                     slots: [.bedtime], burdens: []),

        // MARK: More Marriage Verses
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 13, verse: 13,
                     slots: [.evening], burdens: [.relationship]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 31, verse: 28,
                     slots: [.evening], burdens: [.relationship]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 31, verse: 30,
                     slots: [.morning], burdens: [.relationship]),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 3, verse: 1,
                     slots: [.morning], burdens: [.relationship]),
        CuratedVerse(bookID: "RUT", bookName: "Ruth", chapter: 1, verse: 16,
                     slots: [.evening], burdens: [.relationship]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 5, verse: 21,
                     slots: [.evening], burdens: [.relationship]),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 7, verse: 4,
                     slots: [.evening], burdens: [.relationship]),
        CuratedVerse(bookID: "SNG", bookName: "Song of Solomon", chapter: 1, verse: 2,
                     slots: [.evening], burdens: [.relationship]),
        CuratedVerse(bookID: "GEN", bookName: "Genesis", chapter: 2, verse: 18,
                     slots: [.morning], burdens: [.loneliness, .relationship]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 12, verse: 4,
                     slots: [.morning], burdens: [.relationship]),
        CuratedVerse(bookID: "ECC", bookName: "Ecclesiastes", chapter: 4, verse: 12,
                     slots: [.morning, .evening], burdens: [.relationship]),
        CuratedVerse(bookID: "MAL", bookName: "Malachi", chapter: 2, verse: 14,
                     slots: [.evening], burdens: [.relationship]),

        // MARK: More Parenting Verses
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 103, verse: 17,
                     slots: [.morning, .evening], burdens: []),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 44, verse: 3,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 112, verse: 2,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 23, verse: 13,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 11, verse: 19,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "GEN", bookName: "Genesis", chapter: 18, verse: 19,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "JOS", bookName: "Joshua", chapter: 24, verse: 15,
                     slots: [.morning, .evening], burdens: [.purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 144, verse: 12,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 31, verse: 26,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "2TI", bookName: "2 Timothy", chapter: 1, verse: 5,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 128, verse: 3,
                     slots: [.morning, .evening], burdens: [.relationship]),

        // MARK: More Work & Diligence Verses
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 22, verse: 29,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 6, verse: 7,
                     slots: [.morning, .midday], burdens: [.purpose]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 31, verse: 17,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 128, verse: 2,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 10, verse: 5,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "1TH", bookName: "1 Thessalonians", chapter: 4, verse: 11,
                     slots: [.morning], burdens: []),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 18, verse: 9,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "GEN", bookName: "Genesis", chapter: 1, verse: 28,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 27, verse: 23,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 24, verse: 27,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 28, verse: 19,
                     slots: [.morning], burdens: [.financial]),
        CuratedVerse(bookID: "ECC", bookName: "Ecclesiastes", chapter: 5, verse: 12,
                     slots: [.evening, .bedtime], burdens: []),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 65, verse: 22,
                     slots: [.morning], burdens: [.financial, .purpose]),
    ]
    // swiftlint:enable function_body_length

    /// Score curated verses for a time slot and user burdens.
    private func scoreCuratedVerses(for slot: PrayerTimeSlot, burdens: Set<Burden>) -> [(SelectedContent, Double)] {
        let matching = Self.curatedVerses.filter { $0.slots.contains(slot) }
        return matching.compactMap { cv in
            let verses = BibleRepository.shared.versesSync(book: cv.bookID, chapter: cv.chapter)
            guard let verse = verses.first(where: { $0.number == cv.verse }) else { return nil }
            let verseText = verse.text.count > 120
                ? String(verse.text.prefix(117)) + "..."
                : verse.text
            let text = "\"\(verseText)\" — \(cv.bookName) \(cv.chapter):\(cv.verse)"
            let content = SelectedContent(
                text: text,
                contentID: nil,
                bibleBookName: cv.bookName,
                bibleChapter: cv.chapter
            )

            var score = 1.0
            if !burdens.isEmpty && !Set(cv.burdens).isDisjoint(with: burdens) { score *= 3.0 }
            // Slight boost for Bible verses to ensure they appear regularly
            score *= 1.2

            return (content, score)
        }
    }

    // MARK: - Sent Content Tracking

    private let sentContentKey = "NotificationSentContentHistory"
    private let repeatWindowDays = 14

    private var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: "group.io.bibleplus.shared") ?? .standard
    }

    private func recordSent(identifier: String) {
        var history = loadSentHistory()
        history[identifier] = Date()
        saveSentHistory(history)
    }

    private func wasRecentlySent(identifier: String) -> Bool {
        let history = loadSentHistory()
        guard let lastSent = history[identifier] else { return false }
        let cutoff = Calendar.current.date(byAdding: .day, value: -repeatWindowDays, to: Date()) ?? Date()
        return lastSent > cutoff
    }

    private func loadSentHistory() -> [String: Date] {
        guard let data = appGroupDefaults.data(forKey: sentContentKey),
              let dict = try? JSONDecoder().decode([String: Date].self, from: data)
        else { return [:] }
        return dict
    }

    private func saveSentHistory(_ history: [String: Date]) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -repeatWindowDays, to: Date()) ?? Date()
        let pruned = history.filter { $0.value > cutoff }
        if let data = try? JSONEncoder().encode(pruned) {
            appGroupDefaults.set(data, forKey: sentContentKey)
        }
    }
}

// MARK: - Notification Deep Link

extension Notification.Name {
    static let notificationDeepLink = Notification.Name("NotificationDeepLink")
    static let notificationSaveAction = Notification.Name("NotificationSaveAction")
    static let scriptureDeepLink = Notification.Name("ScriptureDeepLink")
    static let scriptureBibleNavigate = Notification.Name("ScriptureBibleNavigate")
    static let enterFeedFromDashboard = Notification.Name("EnterFeedFromDashboard")
    static let dashboardShowFeedChanged = Notification.Name("DashboardShowFeedChanged")
    static let readingPlanDeepLink = Notification.Name("ReadingPlanDeepLink")
    static let feedContentDeepLink = Notification.Name("FeedContentDeepLink")
    static let progressDeepLink = Notification.Name("ProgressDeepLink")
    static let plansDeepLink = Notification.Name("PlansDeepLink")
    static let showProgressFromWidget = Notification.Name("ShowProgressFromWidget")
    static let showPlansFromWidget = Notification.Name("ShowPlansFromWidget")
    static let switchToAskTab = Notification.Name("SwitchToAskTab")
    static let openAIWithContext = Notification.Name("OpenAIWithContext")
    static let navigateToConversation = Notification.Name("NavigateToConversation")
}
