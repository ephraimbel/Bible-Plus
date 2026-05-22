import Foundation
import SwiftData

// MARK: - Widget Time Window

enum WidgetTimeWindow: String, CaseIterable {
    case gratitude     // 6–9 AM
    case strength      // 9 AM–12 PM
    case pause         // 12–3 PM
    case intercession  // 3–6 PM
    case reflection    // 6–9 PM
    case peace         // 9 PM–6 AM

    var displayName: String {
        switch self {
        case .gratitude: String(localized: "Gratitude")
        case .strength: String(localized: "Strength")
        case .pause: String(localized: "Pause")
        case .intercession: String(localized: "Intercession")
        case .reflection: String(localized: "Reflection")
        case .peace: String(localized: "Peace")
        }
    }

    var icon: String {
        switch self {
        case .gratitude: "sunrise"
        case .strength: "sun.max"
        case .pause: "cup.and.saucer"
        case .intercession: "hands.sparkles"
        case .reflection: "sunset"
        case .peace: "moon.stars"
        }
    }

    var prayerTimeSlot: PrayerTimeSlot {
        switch self {
        case .gratitude: .morning
        case .strength: .morning
        case .pause: .midday
        case .intercession: .midday
        case .reflection: .evening
        case .peace: .bedtime
        }
    }

    /// Thematic categories that get a bonus in this window
    var thematicCategories: Set<String> {
        switch self {
        case .gratitude: ["gratitude", "thanksgiving", "praise"]
        case .strength: ["strength", "courage", "perseverance"]
        case .pause: ["peace", "rest", "stillness"]
        case .intercession: ["prayer", "intercession", "community"]
        case .reflection: ["wisdom", "reflection", "growth"]
        case .peace: ["comfort", "trust", "surrender"]
        }
    }

    /// Hour range for this window (start inclusive, end exclusive)
    var hourRange: Range<Int> {
        switch self {
        case .gratitude: 6..<9
        case .strength: 9..<12
        case .pause: 12..<15
        case .intercession: 15..<18
        case .reflection: 18..<21
        case .peace: 21..<24 // Also covers 0..<6 via current()
        }
    }

    /// Returns the current time window based on system time
    static func current() -> WidgetTimeWindow {
        windowForHour(Calendar.current.component(.hour, from: Date()))
    }

    /// Returns the time window for a given hour
    static func windowForHour(_ hour: Int) -> WidgetTimeWindow {
        if hour < 6 { return .peace }
        for window in allCases {
            if window.hourRange.contains(hour) { return window }
        }
        return .peace
    }

    /// Returns the next 3-hour window boundary date
    static func nextBoundary() -> Date {
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)

        let boundaries = [6, 9, 12, 15, 18, 21]
        let nextHour = boundaries.first(where: { $0 > hour }) ?? 24 + boundaries[0]

        var components = cal.dateComponents([.year, .month, .day], from: now)
        if nextHour >= 24 {
            guard let tomorrow = cal.date(byAdding: .day, value: 1, to: now) else { return now }
            components = cal.dateComponents([.year, .month, .day], from: tomorrow)
            components.hour = nextHour - 24
        } else {
            components.hour = nextHour
        }
        components.minute = 0
        components.second = 0

        return cal.date(from: components) ?? now
    }

    /// Returns the next even-hour boundary (for 2-hour home screen widget cadence)
    static func nextTwoHourBoundary() -> Date {
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)
        let nextEvenHour = hour % 2 == 0 ? hour + 2 : hour + 1

        var components = cal.dateComponents([.year, .month, .day], from: now)
        if nextEvenHour >= 24 {
            guard let tomorrow = cal.date(byAdding: .day, value: 1, to: now) else { return now }
            components = cal.dateComponents([.year, .month, .day], from: tomorrow)
            components.hour = nextEvenHour - 24
        } else {
            components.hour = nextEvenHour
        }
        components.minute = 0
        components.second = 0

        return cal.date(from: components) ?? now
    }

    /// Returns the start of the next day (for lock screen verse-of-the-day reload)
    static func startOfNextDay() -> Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date()
        return tomorrow
    }
}

// MARK: - Widget Content Provider

enum WidgetContentProvider {

