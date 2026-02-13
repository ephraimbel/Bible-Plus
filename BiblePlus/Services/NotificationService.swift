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

            let subtitles = slot.notificationSubtitles(name: name).shuffled()

            for dayOffset in 0..<scheduleDays {
                guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
                let item = items[dayOffset % items.count]

                let notifContent = UNMutableNotificationContent()
                notifContent.title = "Bible+"
                notifContent.subtitle = subtitles[dayOffset % subtitles.count]
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

            let subtitles = slot.notificationSubtitles(name: name).shuffled()

            for dayOffset in 0..<scheduleDays {
                guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
                let item = items[dayOffset % items.count]

                let notifContent = UNMutableNotificationContent()
                notifContent.title = "Bible+"
                notifContent.subtitle = subtitles[dayOffset % subtitles.count]
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
        let bibleBookName: String?
        let bibleChapter: Int?
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

        return mergeAndSelect(count: count, feedItems: scoredFeed, verseItems: scoredVerses)
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

        return mergeAndSelect(count: count, feedItems: scoredFeed, verseItems: scoredVerses)
    }

    /// Merge feed and verse items, filter recently-sent, pick top N, record sent.
    private func mergeAndSelect(
        count: Int,
        feedItems: [(SelectedContent, Double)],
        verseItems: [(SelectedContent, Double)]
    ) -> [SelectedContent] {
        let allItems = feedItems + verseItems

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
        } else if let book = item.bibleBookName, let ch = item.bibleChapter {
            return "verse-\(book)-\(ch)"
        }
        return UUID().uuidString
    }

    private func formatContent(_ item: PrayerContent, name: String) -> SelectedContent {
        let text: String
        if let verse = item.verseText, let ref = item.verseReference {
            text = "\"\(verse)\" — \(ref)"
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

        // MARK: Doubt & Uncertainty
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 3, verse: 5,
                     slots: [.morning, .midday], burdens: [.doubt]),
        CuratedVerse(bookID: "HEB", bookName: "Hebrews", chapter: 11, verse: 1,
                     slots: [.morning], burdens: [.doubt]),
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 29, verse: 11,
                     slots: [.midday], burdens: [.doubt, .purpose]),
        CuratedVerse(bookID: "MRK", bookName: "Mark", chapter: 9, verse: 24,
                     slots: [.evening], burdens: [.doubt]),

        // MARK: Loneliness
        CuratedVerse(bookID: "DEU", bookName: "Deuteronomy", chapter: 31, verse: 8,
                     slots: [.evening, .bedtime], burdens: [.loneliness]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 68, verse: 6,
                     slots: [.morning], burdens: [.loneliness]),
        CuratedVerse(bookID: "ISA", bookName: "Isaiah", chapter: 43, verse: 2,
                     slots: [.evening], burdens: [.loneliness, .grief]),

        // MARK: Temptation
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 10, verse: 13,
                     slots: [.morning, .midday], burdens: [.temptation]),
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 4, verse: 7,
                     slots: [.midday], burdens: [.temptation]),
        CuratedVerse(bookID: "GAL", bookName: "Galatians", chapter: 5, verse: 16,
                     slots: [.morning], burdens: [.temptation]),

        // MARK: Financial
        CuratedVerse(bookID: "PHP", bookName: "Philippians", chapter: 4, verse: 19,
                     slots: [.morning, .midday], burdens: [.financial]),
        CuratedVerse(bookID: "MAT", bookName: "Matthew", chapter: 6, verse: 33,
                     slots: [.morning], burdens: [.financial, .purpose]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 37, verse: 25,
                     slots: [.evening], burdens: [.financial]),

        // MARK: Health
        CuratedVerse(bookID: "JER", bookName: "Jeremiah", chapter: 17, verse: 14,
                     slots: [.morning], burdens: [.health]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 103, verse: 3,
                     slots: [.midday], burdens: [.health]),
        CuratedVerse(bookID: "3JN", bookName: "3 John", chapter: 1, verse: 2,
                     slots: [.morning], burdens: [.health]),

        // MARK: Relationships
        CuratedVerse(bookID: "1CO", bookName: "1 Corinthians", chapter: 13, verse: 4,
                     slots: [.morning, .evening], burdens: [.relationship]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 4, verse: 32,
                     slots: [.midday], burdens: [.relationship, .anger]),
        CuratedVerse(bookID: "COL", bookName: "Colossians", chapter: 3, verse: 13,
                     slots: [.evening], burdens: [.relationship, .anger]),

        // MARK: Anger
        CuratedVerse(bookID: "JAS", bookName: "James", chapter: 1, verse: 19,
                     slots: [.morning, .midday], burdens: [.anger]),
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 4, verse: 26,
                     slots: [.evening], burdens: [.anger]),
        CuratedVerse(bookID: "PRO", bookName: "Proverbs", chapter: 15, verse: 1,
                     slots: [.midday], burdens: [.anger]),

        // MARK: Purpose
        CuratedVerse(bookID: "EPH", bookName: "Ephesians", chapter: 2, verse: 10,
                     slots: [.morning], burdens: [.purpose]),
        CuratedVerse(bookID: "ROM", bookName: "Romans", chapter: 8, verse: 31,
                     slots: [.morning, .midday], burdens: [.purpose, .doubt]),
        CuratedVerse(bookID: "PSA", bookName: "Psalms", chapter: 139, verse: 14,
                     slots: [.morning], burdens: [.purpose]),

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
    ]
    // swiftlint:enable function_body_length

    /// Score curated verses for a time slot and user burdens.
    private func scoreCuratedVerses(for slot: PrayerTimeSlot, burdens: Set<Burden>) -> [(SelectedContent, Double)] {
        let matching = Self.curatedVerses.filter { $0.slots.contains(slot) }
        return matching.compactMap { cv in
            let verses = BibleRepository.shared.versesSync(book: cv.bookID, chapter: cv.chapter)
            guard let verse = verses.first(where: { $0.number == cv.verse }) else { return nil }
            let text = "\"\(verse.text)\" — \(cv.bookName) \(cv.chapter):\(cv.verse)"
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
}
