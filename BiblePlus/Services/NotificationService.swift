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
                notifContent.title = prayerTitle(for: slot, name: name)
                notifContent.subtitle = prayerSubtitle(for: slot)
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
                    notifContent.title = prayerTitle(for: slot, name: name)
                    notifContent.subtitle = prayerSubtitle(for: slot)
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

                    do {
                        try await center.add(request)
                    } catch {
                        #if DEBUG
                        print("[NotificationService] Failed to schedule: \(error)")
                        #endif
                    }
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

    // MARK: - Day-1 Welcome Back (post-onboarding daily anchor)
    //
    // Scheduled at the very end of onboarding. A single recurring local
    // notification at the user's chosen prayer time, starting tomorrow.
    // Recurring (not one-shot) so it doubles as the daily streak anchor —
    // every morning the user gets pulled back at the time they themselves
    // chose during onboarding, which is the highest-converting reminder
    // pattern in subscription apps. Replaces any prior welcome notification
    // so re-running onboarding stays clean.

    static let welcomeBackIdentifier = "bibleplus.welcome.daily"

    func scheduleWelcomeBackDaily(name: String, slot: PrayerTimeSlot) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.welcomeBackIdentifier])

        let safeName = name.isEmpty ? "Friend" : name
        let content = UNMutableNotificationContent()
        content.title = welcomeBackTitle(for: slot, name: safeName)
        content.body = welcomeBackBody(for: slot)
        content.sound = .default
        content.userInfo = [
            "type": "welcome_back",
            "slot": slot.rawValue,
        ]

        var components = DateComponents()
        components.hour = scheduleHour(for: slot)
        components.minute = scheduleMinute(for: slot)

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        let request = UNNotificationRequest(
            identifier: Self.welcomeBackIdentifier,
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error {
                print("[NotificationService] Failed to schedule welcome-back: \(error)")
            }
        }
    }

    /// Recovery path for users who DENIED notification permission during
    /// onboarding (so the welcome-back was skipped) but later enabled
    /// notifications via Settings. Called from ContentView.onAppear on
    /// every launch — cheap and idempotent. Skips work if the request
    /// is already pending or if notifications still aren't authorized.
    func ensureWelcomeBackScheduledIfNeeded(name: String, slot: PrayerTimeSlot) {
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            // Only proceed if the OS-level permission is actually granted.
            // Provisional / ephemeral don't deliver banners reliably so we
            // treat them as not-granted for the recovery hook's purposes.
            guard settings.authorizationStatus == .authorized else { return }

            center.getPendingNotificationRequests { pending in
                let alreadyScheduled = pending.contains { $0.identifier == Self.welcomeBackIdentifier }
                guard !alreadyScheduled else { return }

                Task { @MainActor in
                    self.scheduleWelcomeBackDaily(name: name, slot: slot)
                }
            }
        }
    }

    private func welcomeBackTitle(for slot: PrayerTimeSlot, name: String) -> String {
        switch slot {
        case .morning:  "Good morning, \(name) 🌅"
        case .midday:   "A midday pause, \(name) ✨"
        case .evening:  "Good evening, \(name) 🕊️"
        case .bedtime:  "One last word, \(name) 🌙"
        }
    }

    private func welcomeBackBody(for slot: PrayerTimeSlot) -> String {
        switch slot {
        case .morning:  "Your verse for today is ready."
        case .midday:   "A verse picked just for you is waiting."
        case .evening:  "A reflection chosen for your evening is ready."
        case .bedtime:  "End the day with a verse made for tonight."
        }
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

    private let faithBoostScheduleDays = 2  // Reduced from 3 to stay under iOS 64 notification limit
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

    private func prayerTitle(for slot: PrayerTimeSlot, name: String) -> String {
        switch slot {
        case .morning:  "Time to Pray, \(name) 🙏"
        case .midday:   "Midday Prayer ✨"
        case .evening:  "Evening Prayer Time 🕊️"
        case .bedtime:  "A Moment Before Sleep 🌙"
        }
    }

    private func prayerSubtitle(for slot: PrayerTimeSlot) -> String {
        switch slot {
        case .morning:  "Start your day with God"
        case .midday:   "Pause and reconnect"
        case .evening:  "Reflect on today's blessings"
        case .bedtime:  "Rest in His peace tonight"
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

    private struct CuratedVerse: Decodable {
        let bookID: String
        let bookName: String
        let chapter: Int
        let verse: Int
        let slots: [PrayerTimeSlot]
        let burdens: [Burden]
        let topic: NotificationTopic
    }

    private static let curatedVerses: [CuratedVerse] = loadCuratedVerses()

    private static func loadCuratedVerses() -> [CuratedVerse] {
        guard let url = Bundle.main.url(forResource: "curated-verses", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([CuratedVerse].self, from: data)
        else { return [] }
        return items
    }

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
    static let switchToSettingsTab = Notification.Name("SwitchToSettingsTab")
    static let switchToSavedTab = Notification.Name("SwitchToSavedTab")
    static let switchToBibleTab = Notification.Name("SwitchToBibleTab")
    static let openAIWithContext = Notification.Name("OpenAIWithContext")
    static let navigateToConversation = Notification.Name("NavigateToConversation")
    static let bibleDeepLink = Notification.Name("BibleDeepLink")
    static let askDeepLink = Notification.Name("AskDeepLink")
    static let sanctuaryDeepLink = Notification.Name("SanctuaryDeepLink")
    static let openSanctuaryFromWidget = Notification.Name("OpenSanctuaryFromWidget")
}
