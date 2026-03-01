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
                notifContent.title = "Bible Plus"
                notifContent.body = item.text
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
        selectedTopics: [NotificationTopic] = NotificationTopic.freeTopics
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
                    notifContent.title = "Bible Plus"
                    notifContent.body = item.text
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

        // Schedule faith boost notifications (consolidated — includes all content sources filtered by topics)
        if faithBoostsEnabled {
            scheduleFaithBoosts(
                name: name,
                burdens: burdens,
                seasons: seasons,
                faithLevel: faithLevel,
                isPro: isPro,
                content: content,
                selectedTopics: selectedTopics
            )
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

    func scheduleFaithBoosts(
        name: String,
        burdens: [Burden],
        seasons: [LifeSeason],
        faithLevel: FaithLevel?,
        isPro: Bool,
        content: [PrayerContent],
        selectedTopics: [NotificationTopic] = NotificationTopic.freeTopics
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
            content: content,
            selectedTopics: selectedTopics
        )

        var itemIndex = 0
        for dayOffset in 0..<faithBoostScheduleDays {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }

            for hour in faithBoostHours {
                let item = items[itemIndex % items.count]

                let notifContent = UNMutableNotificationContent()
                notifContent.title = "Bible Plus"
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

    /// Select content for faith boosts — draws from ALL time slots for variety throughout the day, filtered by selected topics.
    private func selectFaithBoostContent(
        count: Int,
        name: String,
        burdens: [Burden],
        seasons: [LifeSeason],
        faithLevel: FaithLevel?,
        isPro: Bool,
        content: [PrayerContent],
        selectedTopics: [NotificationTopic] = NotificationTopic.freeTopics
    ) -> [SelectedContent] {
        let userBurdens = Set(burdens)
        let userSeasons = Set(seasons)
        let topicSet = Set(selectedTopics)

        // Use all content regardless of time slot (feed content is always included)
        let pool = content.filter { !$0.isProOnly || isPro }

        let scoredFeed: [(SelectedContent, Double)] = pool.map { item in
            var score = 1.0
            if !userBurdens.isEmpty && !Set(item.applicableBurdens).isDisjoint(with: userBurdens) { score *= 3.0 }
            if !userSeasons.isEmpty && !Set(item.applicableSeasons).isDisjoint(with: userSeasons) { score *= 2.0 }
            if item.faithLevelMin.numericValue <= (faithLevel?.numericValue ?? FaithLevel.justCurious.numericValue) { score *= 1.3 }
            return (formatContent(item, name: name), score)
        }

        // Score curated verses filtered by selected topics
        let scoredVerses = scoreAllCuratedVerses(burdens: userBurdens, selectedTopics: topicSet)

        // Score notification content filtered by selected topics
        let scoredNotifContent = scoreAllNotificationContent(name: name, burdens: userBurdens, selectedTopics: topicSet)

        return mergeAndSelect(count: count, feedItems: scoredFeed, verseItems: scoredVerses, notifItems: scoredNotifContent)
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

    /// Score all notification-content.json items regardless of time slot, filtered by selected topics.
    private func scoreAllNotificationContent(name: String, burdens: Set<Burden>, selectedTopics: Set<NotificationTopic> = Set(NotificationTopic.freeTopics)) -> [(SelectedContent, Double)] {
        let items = NotificationContentLoader.shared.items(forTopics: Array(selectedTopics))
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

    /// Score all curated verses regardless of time slot (for faith boosts), filtered by selected topics.
    private func scoreAllCuratedVerses(burdens: Set<Burden>, selectedTopics: Set<NotificationTopic> = Set(NotificationTopic.freeTopics)) -> [(SelectedContent, Double)] {
        let filtered = Self.curatedVerses.filter { selectedTopics.contains($0.topic) }
        return filtered.compactMap { cv in
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
        let topic: NotificationTopic
    }

    // swiftlint:disable function_body_length
    private static let curatedVerses: [CuratedVerse] = [
        // MARK: Morning
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 118, verse: 24,
                     slots: [.morning], burdens: [], topic: .morningVerses),
        CuratedVerse(bookID: "LAM", bookName: "Lamentations", chapter: 3, verse: 23,
                     slots: [.morning], burdens: [.grief, .doubt], topic: .morningVerses),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 5, verse: 3,
                     slots: [.morning], burdens: [], topic: .morningVerses),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 143, verse: 8,
                     slots: [.morning], burdens: [.loneliness], topic: .morningVerses),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 40, verse: 31,
                     slots: [.morning], burdens: [.health, .anxiety], topic: .morningVerses),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 90, verse: 14,
                     slots: [.morning], burdens: [], topic: .morningVerses),
        CuratedVerse(bookID: "MIC", bookName: "Micah", chapter: 6, verse: 8,
                     slots: [.morning], burdens: [.purpose], topic: .morningVerses),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 19, verse: 14,
                     slots: [.morning], burdens: [.anger], topic: .morningVerses),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 57, verse: 8,
                     slots: [.morning], burdens: [], topic: .morningVerses),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 30, verse: 5,
                     slots: [.morning], burdens: [.grief], topic: .morningVerses),
        CuratedVerse(bookID: "NUM", bookName: "Numbers", chapter: 6, verse: 24,
                     slots: [.morning], burdens: [], topic: .morningVerses),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 46, verse: 10,
                     slots: [.morning], burdens: [.anxiety], topic: .morningVerses),

        // MARK: Anxiety & Worry
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 4, verse: 6,
                     slots: [.morning, .midday], burdens: [.anxiety], topic: .anxiety),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 5, verse: 7,
                     slots: [.midday, .evening], burdens: [.anxiety], topic: .anxiety),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 41, verse: 10,
                     slots: [.morning, .evening], burdens: [.anxiety, .doubt], topic: .anxiety),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 6, verse: 34,
                     slots: [.bedtime], burdens: [.anxiety], topic: .anxiety),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 55, verse: 22,
                     slots: [.midday], burdens: [.anxiety], topic: .anxiety),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 14, verse: 27,
                     slots: [.evening], burdens: [.anxiety], topic: .anxiety),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 94, verse: 19,
                     slots: [.midday], burdens: [.anxiety], topic: .anxiety),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 11, verse: 28,
                     slots: [.evening], burdens: [.anxiety, .health], topic: .anxiety),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 4, verse: 7,
                     slots: [.bedtime], burdens: [.anxiety], topic: .anxiety),

        // MARK: Grief & Loss
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 34, verse: 18,
                     slots: [.evening, .bedtime], burdens: [.grief], topic: .healing),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 5, verse: 4,
                     slots: [.morning], burdens: [.grief], topic: .healing),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 147, verse: 3,
                     slots: [.evening], burdens: [.grief, .health], topic: .healing),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 28,
                     slots: [.morning, .midday], burdens: [.grief, .doubt], topic: .healing),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 1, verse: 3,
                     slots: [.evening], burdens: [.grief], topic: .healing),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 21, verse: 4,
                     slots: [.bedtime], burdens: [.grief], topic: .healing),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 56, verse: 8,
                     slots: [.evening], burdens: [.grief], topic: .healing),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 11, verse: 35,
                     slots: [.evening], burdens: [.grief], topic: .healing),

        // MARK: Doubt & Uncertainty
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 3, verse: 5,
                     slots: [.morning, .midday], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 11, verse: 1,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 29, verse: 11,
                     slots: [.midday], burdens: [.doubt, .purpose], topic: .faith),
        CuratedVerse(bookID: "MRK", bookName: "Mark", chapter: 9, verse: 24,
                     slots: [.evening], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 38,
                     slots: [.bedtime], burdens: [.doubt, .loneliness], topic: .faith),
        CuratedVerse(bookID: "2TI", bookName: "2 Timothy", chapter: 1, verse: 7,
                     slots: [.morning], burdens: [.doubt, .anxiety], topic: .faith),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 13, verse: 8,
                     slots: [.midday], burdens: [.doubt], topic: .faith),

        // MARK: Loneliness
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 31, verse: 8,
                     slots: [.evening, .bedtime], burdens: [.loneliness], topic: .encouragement),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 68, verse: 6,
                     slots: [.morning], burdens: [.loneliness], topic: .encouragement),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 43, verse: 2,
                     slots: [.evening], burdens: [.loneliness, .grief], topic: .encouragement),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 28, verse: 20,
                     slots: [.bedtime], burdens: [.loneliness], topic: .encouragement),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 27, verse: 10,
                     slots: [.evening], burdens: [.loneliness, .grief], topic: .encouragement),
        CuratedVerse(bookID: "JOS", bookName: "Joshua", chapter: 1, verse: 9,
                     slots: [.morning], burdens: [.loneliness, .doubt], topic: .encouragement),

        // MARK: Temptation
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 10, verse: 13,
                     slots: [.morning, .midday], burdens: [.temptation], topic: .spiritualWarfare),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 4, verse: 7,
                     slots: [.midday], burdens: [.temptation], topic: .spiritualWarfare),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 5, verse: 16,
                     slots: [.morning], burdens: [.temptation], topic: .spiritualWarfare),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 2, verse: 18,
                     slots: [.evening], burdens: [.temptation], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 11,
                     slots: [.morning], burdens: [.temptation], topic: .spiritualWarfare),

        // MARK: Financial
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 4, verse: 19,
                     slots: [.morning, .midday], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 6, verse: 33,
                     slots: [.morning], burdens: [.financial, .purpose], topic: .provision),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 25,
                     slots: [.evening], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "MAL", bookName: "Malachi", chapter: 3, verse: 10,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 10, verse: 22,
                     slots: [.midday], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 8, verse: 18,
                     slots: [.morning], burdens: [.financial, .purpose], topic: .provision),

        // MARK: Health
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 17, verse: 14,
                     slots: [.morning], burdens: [.health], topic: .healing),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 103, verse: 3,
                     slots: [.midday], burdens: [.health], topic: .healing),
        CuratedVerse(bookID: "3JN", bookName: "3 John", chapter: 1, verse: 2,
                     slots: [.morning], burdens: [.health], topic: .healing),
        CuratedVerse(bookID: "EXO", bookName: "Exodus", chapter: 23, verse: 25,
                     slots: [.midday], burdens: [.health], topic: .healing),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 53, verse: 5,
                     slots: [.evening], burdens: [.health], topic: .healing),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 41, verse: 3,
                     slots: [.bedtime], burdens: [.health], topic: .healing),

        // MARK: Relationships
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 13, verse: 4,
                     slots: [.morning, .evening], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 4, verse: 32,
                     slots: [.midday], burdens: [.relationship, .anger], topic: .marriage),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 13,
                     slots: [.evening], burdens: [.relationship, .anger], topic: .marriage),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 4, verse: 8,
                     slots: [.evening], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 17, verse: 17,
                     slots: [.morning], burdens: [.relationship, .loneliness], topic: .marriage),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 12, verse: 18,
                     slots: [.midday], burdens: [.relationship, .anger], topic: .marriage),

        // MARK: Anger
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 1, verse: 19,
                     slots: [.morning, .midday], burdens: [.anger], topic: .strength),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 4, verse: 26,
                     slots: [.evening], burdens: [.anger], topic: .strength),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 15, verse: 1,
                     slots: [.midday], burdens: [.anger], topic: .strength),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 14, verse: 29,
                     slots: [.morning], burdens: [.anger], topic: .strength),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 8,
                     slots: [.evening], burdens: [.anger], topic: .strength),

        // MARK: Purpose
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 2, verse: 10,
                     slots: [.morning], burdens: [.purpose], topic: .encouragement),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 31,
                     slots: [.morning, .midday], burdens: [.purpose, .doubt], topic: .encouragement),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 139, verse: 14,
                     slots: [.morning], burdens: [.purpose], topic: .encouragement),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 16, verse: 3,
                     slots: [.morning], burdens: [.purpose], topic: .encouragement),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 43, verse: 7,
                     slots: [.midday], burdens: [.purpose], topic: .encouragement),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 1, verse: 6,
                     slots: [.evening], burdens: [.purpose, .doubt], topic: .encouragement),

        // MARK: Bedtime / Peace
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 4, verse: 8,
                     slots: [.bedtime], burdens: [.anxiety], topic: .eveningPeace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 91, verse: 1,
                     slots: [.bedtime], burdens: [], topic: .eveningPeace),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 3, verse: 24,
                     slots: [.bedtime], burdens: [.anxiety], topic: .eveningPeace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 121, verse: 4,
                     slots: [.bedtime], burdens: [], topic: .eveningPeace),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 26, verse: 3,
                     slots: [.bedtime, .evening], burdens: [.anxiety, .doubt], topic: .eveningPeace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 23, verse: 4,
                     slots: [.bedtime, .evening], burdens: [.grief, .loneliness], topic: .eveningPeace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 127, verse: 2,
                     slots: [.bedtime], burdens: [.anxiety, .financial], topic: .eveningPeace),
        CuratedVerse(bookID: "ZEP", bookName: "Zephaniah", chapter: 3, verse: 17,
                     slots: [.bedtime], burdens: [.loneliness], topic: .eveningPeace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 63, verse: 6,
                     slots: [.bedtime], burdens: [], topic: .eveningPeace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 16, verse: 7,
                     slots: [.bedtime], burdens: [.doubt], topic: .eveningPeace),

        // MARK: Gratitude & Thanksgiving
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 100, verse: 4,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "1TH", bookName: "1 Thessalonians", chapter: 5, verse: 18,
                     slots: [.morning, .evening], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 15,
                     slots: [.morning], burdens: [.anxiety], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 107, verse: 1,
                     slots: [.morning, .evening], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 136, verse: 1,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 9, verse: 1,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 5, verse: 20,
                     slots: [.evening], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 95, verse: 2,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 106, verse: 1,
                     slots: [.morning, .midday], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 17,
                     slots: [.morning], burdens: [.purpose], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 103, verse: 2,
                     slots: [.evening], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 34, verse: 1,
                     slots: [.morning, .midday], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 4, verse: 4,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 145, verse: 3,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 50, verse: 14,
                     slots: [.evening], burdens: [], topic: .gratitude),

        // MARK: Strength & Courage
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 40, verse: 29,
                     slots: [.morning, .midday], burdens: [.health, .anxiety], topic: .strength),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 4, verse: 13,
                     slots: [.morning, .midday], burdens: [.doubt, .purpose], topic: .strength),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 12, verse: 9,
                     slots: [.midday, .evening], burdens: [.health, .doubt], topic: .strength),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 6, verse: 10,
                     slots: [.morning], burdens: [.temptation], topic: .strength),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 31, verse: 6,
                     slots: [.morning], burdens: [.loneliness, .doubt], topic: .strength),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 18, verse: 32,
                     slots: [.morning], burdens: [], topic: .strength),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 28, verse: 7,
                     slots: [.morning, .midday], burdens: [.anxiety], topic: .strength),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 41, verse: 13,
                     slots: [.midday], burdens: [.anxiety, .loneliness], topic: .strength),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 27, verse: 1,
                     slots: [.morning], burdens: [.doubt], topic: .strength),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 73, verse: 26,
                     slots: [.evening], burdens: [.health, .grief], topic: .strength),
        CuratedVerse(bookID: "NEH", bookName: "Nehemiah", chapter: 8, verse: 10,
                     slots: [.morning, .midday], burdens: [.grief], topic: .strength),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 31, verse: 24,
                     slots: [.morning], burdens: [.doubt], topic: .strength),
        CuratedVerse(bookID: "2TI", bookName: "2 Timothy", chapter: 4, verse: 17,
                     slots: [.midday], burdens: [.loneliness], topic: .strength),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 46, verse: 1,
                     slots: [.morning, .evening], burdens: [.anxiety], topic: .strength),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 12, verse: 2,
                     slots: [.morning], burdens: [.doubt, .anxiety], topic: .strength),

        // MARK: God's Love
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 5, verse: 8,
                     slots: [.morning, .evening], burdens: [.doubt], topic: .godsLove),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 31, verse: 3,
                     slots: [.bedtime], burdens: [.loneliness], topic: .godsLove),
        CuratedVerse(bookID: "1JN", bookName: "1 John", chapter: 4, verse: 19,
                     slots: [.morning], burdens: [.relationship], topic: .godsLove),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 3, verse: 16,
                     slots: [.morning, .evening], burdens: [.doubt], topic: .godsLove),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 39,
                     slots: [.bedtime], burdens: [.loneliness, .doubt], topic: .godsLove),
        CuratedVerse(bookID: "1JN", bookName: "1 John", chapter: 4, verse: 16,
                     slots: [.evening], burdens: [], topic: .godsLove),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 86, verse: 15,
                     slots: [.midday], burdens: [.anger], topic: .godsLove),
        CuratedVerse(bookID: "1JN", bookName: "1 John", chapter: 3, verse: 1,
                     slots: [.morning], burdens: [.purpose], topic: .godsLove),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 36, verse: 7,
                     slots: [.evening], burdens: [], topic: .godsLove),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 37,
                     slots: [.morning], burdens: [.doubt], topic: .godsLove),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 3, verse: 18,
                     slots: [.evening], burdens: [.loneliness], topic: .godsLove),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 103, verse: 8,
                     slots: [.midday], burdens: [.anger], topic: .godsLove),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 54, verse: 10,
                     slots: [.bedtime], burdens: [.grief, .loneliness], topic: .godsLove),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 136, verse: 26,
                     slots: [.evening], burdens: [], topic: .godsLove),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 2, verse: 20,
                     slots: [.morning], burdens: [.purpose], topic: .godsLove),

        // MARK: Wisdom
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 2, verse: 6,
                     slots: [.morning], burdens: [.doubt], topic: .wisdom),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 1, verse: 5,
                     slots: [.morning, .midday], burdens: [.doubt], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 4, verse: 7,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 9, verse: 10,
                     slots: [.morning], burdens: [.doubt], topic: .wisdom),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 2, verse: 3,
                     slots: [.midday], burdens: [.doubt], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 3, verse: 13,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 16, verse: 16,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 19, verse: 20,
                     slots: [.midday], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 105,
                     slots: [.evening], burdens: [.doubt], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 1, verse: 7,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 11, verse: 2,
                     slots: [.midday], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 30,
                     slots: [.midday], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 24, verse: 14,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 8, verse: 11,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "ECC", bookName: "Ecclesiastes", chapter: 7, verse: 12,
                     slots: [.midday], burdens: [.financial], topic: .wisdom),

        // MARK: Peace
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 16, verse: 33,
                     slots: [.morning, .evening], burdens: [.anxiety], topic: .peace),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 4, verse: 9,
                     slots: [.evening], burdens: [.anxiety], topic: .peace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 29, verse: 11,
                     slots: [.evening, .bedtime], burdens: [.anxiety], topic: .peace),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 15, verse: 13,
                     slots: [.morning], burdens: [.doubt], topic: .peace),
        CuratedVerse(bookID: "NUM", bookName: "Numbers", chapter: 6, verse: 26,
                     slots: [.bedtime], burdens: [], topic: .peace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 85, verse: 8,
                     slots: [.evening], burdens: [], topic: .peace),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 14,
                     slots: [.evening], burdens: [.relationship], topic: .peace),
        CuratedVerse(bookID: "2TH", bookName: "2 Thessalonians", chapter: 3, verse: 16,
                     slots: [.bedtime], burdens: [.anxiety], topic: .peace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 11,
                     slots: [.evening], burdens: [], topic: .peace),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 32, verse: 17,
                     slots: [.evening], burdens: [.anxiety], topic: .peace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 165,
                     slots: [.evening], burdens: [.anxiety], topic: .peace),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 5, verse: 9,
                     slots: [.midday], burdens: [.relationship, .anger], topic: .peace),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 14, verse: 17,
                     slots: [.midday], burdens: [], topic: .peace),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 5, verse: 22,
                     slots: [.morning], burdens: [], topic: .peace),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 14, verse: 1,
                     slots: [.evening, .bedtime], burdens: [.anxiety, .doubt], topic: .peace),

        // MARK: Hope
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 6, verse: 19,
                     slots: [.evening], burdens: [.doubt, .anxiety], topic: .hope),
        CuratedVerse(bookID: "LAM", bookName: "Lamentations", chapter: 3, verse: 25,
                     slots: [.morning], burdens: [.grief], topic: .hope),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 33, verse: 22,
                     slots: [.morning], burdens: [], topic: .hope),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 130, verse: 5,
                     slots: [.evening], burdens: [.grief], topic: .hope),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 5, verse: 5,
                     slots: [.morning], burdens: [.doubt], topic: .hope),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 42, verse: 11,
                     slots: [.evening], burdens: [.grief, .doubt], topic: .hope),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 24,
                     slots: [.morning], burdens: [.doubt], topic: .hope),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 62, verse: 5,
                     slots: [.evening], burdens: [.anxiety], topic: .hope),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 71, verse: 14,
                     slots: [.morning], burdens: [], topic: .hope),
        CuratedVerse(bookID: "MIC", bookName: "Micah", chapter: 7, verse: 7,
                     slots: [.morning], burdens: [.doubt], topic: .hope),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 1, verse: 3,
                     slots: [.morning], burdens: [.grief], topic: .hope),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 39, verse: 7,
                     slots: [.evening], burdens: [], topic: .hope),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 146, verse: 5,
                     slots: [.morning], burdens: [], topic: .hope),
        CuratedVerse(bookID: "TIT", bookName: "Titus", chapter: 2, verse: 13,
                     slots: [.evening], burdens: [], topic: .hope),

        // MARK: Faith
        CuratedVerse(bookID: "MRK", bookName: "Mark", chapter: 11, verse: 24,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 10, verse: 17,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 5, verse: 7,
                     slots: [.morning, .midday], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 17, verse: 20,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 11, verse: 6,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "1JN", bookName: "1 John", chapter: 5, verse: 4,
                     slots: [.morning], burdens: [.temptation], topic: .faith),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 21, verse: 22,
                     slots: [.morning], burdens: [], topic: .faith),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 3, verse: 11,
                     slots: [.midday], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 20, verse: 29,
                     slots: [.evening], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 10, verse: 23,
                     slots: [.evening], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 1, verse: 8,
                     slots: [.evening], burdens: [], topic: .faith),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 4, verse: 20,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 12, verse: 2,
                     slots: [.morning], burdens: [], topic: .faith),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 2, verse: 17,
                     slots: [.midday], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "MRK", bookName: "Mark", chapter: 5, verse: 36,
                     slots: [.evening], burdens: [.anxiety, .doubt], topic: .faith),

        // MARK: Forgiveness
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 6, verse: 14,
                     slots: [.evening], burdens: [.anger, .relationship], topic: .forgiveness),
        CuratedVerse(bookID: "1JN", bookName: "1 John", chapter: 1, verse: 9,
                     slots: [.bedtime], burdens: [.temptation], topic: .forgiveness),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 103, verse: 12,
                     slots: [.bedtime], burdens: [.temptation, .doubt], topic: .forgiveness),
        CuratedVerse(bookID: "ACT", bookName: "Acts", chapter: 3, verse: 19,
                     slots: [.morning], burdens: [.temptation], topic: .forgiveness),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 1, verse: 18,
                     slots: [.morning], burdens: [.temptation], topic: .forgiveness),
        CuratedVerse(bookID: "MIC", bookName: "Micah", chapter: 7, verse: 18,
                     slots: [.evening], burdens: [], topic: .forgiveness),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 32, verse: 5,
                     slots: [.bedtime], burdens: [.temptation], topic: .forgiveness),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 1, verse: 7,
                     slots: [.morning], burdens: [.doubt], topic: .forgiveness),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 8, verse: 12,
                     slots: [.bedtime], burdens: [], topic: .forgiveness),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 1,
                     slots: [.morning], burdens: [.temptation, .doubt], topic: .forgiveness),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 51, verse: 10,
                     slots: [.morning, .bedtime], burdens: [.temptation], topic: .forgiveness),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 6, verse: 37,
                     slots: [.midday], burdens: [.relationship, .anger], topic: .forgiveness),

        // MARK: Joy
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 16, verse: 11,
                     slots: [.morning], burdens: [.grief], topic: .joy),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 1, verse: 2,
                     slots: [.morning], burdens: [.doubt], topic: .joy),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 15, verse: 11,
                     slots: [.morning], burdens: [], topic: .joy),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 126, verse: 3,
                     slots: [.morning], burdens: [], topic: .joy),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 30, verse: 11,
                     slots: [.morning], burdens: [.grief], topic: .joy),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 61, verse: 3,
                     slots: [.morning], burdens: [.grief], topic: .joy),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 47, verse: 1,
                     slots: [.morning], burdens: [], topic: .joy),
        CuratedVerse(bookID: "HAB", bookName: "Habakkuk", chapter: 3, verse: 18,
                     slots: [.morning], burdens: [.doubt, .financial], topic: .joy),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 98, verse: 4,
                     slots: [.morning], burdens: [], topic: .joy),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 5, verse: 11,
                     slots: [.morning], burdens: [], topic: .joy),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 1, verse: 6,
                     slots: [.midday], burdens: [.grief], topic: .joy),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 68, verse: 3,
                     slots: [.morning], burdens: [], topic: .joy),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 55, verse: 12,
                     slots: [.morning], burdens: [], topic: .joy),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 16, verse: 22,
                     slots: [.evening], burdens: [.grief], topic: .joy),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 12, verse: 15,
                     slots: [.midday], burdens: [.relationship], topic: .joy),

        // MARK: Patience & Perseverance
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 1, verse: 3,
                     slots: [.morning, .midday], burdens: [.doubt], topic: .strength),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 5, verse: 3,
                     slots: [.morning], burdens: [.health, .doubt], topic: .strength),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 6, verse: 9,
                     slots: [.midday], burdens: [.purpose], topic: .strength),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 10, verse: 36,
                     slots: [.midday], burdens: [.doubt], topic: .strength),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 27, verse: 14,
                     slots: [.morning], burdens: [.anxiety], topic: .strength),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 30, verse: 18,
                     slots: [.evening], burdens: [.doubt], topic: .strength),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 7,
                     slots: [.evening], burdens: [.anxiety], topic: .strength),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 12, verse: 1,
                     slots: [.morning], burdens: [.temptation], topic: .strength),
        CuratedVerse(bookID: "2PE", bookName: "2 Peter", chapter: 3, verse: 9,
                     slots: [.midday], burdens: [], topic: .strength),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 40, verse: 1,
                     slots: [.evening], burdens: [], topic: .strength),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 5, verse: 11,
                     slots: [.midday], burdens: [.health], topic: .strength),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 1, verse: 11,
                     slots: [.morning], burdens: [], topic: .strength),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 5, verse: 7,
                     slots: [.evening], burdens: [], topic: .strength),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 25,
                     slots: [.midday], burdens: [], topic: .strength),

        // MARK: Trust
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 56, verse: 3,
                     slots: [.morning, .bedtime], burdens: [.anxiety], topic: .trust),
        CuratedVerse(bookID: "NAH", bookName: "Nahum", chapter: 1, verse: 7,
                     slots: [.evening], burdens: [.anxiety], topic: .trust),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 5,
                     slots: [.morning], burdens: [.anxiety, .purpose], topic: .trust),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 62, verse: 8,
                     slots: [.evening], burdens: [.anxiety], topic: .trust),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 9, verse: 10,
                     slots: [.morning], burdens: [.loneliness], topic: .trust),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 20, verse: 7,
                     slots: [.morning], burdens: [], topic: .trust),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 112, verse: 7,
                     slots: [.midday], burdens: [.anxiety], topic: .trust),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 26, verse: 4,
                     slots: [.morning], burdens: [.anxiety], topic: .trust),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 125, verse: 1,
                     slots: [.morning], burdens: [], topic: .trust),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 115, verse: 11,
                     slots: [.morning], burdens: [], topic: .trust),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 40, verse: 4,
                     slots: [.morning], burdens: [], topic: .trust),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 33, verse: 21,
                     slots: [.evening], burdens: [], topic: .trust),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 84, verse: 12,
                     slots: [.morning], burdens: [], topic: .trust),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 29, verse: 25,
                     slots: [.midday], burdens: [.anxiety], topic: .trust),

        // MARK: Protection
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 91, verse: 2,
                     slots: [.bedtime], burdens: [.anxiety], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 121, verse: 7,
                     slots: [.bedtime], burdens: [.anxiety], topic: .spiritualWarfare),
        CuratedVerse(bookID: "2TH", bookName: "2 Thessalonians", chapter: 3, verse: 3,
                     slots: [.morning, .bedtime], burdens: [.temptation], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 46, verse: 7,
                     slots: [.evening], burdens: [], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 121, verse: 3,
                     slots: [.bedtime], burdens: [], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 32, verse: 7,
                     slots: [.evening], burdens: [.anxiety], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 18, verse: 2,
                     slots: [.morning], burdens: [], topic: .spiritualWarfare),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 33, verse: 27,
                     slots: [.bedtime], burdens: [.loneliness], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 34, verse: 7,
                     slots: [.bedtime], burdens: [], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 91, verse: 4,
                     slots: [.bedtime], burdens: [.anxiety], topic: .spiritualWarfare),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 54, verse: 17,
                     slots: [.morning], burdens: [], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 3, verse: 3,
                     slots: [.morning], burdens: [], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 59, verse: 16,
                     slots: [.morning], burdens: [], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 18, verse: 10,
                     slots: [.midday], burdens: [.anxiety], topic: .spiritualWarfare),

        // MARK: Provision
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 6, verse: 26,
                     slots: [.morning], burdens: [.financial, .anxiety], topic: .provision),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 9, verse: 8,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 34, verse: 10,
                     slots: [.midday], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 12, verse: 24,
                     slots: [.morning], burdens: [.financial, .anxiety], topic: .provision),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 145, verse: 16,
                     slots: [.midday], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 6, verse: 31,
                     slots: [.morning], burdens: [.financial, .anxiety], topic: .provision),
        CuratedVerse(bookID: "GEN", bookName: "Genesis", chapter: 22, verse: 14,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 4,
                     slots: [.morning], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 84, verse: 11,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 58, verse: 11,
                     slots: [.midday], burdens: [], topic: .provision),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 132, verse: 15,
                     slots: [.evening], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 111, verse: 5,
                     slots: [.midday], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "JOL", bookName: "Joel", chapter: 2, verse: 26,
                     slots: [.evening], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 65, verse: 9,
                     slots: [.morning], burdens: [], topic: .provision),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 7, verse: 11,
                     slots: [.morning], burdens: [], topic: .provision),

        // MARK: Identity in Christ
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 2, verse: 9,
                     slots: [.morning], burdens: [.purpose], topic: .encouragement),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 1, verse: 12,
                     slots: [.morning], burdens: [.loneliness], topic: .encouragement),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 15, verse: 16,
                     slots: [.morning], burdens: [.purpose, .doubt], topic: .encouragement),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 17,
                     slots: [.morning], burdens: [.purpose], topic: .encouragement),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 5, verse: 20,
                     slots: [.midday], burdens: [.purpose], topic: .encouragement),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 1, verse: 4,
                     slots: [.morning], burdens: [.purpose, .doubt], topic: .encouragement),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 3,
                     slots: [.evening], burdens: [], topic: .encouragement),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 3, verse: 20,
                     slots: [.evening], burdens: [.purpose], topic: .encouragement),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 43, verse: 1,
                     slots: [.morning], burdens: [.loneliness], topic: .encouragement),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 3, verse: 12,
                     slots: [.morning], burdens: [.doubt], topic: .encouragement),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 1, verse: 5,
                     slots: [.morning], burdens: [.purpose], topic: .encouragement),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 6, verse: 19,
                     slots: [.morning], burdens: [.temptation, .health], topic: .encouragement),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 16,
                     slots: [.evening], burdens: [.loneliness], topic: .encouragement),
        CuratedVerse(bookID: "1JN", bookName: "1 John", chapter: 3, verse: 2,
                     slots: [.evening], burdens: [.purpose], topic: .encouragement),

        // MARK: Comfort & Healing
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 23, verse: 2,
                     slots: [.evening, .bedtime], burdens: [.anxiety], topic: .healing),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 34, verse: 17,
                     slots: [.evening], burdens: [.grief], topic: .healing),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 57, verse: 18,
                     slots: [.evening], burdens: [.health], topic: .healing),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 107, verse: 20,
                     slots: [.morning], burdens: [.health], topic: .healing),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 1, verse: 4,
                     slots: [.midday], burdens: [.grief], topic: .healing),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 73, verse: 23,
                     slots: [.evening], burdens: [.loneliness], topic: .healing),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 66, verse: 13,
                     slots: [.evening], burdens: [.grief, .loneliness], topic: .healing),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 116, verse: 7,
                     slots: [.evening], burdens: [.anxiety], topic: .healing),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 30, verse: 17,
                     slots: [.morning], burdens: [.health], topic: .healing),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 10, verse: 17,
                     slots: [.evening], burdens: [.loneliness], topic: .healing),

        // MARK: Guidance & Direction
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 32, verse: 8,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 3, verse: 6,
                     slots: [.morning], burdens: [.purpose, .doubt], topic: .wisdom),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 30, verse: 21,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 25, verse: 4,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 23,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 48, verse: 14,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 10, verse: 27,
                     slots: [.morning, .midday], burdens: [.doubt], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 25, verse: 9,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 48, verse: 17,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 143, verse: 10,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),

        // MARK: Obedience & Surrender
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 6, verse: 10,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 9, verse: 23,
                     slots: [.morning], burdens: [.temptation], topic: .faith),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 12, verse: 1,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "1SA", bookName: "1 Samuel", chapter: 15, verse: 22,
                     slots: [.morning], burdens: [], topic: .faith),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 14, verse: 15,
                     slots: [.morning], burdens: [], topic: .faith),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 4, verse: 10,
                     slots: [.evening], burdens: [], topic: .faith),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 51, verse: 17,
                     slots: [.evening], burdens: [.temptation], topic: .faith),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 6, verse: 13,
                     slots: [.morning], burdens: [.temptation], topic: .faith),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 16, verse: 24,
                     slots: [.morning], burdens: [], topic: .faith),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 2, verse: 13,
                     slots: [.morning], burdens: [.purpose], topic: .faith),

        // MARK: Rest & Sabbath
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 11, verse: 29,
                     slots: [.evening, .bedtime], burdens: [.anxiety], topic: .eveningPeace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 62, verse: 1,
                     slots: [.evening], burdens: [.anxiety], topic: .eveningPeace),
        CuratedVerse(bookID: "EXO", bookName: "Exodus", chapter: 33, verse: 14,
                     slots: [.evening], burdens: [.anxiety], topic: .eveningPeace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 7,
                     slots: [.evening, .bedtime], burdens: [.anxiety], topic: .eveningPeace),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 30, verse: 15,
                     slots: [.evening], burdens: [.anxiety], topic: .eveningPeace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 131, verse: 2,
                     slots: [.bedtime], burdens: [.anxiety], topic: .eveningPeace),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 4, verse: 9,
                     slots: [.bedtime], burdens: [], topic: .eveningPeace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 23, verse: 3,
                     slots: [.evening], burdens: [.health], topic: .eveningPeace),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 6, verse: 16,
                     slots: [.evening], burdens: [.anxiety], topic: .eveningPeace),
        CuratedVerse(bookID: "MRK", bookName: "Mark", chapter: 6, verse: 31,
                     slots: [.evening], burdens: [], topic: .eveningPeace),

        // MARK: Unity & Community
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 133, verse: 1,
                     slots: [.morning], burdens: [.relationship], topic: .encouragement),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 10, verse: 25,
                     slots: [.morning], burdens: [.loneliness], topic: .encouragement),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 6, verse: 2,
                     slots: [.midday], burdens: [.relationship], topic: .encouragement),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 12, verse: 10,
                     slots: [.midday], burdens: [.relationship], topic: .encouragement),
        CuratedVerse(bookID: "1TH", bookName: "1 Thessalonians", chapter: 5, verse: 11,
                     slots: [.midday], burdens: [.relationship, .loneliness], topic: .encouragement),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 4, verse: 3,
                     slots: [.morning], burdens: [.relationship], topic: .encouragement),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 12, verse: 26,
                     slots: [.midday], burdens: [.loneliness], topic: .encouragement),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 2, verse: 3,
                     slots: [.morning], burdens: [.relationship], topic: .encouragement),

        // MARK: Generosity & Service
        CuratedVerse(bookID: "ACT", bookName: "Acts", chapter: 20, verse: 35,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 11, verse: 25,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 9, verse: 7,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 6, verse: 38,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 25, verse: 40,
                     slots: [.midday], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 5, verse: 13,
                     slots: [.midday], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 4, verse: 10,
                     slots: [.morning], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 13, verse: 16,
                     slots: [.midday], burdens: [], topic: .provision),

        // MARK: Marriage
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 5, verse: 25,
                     slots: [.morning, .evening], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "GEN", bookName: "Genesis", chapter: 2, verse: 24,
                     slots: [.evening], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "MRK", bookName: "Mark", chapter: 10, verse: 9,
                     slots: [.morning], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "SNG", bookName: "Song of Solomon", chapter: 8, verse: 7,
                     slots: [.evening], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 18, verse: 22,
                     slots: [.morning], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 31, verse: 10,
                     slots: [.morning], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 7, verse: 3,
                     slots: [.evening], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 5, verse: 28,
                     slots: [.evening], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 5, verse: 33,
                     slots: [.morning], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 19,
                     slots: [.evening], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "SNG", bookName: "Song of Solomon", chapter: 2, verse: 16,
                     slots: [.evening], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 13, verse: 4,
                     slots: [.morning], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 19, verse: 6,
                     slots: [.morning], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 13, verse: 7,
                     slots: [.evening], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 5, verse: 18,
                     slots: [.evening], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "ECC", bookName: "Ecclesiastes", chapter: 4, verse: 9,
                     slots: [.morning], burdens: [.relationship, .loneliness], topic: .marriage),
        CuratedVerse(bookID: "SNG", bookName: "Song of Solomon", chapter: 4, verse: 7,
                     slots: [.evening], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 3, verse: 7,
                     slots: [.evening], burdens: [.relationship], topic: .marriage),

        // MARK: Parenting
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 22, verse: 6,
                     slots: [.morning], burdens: [.purpose], topic: .parenting),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 6, verse: 7,
                     slots: [.morning], burdens: [.purpose], topic: .parenting),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 127, verse: 3,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 6, verse: 4,
                     slots: [.morning], burdens: [.anger], topic: .parenting),
        CuratedVerse(bookID: "3JN", bookName: "3 John", chapter: 1, verse: 4,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 29, verse: 17,
                     slots: [.morning], burdens: [.purpose], topic: .parenting),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 54, verse: 13,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 17, verse: 6,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 22, verse: 15,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 6, verse: 6,
                     slots: [.morning], burdens: [.purpose], topic: .parenting),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 21,
                     slots: [.morning], burdens: [.anger], topic: .parenting),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 13, verse: 24,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 18, verse: 3,
                     slots: [.morning], burdens: [.doubt], topic: .parenting),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 19, verse: 14,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 78, verse: 4,
                     slots: [.morning], burdens: [.purpose], topic: .parenting),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 20, verse: 7,
                     slots: [.morning], burdens: [.purpose], topic: .parenting),

        // MARK: Work & Diligence
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 23,
                     slots: [.morning, .midday], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 14, verse: 23,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "ECC", bookName: "Ecclesiastes", chapter: 9, verse: 10,
                     slots: [.morning], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "2TH", bookName: "2 Thessalonians", chapter: 3, verse: 10,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 12, verse: 11,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 13, verse: 4,
                     slots: [.morning], burdens: [.financial, .purpose], topic: .provision),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 12, verse: 24,
                     slots: [.morning], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 10, verse: 4,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "GEN", bookName: "Genesis", chapter: 2, verse: 15,
                     slots: [.morning], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "ECC", bookName: "Ecclesiastes", chapter: 3, verse: 13,
                     slots: [.midday], burdens: [], topic: .provision),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 90, verse: 17,
                     slots: [.morning], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 16, verse: 9,
                     slots: [.morning], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 21, verse: 5,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 15, verse: 58,
                     slots: [.morning, .midday], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "2TI", bookName: "2 Timothy", chapter: 2, verse: 15,
                     slots: [.morning], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 6, verse: 6,
                     slots: [.morning], burdens: [.financial], topic: .provision),

        // MARK: Worship
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 95, verse: 1,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 100, verse: 2,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 4, verse: 24,
                     slots: [.morning], burdens: [.doubt], topic: .gratitude),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 13, verse: 15,
                     slots: [.morning, .midday], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 150, verse: 6,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 29, verse: 2,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 96, verse: 9,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 12, verse: 2,
                     slots: [.morning], burdens: [.temptation], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 63, verse: 3,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 99, verse: 5,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 66, verse: 4,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 86, verse: 9,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "EXO", bookName: "Exodus", chapter: 15, verse: 2,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 22, verse: 3,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 148, verse: 13,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 33, verse: 1,
                     slots: [.morning], burdens: [], topic: .gratitude),

        // MARK: Salvation
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 10, verse: 9,
                     slots: [.morning, .evening], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 2, verse: 8,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "ACT", bookName: "Acts", chapter: 16, verse: 31,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "TIT", bookName: "Titus", chapter: 3, verse: 5,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 6, verse: 23,
                     slots: [.evening], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "ACT", bookName: "Acts", chapter: 4, verse: 12,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 14, verse: 6,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 5, verse: 24,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 10, verse: 13,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 10, verse: 28,
                     slots: [.evening, .bedtime], burdens: [.doubt, .anxiety], topic: .faith),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 5, verse: 17,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 3, verse: 17,
                     slots: [.evening], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 5, verse: 9,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "1JN", bookName: "1 John", chapter: 5, verse: 13,
                     slots: [.evening], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 6, verse: 47,
                     slots: [.evening], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 1, verse: 13,
                     slots: [.morning], burdens: [.doubt], topic: .faith),

        // MARK: Prayer Life
        CuratedVerse(bookID: "1TH", bookName: "1 Thessalonians", chapter: 5, verse: 17,
                     slots: [.morning, .midday], burdens: [], topic: .prayers),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 7, verse: 7,
                     slots: [.morning], burdens: [.doubt], topic: .prayers),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 5, verse: 16,
                     slots: [.morning], burdens: [.health], topic: .prayers),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 145, verse: 18,
                     slots: [.morning, .evening], burdens: [.loneliness], topic: .prayers),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 33, verse: 3,
                     slots: [.morning], burdens: [.doubt], topic: .prayers),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 26,
                     slots: [.evening], burdens: [.doubt], topic: .prayers),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 6, verse: 6,
                     slots: [.morning, .bedtime], burdens: [], topic: .prayers),
        CuratedVerse(bookID: "1JN", bookName: "1 John", chapter: 5, verse: 14,
                     slots: [.morning], burdens: [.doubt], topic: .prayers),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 5, verse: 2,
                     slots: [.morning], burdens: [], topic: .prayers),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 55, verse: 17,
                     slots: [.morning, .midday, .evening], burdens: [.anxiety], topic: .prayers),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 18, verse: 1,
                     slots: [.morning], burdens: [.doubt], topic: .prayers),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 17, verse: 6,
                     slots: [.morning], burdens: [], topic: .prayers),
        CuratedVerse(bookID: "MRK", bookName: "Mark", chapter: 11, verse: 25,
                     slots: [.evening], burdens: [.relationship, .anger], topic: .prayers),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 18, verse: 19,
                     slots: [.evening], burdens: [], topic: .prayers),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 102, verse: 17,
                     slots: [.evening], burdens: [.grief], topic: .prayers),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 15, verse: 7,
                     slots: [.morning], burdens: [], topic: .prayers),

        // MARK: Humility
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 2, verse: 5,
                     slots: [.morning], burdens: [.relationship], topic: .wisdom),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 5, verse: 6,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 22, verse: 4,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 23, verse: 12,
                     slots: [.midday], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 15, verse: 33,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "ZEP", bookName: "Zephaniah", chapter: 2, verse: 3,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 14, verse: 11,
                     slots: [.midday], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 18, verse: 4,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 27, verse: 2,
                     slots: [.midday], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 57, verse: 15,
                     slots: [.evening], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 12,
                     slots: [.morning], burdens: [.relationship], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 16, verse: 18,
                     slots: [.midday], burdens: [.temptation], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 147, verse: 6,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 4, verse: 2,
                     slots: [.morning], burdens: [.relationship], topic: .wisdom),
        CuratedVerse(bookID: "2CH", bookName: "2 Chronicles", chapter: 7, verse: 14,
                     slots: [.evening], burdens: [], topic: .wisdom),

        // MARK: Grace
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 2, verse: 9,
                     slots: [.morning], burdens: [.doubt], topic: .godsLove),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 6, verse: 14,
                     slots: [.morning], burdens: [.temptation], topic: .godsLove),
        CuratedVerse(bookID: "TIT", bookName: "Titus", chapter: 2, verse: 11,
                     slots: [.morning], burdens: [], topic: .godsLove),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 4, verse: 16,
                     slots: [.morning, .midday], burdens: [.doubt, .temptation], topic: .godsLove),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 3, verse: 24,
                     slots: [.morning], burdens: [.doubt], topic: .godsLove),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 8, verse: 9,
                     slots: [.morning], burdens: [.financial], topic: .godsLove),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 1, verse: 16,
                     slots: [.morning], burdens: [], topic: .godsLove),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 5, verse: 20,
                     slots: [.evening], burdens: [.temptation], topic: .godsLove),
        CuratedVerse(bookID: "2PE", bookName: "2 Peter", chapter: 3, verse: 18,
                     slots: [.morning], burdens: [], topic: .godsLove),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 11, verse: 6,
                     slots: [.morning], burdens: [.doubt], topic: .godsLove),
        CuratedVerse(bookID: "ACT", bookName: "Acts", chapter: 15, verse: 11,
                     slots: [.morning], burdens: [.doubt], topic: .godsLove),
        CuratedVerse(bookID: "2TI", bookName: "2 Timothy", chapter: 1, verse: 9,
                     slots: [.morning], burdens: [.purpose], topic: .godsLove),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 5, verse: 17,
                     slots: [.morning], burdens: [.doubt], topic: .godsLove),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 1, verse: 4,
                     slots: [.morning], burdens: [], topic: .godsLove),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 9, verse: 14,
                     slots: [.evening], burdens: [], topic: .godsLove),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 5, verse: 10,
                     slots: [.evening], burdens: [.grief, .health], topic: .godsLove),

        // MARK: More Protection
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 91, verse: 11,
                     slots: [.bedtime], burdens: [.anxiety], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 121, verse: 8,
                     slots: [.morning, .bedtime], burdens: [], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 5, verse: 12,
                     slots: [.morning], burdens: [], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 17, verse: 8,
                     slots: [.bedtime], burdens: [.anxiety], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 27, verse: 5,
                     slots: [.evening], burdens: [.anxiety], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 61, verse: 3,
                     slots: [.evening], burdens: [.anxiety], topic: .spiritualWarfare),
        CuratedVerse(bookID: "2SA", bookName: "2 Samuel", chapter: 22, verse: 3,
                     slots: [.morning], burdens: [], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 91, verse: 10,
                     slots: [.bedtime], burdens: [.anxiety], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 144, verse: 2,
                     slots: [.morning], burdens: [], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 138, verse: 7,
                     slots: [.evening], burdens: [.anxiety], topic: .spiritualWarfare),

        // MARK: More Provision
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 23, verse: 1,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 36, verse: 8,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 68, verse: 19,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 33, verse: 16,
                     slots: [.midday], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 34, verse: 9,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 28, verse: 12,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 3,
                     slots: [.morning], burdens: [.financial, .anxiety], topic: .provision),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 104, verse: 28,
                     slots: [.evening], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 23, verse: 5,
                     slots: [.evening], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 12, verse: 31,
                     slots: [.morning], burdens: [.financial, .anxiety], topic: .provision),

        // MARK: More Identity in Christ
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 3, verse: 26,
                     slots: [.morning], burdens: [.purpose], topic: .encouragement),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 2, verse: 6,
                     slots: [.morning], burdens: [.purpose], topic: .encouragement),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 3, verse: 18,
                     slots: [.morning], burdens: [.purpose], topic: .encouragement),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 14,
                     slots: [.morning], burdens: [.purpose, .doubt], topic: .encouragement),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 4, verse: 7,
                     slots: [.morning], burdens: [.purpose, .loneliness], topic: .encouragement),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 2, verse: 19,
                     slots: [.morning], burdens: [.loneliness], topic: .encouragement),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 3, verse: 16,
                     slots: [.morning], burdens: [.purpose], topic: .encouragement),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 1, verse: 13,
                     slots: [.morning], burdens: [.doubt], topic: .encouragement),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 15, verse: 15,
                     slots: [.evening], burdens: [.loneliness], topic: .encouragement),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 15,
                     slots: [.morning], burdens: [.anxiety, .loneliness], topic: .encouragement),

        // MARK: Spiritual Warfare
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 6, verse: 11,
                     slots: [.morning], burdens: [.temptation], topic: .spiritualWarfare),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 6, verse: 12,
                     slots: [.morning], burdens: [.temptation, .doubt], topic: .spiritualWarfare),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 6, verse: 13,
                     slots: [.morning], burdens: [.temptation], topic: .spiritualWarfare),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 6, verse: 14,
                     slots: [.morning], burdens: [.temptation], topic: .spiritualWarfare),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 6, verse: 16,
                     slots: [.morning, .midday], burdens: [.temptation, .doubt], topic: .spiritualWarfare),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 6, verse: 17,
                     slots: [.morning], burdens: [.temptation], topic: .spiritualWarfare),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 6, verse: 18,
                     slots: [.morning, .evening], burdens: [.temptation], topic: .spiritualWarfare),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 10, verse: 4,
                     slots: [.morning], burdens: [.temptation, .doubt], topic: .spiritualWarfare),
        CuratedVerse(bookID: "1JN", bookName: "1 John", chapter: 4, verse: 4,
                     slots: [.morning, .midday], burdens: [.temptation, .doubt], topic: .spiritualWarfare),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 16, verse: 20,
                     slots: [.morning], burdens: [.temptation], topic: .spiritualWarfare),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 10, verse: 5,
                     slots: [.morning], burdens: [.temptation, .anxiety], topic: .spiritualWarfare),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 54, verse: 15,
                     slots: [.evening], burdens: [.anxiety], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 44, verse: 5,
                     slots: [.morning], burdens: [.temptation], topic: .spiritualWarfare),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 20, verse: 4,
                     slots: [.morning], burdens: [.anxiety], topic: .spiritualWarfare),
        CuratedVerse(bookID: "2CH", bookName: "2 Chronicles", chapter: 20, verse: 15,
                     slots: [.morning, .midday], burdens: [.anxiety, .doubt], topic: .spiritualWarfare),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 13, verse: 12,
                     slots: [.morning], burdens: [.temptation], topic: .spiritualWarfare),
        CuratedVerse(bookID: "1TI", bookName: "1 Timothy", chapter: 6, verse: 12,
                     slots: [.morning], burdens: [.temptation, .doubt], topic: .spiritualWarfare),
        CuratedVerse(bookID: "2TI", bookName: "2 Timothy", chapter: 4, verse: 7,
                     slots: [.evening], burdens: [.purpose], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 144, verse: 1,
                     slots: [.morning], burdens: [], topic: .spiritualWarfare),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 59, verse: 19,
                     slots: [.evening], burdens: [.temptation], topic: .spiritualWarfare),

        // MARK: Promises of God
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 1, verse: 20,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "JOS", bookName: "Joshua", chapter: 21, verse: 45,
                     slots: [.morning, .evening], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "2PE", bookName: "2 Peter", chapter: 1, verse: 4,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "NUM", bookName: "Numbers", chapter: 23, verse: 19,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 55, verse: 11,
                     slots: [.morning, .midday], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 7, verse: 9,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "JOS", bookName: "Joshua", chapter: 23, verse: 14,
                     slots: [.evening], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "1KI", bookName: "1 Kings", chapter: 8, verse: 56,
                     slots: [.evening], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 46, verse: 10,
                     slots: [.morning], burdens: [.doubt, .purpose], topic: .faith),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 145, verse: 13,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 40, verse: 8,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 29, verse: 13,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 89, verse: 34,
                     slots: [.evening], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 4, verse: 21,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 138, verse: 8,
                     slots: [.morning, .evening], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 49, verse: 16,
                     slots: [.evening], burdens: [.loneliness], topic: .faith),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 32, verse: 27,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 105, verse: 8,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 25, verse: 1,
                     slots: [.morning], burdens: [], topic: .faith),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 6, verse: 18,
                     slots: [.morning], burdens: [.doubt], topic: .faith),

        // MARK: Creation & Nature
        CuratedVerse(bookID: "GEN", bookName: "Genesis", chapter: 1, verse: 1,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 19, verse: 1,
                     slots: [.morning], burdens: [.doubt], topic: .gratitude),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 1, verse: 20,
                     slots: [.morning, .midday], burdens: [.doubt], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 104, verse: 24,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 40, verse: 26,
                     slots: [.evening], burdens: [.doubt], topic: .gratitude),
        CuratedVerse(bookID: "JOB", bookName: "Job", chapter: 12, verse: 7,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 1, verse: 16,
                     slots: [.morning], burdens: [.purpose], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 8, verse: 3,
                     slots: [.evening, .bedtime], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 104, verse: 33,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "GEN", bookName: "Genesis", chapter: 1, verse: 31,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 33, verse: 6,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 45, verse: 12,
                     slots: [.morning], burdens: [.purpose], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 24, verse: 1,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "JOB", bookName: "Job", chapter: 37, verse: 5,
                     slots: [.evening], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 19, verse: 2,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "NEH", bookName: "Nehemiah", chapter: 9, verse: 6,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 4, verse: 11,
                     slots: [.morning], burdens: [.purpose], topic: .gratitude),
        CuratedVerse(bookID: "JOB", bookName: "Job", chapter: 38, verse: 4,
                     slots: [.evening], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 8, verse: 1,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 11, verse: 3,
                     slots: [.morning], burdens: [.doubt], topic: .gratitude),

        // MARK: Heaven & Eternity
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 14, verse: 2,
                     slots: [.evening, .bedtime], burdens: [.grief], topic: .hope),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 2, verse: 9,
                     slots: [.evening, .bedtime], burdens: [.grief], topic: .hope),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 4, verse: 17,
                     slots: [.evening], burdens: [.grief, .health], topic: .hope),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 1, verse: 4,
                     slots: [.evening], burdens: [.grief], topic: .hope),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 14, verse: 3,
                     slots: [.bedtime], burdens: [.grief, .loneliness], topic: .hope),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 4, verse: 18,
                     slots: [.evening], burdens: [.doubt], topic: .hope),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 21, verse: 1,
                     slots: [.bedtime], burdens: [.grief], topic: .hope),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 22, verse: 5,
                     slots: [.bedtime], burdens: [], topic: .hope),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 6, verse: 20,
                     slots: [.evening], burdens: [.financial], topic: .hope),
        CuratedVerse(bookID: "1TH", bookName: "1 Thessalonians", chapter: 4, verse: 17,
                     slots: [.bedtime], burdens: [.grief, .loneliness], topic: .hope),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 2,
                     slots: [.morning], burdens: [.purpose], topic: .hope),
        CuratedVerse(bookID: "2TI", bookName: "2 Timothy", chapter: 4, verse: 8,
                     slots: [.evening], burdens: [.purpose], topic: .hope),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 7, verse: 17,
                     slots: [.bedtime], burdens: [.grief], topic: .hope),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 15, verse: 55,
                     slots: [.evening], burdens: [.grief], topic: .hope),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 11, verse: 25,
                     slots: [.morning, .evening], burdens: [.grief, .doubt], topic: .hope),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 21, verse: 3,
                     slots: [.bedtime], burdens: [.loneliness, .grief], topic: .hope),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 25, verse: 8,
                     slots: [.evening], burdens: [.grief], topic: .hope),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 15, verse: 54,
                     slots: [.morning], burdens: [.grief], topic: .hope),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 3, verse: 21,
                     slots: [.evening], burdens: [.health], topic: .hope),
        CuratedVerse(bookID: "2PE", bookName: "2 Peter", chapter: 3, verse: 13,
                     slots: [.evening], burdens: [], topic: .hope),

        // MARK: Children & Youth
        CuratedVerse(bookID: "1TI", bookName: "1 Timothy", chapter: 4, verse: 12,
                     slots: [.morning], burdens: [.purpose], topic: .parenting),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 9,
                     slots: [.morning], burdens: [.temptation], topic: .parenting),
        CuratedVerse(bookID: "ECC", bookName: "Ecclesiastes", chapter: 12, verse: 1,
                     slots: [.morning], burdens: [.purpose], topic: .parenting),
        CuratedVerse(bookID: "LAM", bookName: "Lamentations", chapter: 3, verse: 27,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 99,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 20, verse: 11,
                     slots: [.morning], burdens: [.purpose], topic: .parenting),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 71, verse: 5,
                     slots: [.morning], burdens: [.doubt], topic: .parenting),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 148, verse: 12,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "2TI", bookName: "2 Timothy", chapter: 3, verse: 15,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 1, verse: 8,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 40, verse: 30,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 100,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 4, verse: 1,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 8, verse: 2,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 1, verse: 7,
                     slots: [.morning], burdens: [.doubt, .purpose], topic: .parenting),
        CuratedVerse(bookID: "1SA", bookName: "1 Samuel", chapter: 2, verse: 26,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 23, verse: 24,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "DAN", bookName: "Daniel", chapter: 1, verse: 17,
                     slots: [.morning], burdens: [.purpose], topic: .parenting),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 18, verse: 10,
                     slots: [.evening], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 2, verse: 52,
                     slots: [.morning], burdens: [], topic: .parenting),

        // MARK: Fear of the Lord
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 111, verse: 10,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 10, verse: 12,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 33, verse: 8,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 25, verse: 14,
                     slots: [.morning, .evening], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 34, verse: 11,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 128, verse: 1,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 14, verse: 27,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 14, verse: 26,
                     slots: [.morning], burdens: [.anxiety], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 103, verse: 11,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 10, verse: 27,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 19, verse: 9,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 115, verse: 13,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 147, verse: 11,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 8, verse: 13,
                     slots: [.morning], burdens: [.temptation], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 3, verse: 7,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "ACT", bookName: "Acts", chapter: 9, verse: 31,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 19, verse: 23,
                     slots: [.evening, .bedtime], burdens: [.anxiety], topic: .wisdom),
        CuratedVerse(bookID: "MAL", bookName: "Malachi", chapter: 4, verse: 2,
                     slots: [.morning], burdens: [.health], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 112, verse: 1,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 33, verse: 6,
                     slots: [.morning], burdens: [], topic: .wisdom),

        // MARK: Justice & Righteousness
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 1, verse: 17,
                     slots: [.morning, .midday], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "AMO", bookName: "Amos", chapter: 5, verse: 24,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 89, verse: 14,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 21, verse: 3,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 6,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 61, verse: 8,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 106, verse: 3,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 31, verse: 9,
                     slots: [.morning, .midday], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "ZEC", bookName: "Zechariah", chapter: 7, verse: 9,
                     slots: [.morning], burdens: [.relationship], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 82, verse: 3,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 28, verse: 5,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 56, verse: 1,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 11, verse: 7,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 29, verse: 7,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 5, verse: 6,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 140, verse: 12,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 58, verse: 6,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 22, verse: 3,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 72, verse: 4,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 23, verse: 23,
                     slots: [.midday], burdens: [.purpose], topic: .wisdom),

        // MARK: Thanksgiving (Expanded)
        CuratedVerse(bookID: "1CH", bookName: "1 Chronicles", chapter: 16, verse: 34,
                     slots: [.morning, .evening], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 69, verse: 30,
                     slots: [.morning], burdens: [.grief], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 7, verse: 17,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 30, verse: 12,
                     slots: [.morning, .evening], burdens: [.grief], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 105, verse: 1,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 75, verse: 1,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 116, verse: 17,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "1CH", bookName: "1 Chronicles", chapter: 16, verse: 8,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 92, verse: 1,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 138, verse: 1,
                     slots: [.morning, .evening], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "DAN", bookName: "Daniel", chapter: 2, verse: 23,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 107, verse: 8,
                     slots: [.morning, .evening], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 12, verse: 28,
                     slots: [.morning], burdens: [], topic: .gratitude),

        // MARK: Renewal & Transformation
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 43, verse: 19,
                     slots: [.morning], burdens: [.purpose, .doubt], topic: .hope),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 4, verse: 16,
                     slots: [.morning, .evening], burdens: [.health, .grief], topic: .hope),
        CuratedVerse(bookID: "EZK", bookName: "Ezekiel", chapter: 36, verse: 26,
                     slots: [.morning], burdens: [.temptation], topic: .hope),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 51, verse: 12,
                     slots: [.morning], burdens: [.grief, .temptation], topic: .hope),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 6, verse: 4,
                     slots: [.morning], burdens: [.temptation, .purpose], topic: .hope),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 4, verse: 23,
                     slots: [.morning], burdens: [.temptation], topic: .hope),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 61, verse: 1,
                     slots: [.morning], burdens: [.grief], topic: .hope),
        CuratedVerse(bookID: "LAM", bookName: "Lamentations", chapter: 5, verse: 21,
                     slots: [.morning, .evening], burdens: [.doubt], topic: .hope),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 4, verse: 24,
                     slots: [.morning], burdens: [.temptation, .purpose], topic: .hope),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 43, verse: 18,
                     slots: [.morning], burdens: [.grief], topic: .hope),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 80, verse: 19,
                     slots: [.morning], burdens: [], topic: .hope),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 10,
                     slots: [.morning], burdens: [.purpose], topic: .hope),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 21, verse: 5,
                     slots: [.morning], burdens: [], topic: .hope),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 104, verse: 30,
                     slots: [.morning], burdens: [], topic: .hope),
        CuratedVerse(bookID: "JOL", bookName: "Joel", chapter: 2, verse: 25,
                     slots: [.morning], burdens: [.grief, .financial], topic: .hope),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 42, verse: 9,
                     slots: [.morning], burdens: [.purpose], topic: .hope),
        CuratedVerse(bookID: "EZK", bookName: "Ezekiel", chapter: 37, verse: 5,
                     slots: [.morning], burdens: [.doubt], topic: .hope),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 6, verse: 15,
                     slots: [.morning], burdens: [.purpose], topic: .hope),

        // MARK: Compassion & Mercy
        CuratedVerse(bookID: "LAM", bookName: "Lamentations", chapter: 3, verse: 22,
                     slots: [.morning], burdens: [.grief, .doubt], topic: .godsLove),
        CuratedVerse(bookID: "MIC", bookName: "Micah", chapter: 7, verse: 19,
                     slots: [.evening], burdens: [.temptation], topic: .godsLove),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 9, verse: 36,
                     slots: [.midday], burdens: [.relationship], topic: .godsLove),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 103, verse: 13,
                     slots: [.morning, .evening], burdens: [], topic: .godsLove),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 145, verse: 8,
                     slots: [.morning], burdens: [.anger], topic: .godsLove),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 145, verse: 9,
                     slots: [.morning], burdens: [], topic: .godsLove),
        CuratedVerse(bookID: "EXO", bookName: "Exodus", chapter: 34, verse: 6,
                     slots: [.morning], burdens: [.anger], topic: .godsLove),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 116, verse: 5,
                     slots: [.morning], burdens: [], topic: .godsLove),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 5, verse: 7,
                     slots: [.morning, .midday], burdens: [.relationship], topic: .godsLove),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 6, verse: 36,
                     slots: [.midday], burdens: [.relationship], topic: .godsLove),
        CuratedVerse(bookID: "HOS", bookName: "Hosea", chapter: 6, verse: 6,
                     slots: [.morning], burdens: [], topic: .godsLove),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 2, verse: 13,
                     slots: [.midday], burdens: [.relationship], topic: .godsLove),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 78, verse: 38,
                     slots: [.evening], burdens: [.temptation], topic: .godsLove),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 49, verse: 13,
                     slots: [.morning], burdens: [.grief], topic: .godsLove),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 4, verse: 15,
                     slots: [.evening], burdens: [.temptation], topic: .godsLove),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 103, verse: 4,
                     slots: [.morning], burdens: [.grief], topic: .godsLove),
        CuratedVerse(bookID: "JON", bookName: "Jonah", chapter: 4, verse: 2,
                     slots: [.evening], burdens: [.anger], topic: .godsLove),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 111, verse: 4,
                     slots: [.morning], burdens: [], topic: .godsLove),
        CuratedVerse(bookID: "DAN", bookName: "Daniel", chapter: 9, verse: 9,
                     slots: [.evening, .bedtime], burdens: [.temptation], topic: .godsLove),

        // MARK: More Morning Verses
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 59, verse: 17,
                     slots: [.morning], burdens: [], topic: .morningVerses),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 92, verse: 2,
                     slots: [.morning], burdens: [], topic: .morningVerses),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 108, verse: 2,
                     slots: [.morning], burdens: [], topic: .morningVerses),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 88, verse: 13,
                     slots: [.morning], burdens: [.grief], topic: .morningVerses),
        CuratedVerse(bookID: "MRK", bookName: "Mark", chapter: 1, verse: 35,
                     slots: [.morning], burdens: [], topic: .morningVerses),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 63, verse: 1,
                     slots: [.morning], burdens: [.loneliness], topic: .morningVerses),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 130, verse: 6,
                     slots: [.morning], burdens: [], topic: .morningVerses),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 50, verse: 4,
                     slots: [.morning], burdens: [.purpose], topic: .morningVerses),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 147,
                     slots: [.morning], burdens: [], topic: .morningVerses),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 8, verse: 17,
                     slots: [.morning], burdens: [], topic: .morningVerses),

        // MARK: More Bedtime Verses
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 91, verse: 5,
                     slots: [.bedtime], burdens: [.anxiety], topic: .eveningPeace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 3, verse: 5,
                     slots: [.bedtime], burdens: [.anxiety], topic: .eveningPeace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 121, verse: 5,
                     slots: [.bedtime], burdens: [.anxiety], topic: .eveningPeace),
        CuratedVerse(bookID: "JOB", bookName: "Job", chapter: 11, verse: 18,
                     slots: [.bedtime], burdens: [.anxiety], topic: .eveningPeace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 139, verse: 18,
                     slots: [.bedtime], burdens: [.loneliness], topic: .eveningPeace),
        CuratedVerse(bookID: "LEV", bookName: "Leviticus", chapter: 26, verse: 6,
                     slots: [.bedtime], burdens: [.anxiety], topic: .eveningPeace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 139, verse: 12,
                     slots: [.bedtime], burdens: [.anxiety], topic: .eveningPeace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 42, verse: 8,
                     slots: [.bedtime], burdens: [.loneliness], topic: .eveningPeace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 121, verse: 6,
                     slots: [.bedtime], burdens: [], topic: .eveningPeace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 16, verse: 9,
                     slots: [.bedtime], burdens: [], topic: .eveningPeace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 149, verse: 5,
                     slots: [.bedtime], burdens: [], topic: .eveningPeace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 4, verse: 4,
                     slots: [.bedtime], burdens: [.anger], topic: .eveningPeace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 134, verse: 1,
                     slots: [.bedtime], burdens: [], topic: .eveningPeace),

        // MARK: More Marriage Verses
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 13, verse: 13,
                     slots: [.evening], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 31, verse: 28,
                     slots: [.evening], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 31, verse: 30,
                     slots: [.morning], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 3, verse: 1,
                     slots: [.morning], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "RUT", bookName: "Ruth", chapter: 1, verse: 16,
                     slots: [.evening], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 5, verse: 21,
                     slots: [.evening], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 7, verse: 4,
                     slots: [.evening], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "SNG", bookName: "Song of Solomon", chapter: 1, verse: 2,
                     slots: [.evening], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "GEN", bookName: "Genesis", chapter: 2, verse: 18,
                     slots: [.morning], burdens: [.loneliness, .relationship], topic: .marriage),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 12, verse: 4,
                     slots: [.morning], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "ECC", bookName: "Ecclesiastes", chapter: 4, verse: 12,
                     slots: [.morning, .evening], burdens: [.relationship], topic: .marriage),
        CuratedVerse(bookID: "MAL", bookName: "Malachi", chapter: 2, verse: 14,
                     slots: [.evening], burdens: [.relationship], topic: .marriage),

        // MARK: More Parenting Verses
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 103, verse: 17,
                     slots: [.morning, .evening], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 44, verse: 3,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 112, verse: 2,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 23, verse: 13,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 11, verse: 19,
                     slots: [.morning], burdens: [.purpose], topic: .parenting),
        CuratedVerse(bookID: "GEN", bookName: "Genesis", chapter: 18, verse: 19,
                     slots: [.morning], burdens: [.purpose], topic: .parenting),
        CuratedVerse(bookID: "JOS", bookName: "Joshua", chapter: 24, verse: 15,
                     slots: [.morning, .evening], burdens: [.purpose], topic: .parenting),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 144, verse: 12,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 31, verse: 26,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "2TI", bookName: "2 Timothy", chapter: 1, verse: 5,
                     slots: [.morning], burdens: [], topic: .parenting),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 128, verse: 3,
                     slots: [.morning, .evening], burdens: [.relationship], topic: .parenting),

        // MARK: More Work & Diligence Verses
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 22, verse: 29,
                     slots: [.morning], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 6, verse: 7,
                     slots: [.morning, .midday], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 31, verse: 17,
                     slots: [.morning], burdens: [], topic: .provision),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 128, verse: 2,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 10, verse: 5,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "1TH", bookName: "1 Thessalonians", chapter: 4, verse: 11,
                     slots: [.morning], burdens: [], topic: .provision),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 18, verse: 9,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "GEN", bookName: "Genesis", chapter: 1, verse: 28,
                     slots: [.morning], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 27, verse: 23,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 24, verse: 27,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 28, verse: 19,
                     slots: [.morning], burdens: [.financial], topic: .provision),
        CuratedVerse(bookID: "ECC", bookName: "Ecclesiastes", chapter: 5, verse: 12,
                     slots: [.evening, .bedtime], burdens: [], topic: .provision),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 65, verse: 22,
                     slots: [.morning], burdens: [.financial, .purpose], topic: .provision),

        // MARK: - Holiness & Sanctification
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 1, verse: 15,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 1, verse: 16,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "LEV", bookName: "Leviticus", chapter: 20, verse: 7,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "1TH", bookName: "1 Thessalonians", chapter: 4, verse: 7,
                     slots: [.morning], burdens: [.temptation], topic: .faith),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 12, verse: 14,
                     slots: [.morning, .midday], burdens: [.relationship], topic: .faith),
        CuratedVerse(bookID: "2TI", bookName: "2 Timothy", chapter: 2, verse: 21,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 12, verse: 21,
                     slots: [.midday], burdens: [.anger, .temptation], topic: .faith),
        CuratedVerse(bookID: "1TH", bookName: "1 Thessalonians", chapter: 5, verse: 23,
                     slots: [.evening], burdens: [], topic: .faith),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 24, verse: 3,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 24, verse: 4,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "LEV", bookName: "Leviticus", chapter: 19, verse: 2,
                     slots: [.morning], burdens: [], topic: .faith),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 6, verse: 3,
                     slots: [.morning], burdens: [], topic: .faith),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 6, verse: 11,
                     slots: [.morning], burdens: [.temptation], topic: .faith),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 6, verse: 12,
                     slots: [.midday], burdens: [.temptation], topic: .faith),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 7, verse: 1,
                     slots: [.morning], burdens: [.temptation], topic: .faith),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 5, verse: 3,
                     slots: [.midday], burdens: [.temptation], topic: .faith),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 12, verse: 10,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 1, verse: 11,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 1, verse: 22,
                     slots: [.morning], burdens: [], topic: .faith),
        CuratedVerse(bookID: "1JN", bookName: "1 John", chapter: 3, verse: 3,
                     slots: [.morning], burdens: [.purpose], topic: .faith),

        // MARK: - Angels & Heavenly Beings
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 1, verse: 14,
                     slots: [.evening, .bedtime], burdens: [.anxiety], topic: .hope),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 13, verse: 2,
                     slots: [.midday], burdens: [.relationship], topic: .hope),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 103, verse: 20,
                     slots: [.morning], burdens: [], topic: .hope),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 103, verse: 21,
                     slots: [.morning], burdens: [], topic: .hope),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 91, verse: 12,
                     slots: [.evening, .bedtime], burdens: [.anxiety], topic: .hope),
        CuratedVerse(bookID: "EXO", bookName: "Exodus", chapter: 23, verse: 20,
                     slots: [.morning], burdens: [], topic: .hope),
        CuratedVerse(bookID: "GEN", bookName: "Genesis", chapter: 28, verse: 12,
                     slots: [.bedtime], burdens: [], topic: .hope),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 6, verse: 2,
                     slots: [.morning], burdens: [], topic: .hope),
        CuratedVerse(bookID: "DAN", bookName: "Daniel", chapter: 6, verse: 22,
                     slots: [.evening], burdens: [.anxiety], topic: .hope),
        CuratedVerse(bookID: "DAN", bookName: "Daniel", chapter: 3, verse: 28,
                     slots: [.morning], burdens: [.doubt], topic: .hope),
        CuratedVerse(bookID: "2KI", bookName: "2 Kings", chapter: 6, verse: 17,
                     slots: [.morning], burdens: [.doubt, .anxiety], topic: .hope),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 15, verse: 10,
                     slots: [.midday], burdens: [], topic: .hope),
        CuratedVerse(bookID: "ACT", bookName: "Acts", chapter: 12, verse: 7,
                     slots: [.evening], burdens: [.anxiety], topic: .hope),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 4, verse: 11,
                     slots: [.morning], burdens: [.temptation], topic: .hope),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 2, verse: 13,
                     slots: [.evening], burdens: [], topic: .hope),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 1, verse: 19,
                     slots: [.morning], burdens: [], topic: .hope),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 5, verse: 11,
                     slots: [.evening], burdens: [], topic: .hope),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 148, verse: 2,
                     slots: [.morning], burdens: [], topic: .hope),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 26, verse: 53,
                     slots: [.midday], burdens: [.anxiety], topic: .hope),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 12, verse: 22,
                     slots: [.evening], burdens: [], topic: .hope),

        // MARK: - Church / Body of Christ
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 12, verse: 12,
                     slots: [.morning], burdens: [.loneliness], topic: .encouragement),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 12, verse: 27,
                     slots: [.morning], burdens: [.loneliness, .purpose], topic: .encouragement),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 4, verse: 11,
                     slots: [.morning], burdens: [.purpose], topic: .encouragement),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 4, verse: 12,
                     slots: [.morning], burdens: [.purpose], topic: .encouragement),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 4, verse: 16,
                     slots: [.midday], burdens: [.loneliness], topic: .encouragement),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 1, verse: 18,
                     slots: [.morning], burdens: [], topic: .encouragement),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 12, verse: 4,
                     slots: [.midday], burdens: [.purpose], topic: .encouragement),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 12, verse: 5,
                     slots: [.midday], burdens: [.loneliness], topic: .encouragement),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 2, verse: 20,
                     slots: [.morning], burdens: [.doubt], topic: .encouragement),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 2, verse: 21,
                     slots: [.morning], burdens: [.loneliness], topic: .encouragement),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 16, verse: 18,
                     slots: [.morning], burdens: [.doubt], topic: .encouragement),
        CuratedVerse(bookID: "ACT", bookName: "Acts", chapter: 2, verse: 42,
                     slots: [.morning], burdens: [.loneliness], topic: .encouragement),
        CuratedVerse(bookID: "ACT", bookName: "Acts", chapter: 2, verse: 46,
                     slots: [.midday], burdens: [.loneliness], topic: .encouragement),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 12, verse: 18,
                     slots: [.midday], burdens: [.purpose], topic: .encouragement),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 12, verse: 21,
                     slots: [.midday], burdens: [.purpose, .loneliness], topic: .encouragement),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 4, verse: 4,
                     slots: [.morning], burdens: [.loneliness], topic: .encouragement),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 4, verse: 15,
                     slots: [.midday], burdens: [.relationship], topic: .encouragement),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 3, verse: 28,
                     slots: [.morning], burdens: [.loneliness], topic: .encouragement),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 5, verse: 23,
                     slots: [.morning], burdens: [], topic: .encouragement),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 16,
                     slots: [.evening], burdens: [], topic: .encouragement),

        // MARK: - Victory in Christ
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 15, verse: 57,
                     slots: [.morning], burdens: [.doubt], topic: .strength),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 2, verse: 14,
                     slots: [.morning], burdens: [], topic: .strength),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 12, verse: 11,
                     slots: [.morning], burdens: [.temptation], topic: .strength),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 20, verse: 1,
                     slots: [.morning], burdens: [.anxiety, .doubt], topic: .strength),
        CuratedVerse(bookID: "JOS", bookName: "Joshua", chapter: 10, verse: 25,
                     slots: [.morning], burdens: [.anxiety], topic: .strength),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 25, verse: 9,
                     slots: [.morning], burdens: [.doubt], topic: .strength),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 35,
                     slots: [.midday], burdens: [.doubt, .loneliness], topic: .strength),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 15, verse: 56,
                     slots: [.morning], burdens: [.temptation], topic: .strength),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 2, verse: 7,
                     slots: [.morning], burdens: [.temptation], topic: .strength),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 2, verse: 11,
                     slots: [.morning], burdens: [], topic: .strength),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 2, verse: 17,
                     slots: [.morning], burdens: [], topic: .strength),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 3, verse: 5,
                     slots: [.morning], burdens: [], topic: .strength),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 3, verse: 21,
                     slots: [.morning], burdens: [.doubt], topic: .strength),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 16, verse: 11,
                     slots: [.midday], burdens: [], topic: .strength),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 44, verse: 6,
                     slots: [.morning], burdens: [.doubt], topic: .strength),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 44, verse: 7,
                     slots: [.morning], burdens: [], topic: .strength),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 60, verse: 12,
                     slots: [.morning], burdens: [.doubt], topic: .strength),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 54, verse: 14,
                     slots: [.morning], burdens: [.anxiety], topic: .strength),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 16, verse: 8,
                     slots: [.midday], burdens: [], topic: .strength),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 20, verse: 6,
                     slots: [.morning], burdens: [], topic: .strength),

        // MARK: - Ministry & Service
        CuratedVerse(bookID: "MRK", bookName: "Mark", chapter: 10, verse: 45,
                     slots: [.morning, .midday], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 25, verse: 35,
                     slots: [.midday], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 25, verse: 36,
                     slots: [.midday], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 20, verse: 28,
                     slots: [.morning], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 13, verse: 14,
                     slots: [.midday], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 13, verse: 15,
                     slots: [.midday], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 12, verse: 11,
                     slots: [.morning], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 9, verse: 19,
                     slots: [.midday], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 6, verse: 10,
                     slots: [.midday], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 2, verse: 15,
                     slots: [.midday], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 2, verse: 16,
                     slots: [.midday], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 6, verse: 10,
                     slots: [.morning], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 4, verse: 28,
                     slots: [.midday], burdens: [.financial, .purpose], topic: .provision),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 10, verse: 8,
                     slots: [.morning], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 58, verse: 7,
                     slots: [.midday], burdens: [.purpose], topic: .provision),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 10, verse: 27,
                     slots: [.morning, .midday], burdens: [.relationship], topic: .provision),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 15, verse: 1,
                     slots: [.midday], burdens: [.relationship], topic: .provision),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 2, verse: 4,
                     slots: [.midday], burdens: [.relationship], topic: .provision),
        CuratedVerse(bookID: "1TI", bookName: "1 Timothy", chapter: 6, verse: 18,
                     slots: [.midday], burdens: [.financial, .purpose], topic: .provision),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 5, verse: 16,
                     slots: [.morning], burdens: [.purpose], topic: .provision),

        // MARK: - Word of God / Scripture
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 4, verse: 12,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "2TI", bookName: "2 Timothy", chapter: 3, verse: 16,
                     slots: [.morning], burdens: [.doubt], topic: .wisdom),
        CuratedVerse(bookID: "JOS", bookName: "Joshua", chapter: 1, verse: 8,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 130,
                     slots: [.morning], burdens: [.doubt], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 160,
                     slots: [.morning], burdens: [.doubt], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 12, verse: 6,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 30, verse: 5,
                     slots: [.morning], burdens: [.doubt], topic: .wisdom),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 15, verse: 4,
                     slots: [.midday], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "2TI", bookName: "2 Timothy", chapter: 3, verse: 17,
                     slots: [.morning], burdens: [.purpose], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 89,
                     slots: [.evening], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 103,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 114,
                     slots: [.midday], burdens: [.anxiety], topic: .wisdom),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 4, verse: 4,
                     slots: [.morning], burdens: [.temptation], topic: .wisdom),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 15, verse: 16,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 19, verse: 7,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 19, verse: 8,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 50,
                     slots: [.evening], burdens: [.grief], topic: .wisdom),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 2, verse: 2,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 55, verse: 10,
                     slots: [.morning], burdens: [], topic: .wisdom),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 18,
                     slots: [.morning], burdens: [], topic: .wisdom),

        // MARK: - Repentance & Turning to God
        CuratedVerse(bookID: "JOL", bookName: "Joel", chapter: 2, verse: 12,
                     slots: [.morning, .evening], burdens: [.temptation], topic: .forgiveness),
        CuratedVerse(bookID: "JOL", bookName: "Joel", chapter: 2, verse: 13,
                     slots: [.morning, .evening], burdens: [], topic: .forgiveness),
        CuratedVerse(bookID: "EZK", bookName: "Ezekiel", chapter: 18, verse: 30,
                     slots: [.morning], burdens: [.temptation], topic: .forgiveness),
        CuratedVerse(bookID: "EZK", bookName: "Ezekiel", chapter: 18, verse: 31,
                     slots: [.morning], burdens: [.temptation], topic: .forgiveness),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 55, verse: 7,
                     slots: [.morning], burdens: [.temptation], topic: .forgiveness),
        CuratedVerse(bookID: "HOS", bookName: "Hosea", chapter: 14, verse: 1,
                     slots: [.morning], burdens: [.temptation], topic: .forgiveness),
        CuratedVerse(bookID: "HOS", bookName: "Hosea", chapter: 14, verse: 2,
                     slots: [.morning], burdens: [], topic: .forgiveness),
        CuratedVerse(bookID: "ACT", bookName: "Acts", chapter: 2, verse: 38,
                     slots: [.morning], burdens: [], topic: .forgiveness),
        CuratedVerse(bookID: "ACT", bookName: "Acts", chapter: 17, verse: 30,
                     slots: [.morning], burdens: [], topic: .forgiveness),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 13, verse: 3,
                     slots: [.evening], burdens: [.temptation], topic: .forgiveness),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 3, verse: 19,
                     slots: [.evening], burdens: [.temptation], topic: .forgiveness),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 44, verse: 22,
                     slots: [.morning], burdens: [.doubt], topic: .forgiveness),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 15, verse: 7,
                     slots: [.evening], burdens: [], topic: .forgiveness),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 15, verse: 18,
                     slots: [.evening], burdens: [], topic: .forgiveness),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 51, verse: 7,
                     slots: [.evening], burdens: [.temptation], topic: .forgiveness),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 51, verse: 1,
                     slots: [.evening], burdens: [.temptation], topic: .forgiveness),
        CuratedVerse(bookID: "MIC", bookName: "Micah", chapter: 7, verse: 8,
                     slots: [.morning], burdens: [.doubt], topic: .forgiveness),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 3, verse: 12,
                     slots: [.morning], burdens: [], topic: .forgiveness),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 3, verse: 22,
                     slots: [.morning], burdens: [], topic: .forgiveness),
        CuratedVerse(bookID: "ZEC", bookName: "Zechariah", chapter: 1, verse: 3,
                     slots: [.morning], burdens: [], topic: .forgiveness),

        // MARK: - Contentment
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 4, verse: 11,
                     slots: [.midday, .evening], burdens: [.financial], topic: .peace),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 4, verse: 12,
                     slots: [.midday], burdens: [.financial], topic: .peace),
        CuratedVerse(bookID: "1TI", bookName: "1 Timothy", chapter: 6, verse: 6,
                     slots: [.midday], burdens: [.financial], topic: .peace),
        CuratedVerse(bookID: "1TI", bookName: "1 Timothy", chapter: 6, verse: 7,
                     slots: [.midday], burdens: [.financial], topic: .peace),
        CuratedVerse(bookID: "1TI", bookName: "1 Timothy", chapter: 6, verse: 8,
                     slots: [.midday], burdens: [.financial], topic: .peace),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 13, verse: 5,
                     slots: [.midday, .evening], burdens: [.financial], topic: .peace),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 15, verse: 16,
                     slots: [.midday], burdens: [.financial], topic: .peace),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 17, verse: 1,
                     slots: [.evening], burdens: [.relationship], topic: .peace),
        CuratedVerse(bookID: "ECC", bookName: "Ecclesiastes", chapter: 6, verse: 9,
                     slots: [.midday], burdens: [.financial], topic: .peace),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 30, verse: 8,
                     slots: [.evening], burdens: [.financial], topic: .peace),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 30, verse: 9,
                     slots: [.evening], burdens: [.financial], topic: .peace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 16,
                     slots: [.midday], burdens: [.financial], topic: .peace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 16, verse: 5,
                     slots: [.morning], burdens: [.purpose], topic: .peace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 16, verse: 6,
                     slots: [.morning], burdens: [], topic: .peace),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 12, verse: 15,
                     slots: [.midday], burdens: [.financial], topic: .peace),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 6, verse: 19,
                     slots: [.midday], burdens: [.financial], topic: .peace),
        CuratedVerse(bookID: "ECC", bookName: "Ecclesiastes", chapter: 5, verse: 10,
                     slots: [.evening], burdens: [.financial], topic: .peace),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 73, verse: 25,
                     slots: [.evening], burdens: [], topic: .peace),
        CuratedVerse(bookID: "ECC", bookName: "Ecclesiastes", chapter: 2, verse: 24,
                     slots: [.midday], burdens: [], topic: .peace),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 26, verse: 12,
                     slots: [.evening], burdens: [], topic: .peace),

        // MARK: - Obedience (New)
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 5, verse: 33,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 14, verse: 23,
                     slots: [.morning], burdens: [], topic: .faith),
        CuratedVerse(bookID: "ACT", bookName: "Acts", chapter: 5, verse: 29,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 28, verse: 1,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 28, verse: 2,
                     slots: [.morning], burdens: [], topic: .faith),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 11, verse: 1,
                     slots: [.morning], burdens: [], topic: .faith),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 13, verse: 4,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 15, verse: 10,
                     slots: [.morning], burdens: [], topic: .faith),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 15, verse: 14,
                     slots: [.midday], burdens: [], topic: .faith),
        CuratedVerse(bookID: "1JN", bookName: "1 John", chapter: 5, verse: 3,
                     slots: [.morning], burdens: [], topic: .faith),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 14, verse: 21,
                     slots: [.morning], burdens: [], topic: .faith),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 1, verse: 22,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 1, verse: 25,
                     slots: [.morning], burdens: [], topic: .faith),
        CuratedVerse(bookID: "LUK", bookName: "Luke", chapter: 11, verse: 28,
                     slots: [.morning], burdens: [], topic: .faith),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 30, verse: 16,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 1, verse: 19,
                     slots: [.morning], burdens: [], topic: .faith),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 33,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 119, verse: 34,
                     slots: [.morning], burdens: [], topic: .faith),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 6, verse: 16,
                     slots: [.midday], burdens: [.temptation], topic: .faith),
        CuratedVerse(bookID: "MIC", bookName: "Micah", chapter: 6, verse: 6,
                     slots: [.morning], burdens: [.purpose], topic: .faith),

        // MARK: - Missions & Evangelism
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 28, verse: 19,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "MRK", bookName: "Mark", chapter: 16, verse: 15,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "ACT", bookName: "Acts", chapter: 1, verse: 8,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 10, verse: 15,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 6, verse: 8,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 1, verse: 16,
                     slots: [.morning], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 9, verse: 37,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 9, verse: 38,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 20, verse: 21,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 5, verse: 18,
                     slots: [.midday], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 5, verse: 19,
                     slots: [.midday], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "ACT", bookName: "Acts", chapter: 13, verse: 47,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 96, verse: 3,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 3, verse: 15,
                     slots: [.midday], burdens: [.doubt], topic: .faith),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 4, verse: 5,
                     slots: [.midday], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 4, verse: 6,
                     slots: [.midday], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 52, verse: 7,
                     slots: [.morning], burdens: [], topic: .faith),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 5, verse: 14,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 5, verse: 15,
                     slots: [.morning], burdens: [.purpose], topic: .faith),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 2, verse: 15,
                     slots: [.evening], burdens: [.purpose], topic: .faith),

        // MARK: - Spiritual Warfare (Expanded)
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 10, verse: 3,
                     slots: [.morning], burdens: [.temptation], topic: .spiritualWarfare),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 5, verse: 8,
                     slots: [.evening], burdens: [.temptation], topic: .spiritualWarfare),
        CuratedVerse(bookID: "1PE", bookName: "1 Peter", chapter: 5, verse: 9,
                     slots: [.evening], burdens: [.temptation], topic: .spiritualWarfare),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 4, verse: 8,
                     slots: [.morning], burdens: [.temptation], topic: .spiritualWarfare),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 13, verse: 14,
                     slots: [.morning], burdens: [.temptation], topic: .spiritualWarfare),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 54, verse: 16,
                     slots: [.morning], burdens: [], topic: .spiritualWarfare),
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 3, verse: 22,
                     slots: [.morning], burdens: [.anxiety], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 144, verse: 3,
                     slots: [.morning], burdens: [], topic: .spiritualWarfare),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 41, verse: 11,
                     slots: [.morning], burdens: [.anxiety], topic: .spiritualWarfare),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 41, verse: 12,
                     slots: [.morning], burdens: [.anxiety], topic: .spiritualWarfare),
        CuratedVerse(bookID: "NAH", bookName: "Nahum", chapter: 1, verse: 2,
                     slots: [.morning], burdens: [], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 35, verse: 1,
                     slots: [.morning], burdens: [], topic: .spiritualWarfare),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 35, verse: 10,
                     slots: [.morning], burdens: [], topic: .spiritualWarfare),
        CuratedVerse(bookID: "EXO", bookName: "Exodus", chapter: 14, verse: 14,
                     slots: [.morning], burdens: [.anxiety], topic: .spiritualWarfare),
        CuratedVerse(bookID: "2CH", bookName: "2 Chronicles", chapter: 20, verse: 17,
                     slots: [.morning], burdens: [.anxiety], topic: .spiritualWarfare),

        // MARK: - Heaven & Eternity (Expanded)
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 21, verse: 2,
                     slots: [.evening, .bedtime], burdens: [.grief], topic: .hope),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 22, verse: 3,
                     slots: [.evening], burdens: [], topic: .hope),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 22, verse: 4,
                     slots: [.evening], burdens: [.grief], topic: .hope),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 15, verse: 42,
                     slots: [.evening], burdens: [.grief, .health], topic: .hope),
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 15, verse: 43,
                     slots: [.evening], burdens: [.grief, .health], topic: .hope),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 1, verse: 21,
                     slots: [.evening], burdens: [.grief], topic: .hope),
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 1, verse: 23,
                     slots: [.evening], burdens: [.grief], topic: .hope),
        CuratedVerse(bookID: "JHN", bookName: "John", chapter: 14, verse: 19,
                     slots: [.evening], burdens: [.grief], topic: .hope),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 65, verse: 17,
                     slots: [.evening], burdens: [.grief], topic: .hope),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 5, verse: 1,
                     slots: [.bedtime], burdens: [.grief, .health], topic: .hope),
        CuratedVerse(bookID: "2CO", bookName: "2 Corinthians", chapter: 5, verse: 8,
                     slots: [.bedtime], burdens: [.grief], topic: .hope),
        CuratedVerse(bookID: "REV", bookName: "Revelation", chapter: 7, verse: 16,
                     slots: [.evening], burdens: [.grief, .health], topic: .hope),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 18,
                     slots: [.evening], burdens: [.grief, .health], topic: .hope),
        CuratedVerse(bookID: "1TH", bookName: "1 Thessalonians", chapter: 4, verse: 14,
                     slots: [.bedtime], burdens: [.grief], topic: .hope),

        // MARK: - Creation (Expanded)
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 19, verse: 4,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 95, verse: 4,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 95, verse: 5,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 33, verse: 9,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 40, verse: 12,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 10, verse: 12,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "JOB", bookName: "Job", chapter: 26, verse: 7,
                     slots: [.evening], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "JOB", bookName: "Job", chapter: 38, verse: 7,
                     slots: [.evening], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 104, verse: 5,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "GEN", bookName: "Genesis", chapter: 1, verse: 3,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 8, verse: 4,
                     slots: [.evening], burdens: [.purpose], topic: .gratitude),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 40, verse: 22,
                     slots: [.evening], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 147, verse: 4,
                     slots: [.evening], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 136, verse: 5,
                     slots: [.morning], burdens: [], topic: .gratitude),
        CuratedVerse(bookID: "NEH", bookName: "Nehemiah", chapter: 9, verse: 5,
                     slots: [.morning], burdens: [], topic: .gratitude),

        // MARK: - Additional Verses
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 96, verse: 1,
                     slots: [.morning], burdens: [], topic: .joy),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 43, verse: 3,
                     slots: [.morning], burdens: [.doubt], topic: .joy),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 31, verse: 13,
                     slots: [.evening], burdens: [.grief], topic: .joy),
        CuratedVerse(bookID: "ZEP", bookName: "Zephaniah", chapter: 3, verse: 15,
                     slots: [.morning], burdens: [.anxiety], topic: .joy),
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
    static let bibleDeepLink = Notification.Name("BibleDeepLink")
    static let askDeepLink = Notification.Name("AskDeepLink")
    static let sanctuaryDeepLink = Notification.Name("SanctuaryDeepLink")
    static let openSanctuaryFromWidget = Notification.Name("OpenSanctuaryFromWidget")
}