    /// djb2 hash — deterministic across app and widget processes
    /// (unlike Swift's String.hashValue which is randomized per process).
    private static func stableHash(_ string: String) -> Int {
        var hash: UInt64 = 5381
        for byte in string.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
        }
        return Int(hash & 0x7FFFFFFFFFFFFFFF)
    }

    struct WidgetEntry {
        let date: Date
        let window: WidgetTimeWindow
        let displayText: String
        let shortText: String
        let verseReference: String?
        let contentType: ContentType
        let contentID: UUID
        let backgroundGradient: [String]
    }

    /// Fetch the best content item for the given time window and user profile
    static func contentForWidget(
        window: WidgetTimeWindow,
        profile: UserProfile,
        modelContext: ModelContext,
        allowedTypes: Set<ContentType>? = nil
    ) -> PrayerContent? {
        let descriptor = FetchDescriptor<PrayerContent>()
        guard let allContent = try? modelContext.fetch(descriptor) else { return nil }

        let eligible = allContent.filter { content in
            (!content.isProOnly || profile.isPro)
                && content.faithLevelMin.numericValue <= profile.faithLevel.numericValue
                && (allowedTypes == nil || allowedTypes!.contains(content.type))
        }

        guard !eligible.isEmpty else { return nil }

        let scored = eligible.map { content in
            (content: content, score: score(content: content, profile: profile, window: window))
        }

        return scored.max(by: { $0.score < $1.score })?.content
    }

    /// Fetch the Nth content item from the scored list (for manual navigation via arrows)
    static func contentForWidgetWithOffset(
        offset: Int,
        window: WidgetTimeWindow,
        profile: UserProfile,
        modelContext: ModelContext,
        allowedTypes: Set<ContentType>? = nil
    ) -> PrayerContent? {
        let descriptor = FetchDescriptor<PrayerContent>()
        guard let allContent = try? modelContext.fetch(descriptor) else { return nil }

        let eligible = allContent.filter { content in
            (!content.isProOnly || profile.isPro)
                && content.faithLevelMin.numericValue <= profile.faithLevel.numericValue
                && (allowedTypes == nil || allowedTypes!.contains(content.type))
        }

        guard !eligible.isEmpty else { return nil }

        let scored = eligible.map { content in
            (content: content, score: score(content: content, profile: profile, window: window))
        }.sorted { $0.score > $1.score }

        let clampedOffset = offset % scored.count
        return scored[clampedOffset].content
    }

    /// Generate timeline entries for remaining windows today (plus next morning)
    static func timelineEntries(
        profile: UserProfile,
        modelContext: ModelContext
    ) -> [WidgetEntry] {
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)

        let effectiveBgID = profile.widgetSelectedBackgroundID ?? profile.selectedBackgroundID
        let background = SanctuaryBackground.background(for: effectiveBgID)
            ?? SanctuaryBackground.allBackgrounds[0]

        // Single fetch of all content
        let descriptor = FetchDescriptor<PrayerContent>()
        guard let allContent = try? modelContext.fetch(descriptor) else { return [] }

        let eligible = allContent.filter { content in
            (!content.isProOnly || profile.isPro)
                && content.faithLevelMin.numericValue <= profile.faithLevel.numericValue
        }

        var entries: [WidgetEntry] = []
        var usedIDs: Set<UUID> = []

        // Generate entries for remaining windows today + first window tomorrow
        let allWindows = remainingWindows(fromHour: hour)

        for (window, date) in allWindows {
            if let content = bestContentFromArray(
                eligible,
                window: window,
                profile: profile,
                excluding: usedIDs,
                avoidType: nil,
                avoidCategory: nil
            ) {
                usedIDs.insert(content.id)
                let text = personalizedText(template: content.templateText, firstName: profile.firstName)
                entries.append(WidgetEntry(
                    date: date,
                    window: window,
                    displayText: text,
                    shortText: String(text.prefix(40)),
                    verseReference: content.verseReference,
                    contentType: content.type,
                    contentID: content.id,
                    backgroundGradient: background.gradientColors
                ))
            }
        }

        return entries
    }

    /// Replace {name} token in template text
    static func personalizedText(template: String, firstName: String) -> String {
        let name = firstName.isEmpty ? "Friend" : firstName
        return template.replacingOccurrences(of: "{name}", with: name)
    }

    // MARK: - Deterministic Scoring & Cache

    /// Same as score() but uses a hash-based jitter instead of random, so the
    /// same content ID + day seed always produces the same score.
    static func deterministicScore(
        content: PrayerContent,
        profile: UserProfile,
        window: WidgetTimeWindow,
        daySeed: Int
    ) -> Double {
        var s: Double = 1.0

        // Burden weighting: 3x
        let userBurdens = Set(profile.currentBurdens)
        let contentBurdens = Set(content.applicableBurdens)
        if !userBurdens.intersection(contentBurdens).isEmpty {
            s *= 3.0
        }

        // Season weighting: 2x
        let userSeasons = Set(profile.lifeSeasons)
        let contentSeasons = Set(content.applicableSeasons)
        if !userSeasons.intersection(contentSeasons).isEmpty {
            s *= 2.0
        }

        // Time awareness: 1.5x
        if content.timeOfDay.contains(window.prayerTimeSlot) {
            s *= 1.5
        }

        // Faith depth: 1.3x
        if content.faithLevelMin == profile.faithLevel {
            s *= 1.3
        }

        // Thematic category bonus: 1.4x
        if window.thematicCategories.contains(content.category.lowercased()) {
            s *= 1.4
        }

        // Deterministic jitter from content ID + day seed (range 0.7–1.3)
        // Uses djb2 hash (stable across processes, unlike String.hashValue)
        let hashInput = content.id.uuidString + String(daySeed)
        let hash = Self.stableHash(hashInput)
        let jitter = 0.7 + Double(hash % 1000) / 1000.0 * 0.6
        s *= jitter

        return s
    }

    /// Fetch all eligible content once, score deterministically, cache the ordered list.
    /// Returns the cached items (also persisted via WidgetBackgroundService).
    static func buildAndCacheContentList(
        profile: UserProfile,
        modelContext: ModelContext,
        allowedTypes: Set<ContentType>? = nil
    ) -> WidgetContentCache? {
        let descriptor = FetchDescriptor<PrayerContent>()
        guard let allContent = try? modelContext.fetch(descriptor) else { return nil }

        let eligible = allContent.filter { content in
            (!content.isProOnly || profile.isPro)
                && content.faithLevelMin.numericValue <= profile.faithLevel.numericValue
                && (allowedTypes == nil || allowedTypes!.contains(content.type))
        }

        guard !eligible.isEmpty else { return nil }

        let window = WidgetTimeWindow.current()
        let cal = Calendar.current
        let dayOfYear = cal.ordinality(of: .day, in: .year, for: Date()) ?? 1

        // Score deterministically and sort descending
        let scored = eligible.map { content in
            (content: content, score: deterministicScore(
                content: content, profile: profile, window: window, daySeed: dayOfYear
            ))
        }.sorted { $0.score > $1.score }

        // Convert to lightweight Codable items
        let cachedItems = scored.map { item in
            let text = personalizedText(template: item.content.templateText, firstName: profile.firstName)
            return CachedWidgetContent(
                id: item.content.id.uuidString,
                displayText: text,
                shortText: String(text.prefix(40)),
                verseReference: item.content.verseReference,
                contentType: item.content.type.rawValue
            )
        }

        let cache = WidgetContentCache(
            items: cachedItems,
            timeWindow: window.rawValue,
            createdAt: Date(),
            daySeed: dayOfYear
        )

        WidgetBackgroundService.saveContentCache(cache)
        return cache
    }

    /// Fast O(1) lookup: get the Nth item from the cached content list.
    /// Returns nil if cache is stale/missing or offset is out of bounds.
    static func cachedContentAtOffset(_ offset: Int) -> CachedWidgetContent? {
        guard let cache = WidgetBackgroundService.loadContentCache(),
              !cache.isStale,
              !cache.items.isEmpty else { return nil }
        let index = offset % cache.items.count
        return cache.items[index]
    }

    // MARK: - Home Screen (2-hour rotation, mixed content)

    /// Generate timeline entries every 2 hours with diverse content types.
    /// Single-fetch: loads PrayerContent once and picks from the array.
    static func homeScreenTimelineEntries(
        profile: UserProfile,
        modelContext: ModelContext,
        allowedTypes: Set<ContentType>? = nil
    ) -> [WidgetEntry] {
        let cal = Calendar.current
        let now = Date()

        let effectiveBgID = profile.widgetSelectedBackgroundID ?? profile.selectedBackgroundID
        let background = SanctuaryBackground.background(for: effectiveBgID)
            ?? SanctuaryBackground.allBackgrounds[0]

        // Single fetch of all content
        let descriptor = FetchDescriptor<PrayerContent>()
        guard let allContent = try? modelContext.fetch(descriptor) else { return [] }

        let eligible = allContent.filter { content in
            (!content.isProOnly || profile.isPro)
                && content.faithLevelMin.numericValue <= profile.faithLevel.numericValue
                && (allowedTypes == nil || allowedTypes!.contains(content.type))
        }

        guard !eligible.isEmpty else { return [] }

        var entries: [WidgetEntry] = []
        var usedIDs: Set<UUID> = []
        var lastContentType: ContentType?
        var lastCategory: String?

        // Generate 12 entries covering the next 24 hours at 2-hour intervals
        for i in 0..<12 {
            let entryDate = i == 0 ? now : cal.date(byAdding: .hour, value: i * 2, to: now) ?? now
            let entryHour = cal.component(.hour, from: entryDate)
            let window = WidgetTimeWindow.windowForHour(entryHour)

            if let content = bestContentFromArray(
                eligible,
                window: window,
                profile: profile,
                excluding: usedIDs,
                avoidType: lastContentType,
                avoidCategory: lastCategory
            ) {
                usedIDs.insert(content.id)
                lastContentType = content.type
                lastCategory = content.category
                let text = personalizedText(template: content.templateText, firstName: profile.firstName)
                entries.append(WidgetEntry(
                    date: entryDate,
                    window: window,
                    displayText: text,
                    shortText: String(text.prefix(40)),
                    verseReference: content.verseReference,
                    contentType: content.type,
                    contentID: content.id,
                    backgroundGradient: background.gradientColors
                ))
            }
        }

        return entries
    }

    // MARK: - Lock Screen (Daily Inspiration, refreshes daily)

    /// Returns a single daily inspiration entry (verse, quote, prayer, or reflection) that stays the entire day
    static func dailyInspirationEntry(
        profile: UserProfile,
        modelContext: ModelContext,
        allowedTypes: Set<ContentType>? = nil
    ) -> WidgetEntry? {
        let descriptor = FetchDescriptor<PrayerContent>()
        guard let allContent = try? modelContext.fetch(descriptor) else { return nil }

        let lockScreenTypes: Set<ContentType> = allowedTypes ?? [.verse, .quote, .reflection, .prayer]

        // Filter to lock-screen-friendly types — no length cap, widget scales text to fit
        let allEligible = allContent.filter { content in
            lockScreenTypes.contains(content.type)
                && (!content.isProOnly || profile.isPro)
                && content.faithLevelMin.numericValue <= profile.faithLevel.numericValue
        }

        // Strongly prefer actual Bible verses (have verseReference) for the lock screen
        let versesOnly = allEligible.filter { $0.verseReference != nil }
        let eligible = versesOnly.isEmpty ? allEligible : versesOnly

        guard !eligible.isEmpty else { return nil }

        // Use day-of-year as seed for deterministic daily selection
        let cal = Calendar.current
        let dayOfYear = cal.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let year = cal.component(.year, from: Date())
        let seed = (year * 1000 + dayOfYear) % eligible.count

        // Score with profile relevance, then pick deterministically
        let scored = eligible.map { content in
            (content: content, score: score(content: content, profile: profile, window: .current()))
        }.sorted { $0.score > $1.score }

        // Pick from top-scored items using the daily seed
        let topCount = min(scored.count, max(5, scored.count / 3))
        let index = seed % topCount
        let chosen = scored[index].content

        let effectiveBgID = profile.widgetSelectedBackgroundID ?? profile.selectedBackgroundID
        let background = SanctuaryBackground.background(for: effectiveBgID)
            ?? SanctuaryBackground.allBackgrounds[0]
        let text = personalizedText(template: chosen.templateText, firstName: profile.firstName)

        return WidgetEntry(
            date: Date(),
            window: .current(),
            displayText: text,
            shortText: String(text.prefix(40)),
            verseReference: chosen.verseReference,
            contentType: chosen.type,
            contentID: chosen.id,
            backgroundGradient: background.gradientColors
        )
    }

    // MARK: - Private

    private static func score(
        content: PrayerContent,
        profile: UserProfile,
        window: WidgetTimeWindow
    ) -> Double {
        var score: Double = 1.0

        // Burden weighting: 3x
        let userBurdens = Set(profile.currentBurdens)
        let contentBurdens = Set(content.applicableBurdens)
        if !userBurdens.intersection(contentBurdens).isEmpty {
            score *= 3.0
        }

        // Season weighting: 2x
        let userSeasons = Set(profile.lifeSeasons)
        let contentSeasons = Set(content.applicableSeasons)
        if !userSeasons.intersection(contentSeasons).isEmpty {
            score *= 2.0
        }

        // Time awareness: 1.5x
        if content.timeOfDay.contains(window.prayerTimeSlot) {
            score *= 1.5
        }

        // Faith depth: 1.3x
        if content.faithLevelMin == profile.faithLevel {
            score *= 1.3
        }

        // Thematic category bonus: 1.4x
        if window.thematicCategories.contains(content.category.lowercased()) {
            score *= 1.4
        }

        // Deterministic jitter from content ID + day (prevents flicker on widget reload)
        // Uses djb2 hash (stable across processes, unlike String.hashValue)
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let hashInput = content.id.uuidString + String(dayOfYear)
        let hash = Self.stableHash(hashInput)
        let jitter = 0.7 + Double(hash % 1000) / 1000.0 * 0.6
        score *= jitter

        return score
    }

    /// Picks the best content from a pre-fetched array (no SwiftData fetch),
    /// favoring content type and category diversity.
    private static func bestContentFromArray(
        _ eligible: [PrayerContent],
        window: WidgetTimeWindow,
        profile: UserProfile,
        excluding usedIDs: Set<UUID>,
        avoidType: ContentType?,
        avoidCategory: String? = nil
    ) -> PrayerContent? {
        let filtered = eligible.filter { !usedIDs.contains($0.id) }
        guard !filtered.isEmpty else { return nil }

        var scored = filtered.map { content in
            var s = score(content: content, profile: profile, window: window)
            // Type diversity penalty
            if let avoid = avoidType, content.type == avoid {
                s *= 0.3
            }
            // Category diversity penalty
            if let avoidCat = avoidCategory, content.category.lowercased() == avoidCat.lowercased() {
                s *= 0.4
            }
            // Widget-friendly content length bonus (40-200 chars)
            let len = content.templateText.count
            if len >= 40 && len <= 200 {
                s *= 1.2
            }
            return (content: content, score: s)
        }

        scored.sort { $0.score > $1.score }
        return scored.first?.content
    }

    /// Returns remaining time windows today with their start dates, plus first window tomorrow
    private static func remainingWindows(fromHour hour: Int) -> [(WidgetTimeWindow, Date)] {
        let cal = Calendar.current
        let today = Date()
        let startOfDay = cal.startOfDay(for: today)

        let windowsWithHours: [(WidgetTimeWindow, Int)] = [
            (.gratitude, 6),
            (.strength, 9),
            (.pause, 12),
            (.intercession, 15),
            (.reflection, 18),
            (.peace, 21),
        ]

        var result: [(WidgetTimeWindow, Date)] = []

        // Add current window with "now" as date
        let currentWindow = WidgetTimeWindow.current()
        result.append((currentWindow, today))

        // Add remaining windows today
        for (window, startHour) in windowsWithHours {
            if startHour > hour {
                let date = cal.date(bySettingHour: startHour, minute: 0, second: 0, of: today) ?? today
                result.append((window, date))
            }
        }

        // Add first window tomorrow (gratitude at 6 AM)
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: startOfDay) {
            let morningDate = cal.date(bySettingHour: 6, minute: 0, second: 0, of: tomorrow) ?? tomorrow
            result.append((.gratitude, morningDate))
        }

        return result
    }
}
