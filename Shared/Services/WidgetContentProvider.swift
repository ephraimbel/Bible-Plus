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
        case .gratitude: "Gratitude"
        case .strength: "Strength"
        case .pause: "Pause"
        case .intercession: "Intercession"
        case .reflection: "Reflection"
        case .peace: "Peace"
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
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 6 { return .peace }
        for window in allCases {
            if window.hourRange.contains(hour) { return window }
        }
        return .peace
    }

    /// Returns the next window boundary date (for timeline reload scheduling)
    static func nextBoundary() -> Date {
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)

        let boundaries = [6, 9, 12, 15, 18, 21]
        let nextHour = boundaries.first(where: { $0 > hour }) ?? 24 + boundaries[0]

        var components = cal.dateComponents([.year, .month, .day], from: now)
        if nextHour >= 24 {
            components.hour = nextHour - 24
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
}

// MARK: - Widget Content Provider

enum WidgetContentProvider {

    struct WidgetEntry {
        let date: Date
        let window: WidgetTimeWindow
        let displayText: String
        let shortText: String
        let verseReference: String?
        let contentType: ContentType
        let contentID: UUID
        let themeGradient: [String]
        let firstName: String
    }

    /// Fetch the best content item for the given time window and user profile
    static func contentForWidget(
        window: WidgetTimeWindow,
        profile: UserProfile,
        modelContext: ModelContext
    ) -> PrayerContent? {
        let descriptor = FetchDescriptor<PrayerContent>()
        guard let allContent = try? modelContext.fetch(descriptor) else { return nil }

        let eligible = allContent.filter { content in
            (!content.isProOnly || profile.isPro)
                && content.faithLevelMin.numericValue <= profile.faithLevel.numericValue
        }

        guard !eligible.isEmpty else { return nil }

        let scored = eligible.map { content in
            (content: content, score: score(content: content, profile: profile, window: window))
        }

        return scored.max(by: { $0.score < $1.score })?.content
    }

    /// Generate timeline entries for remaining windows today (plus next morning)
    static func timelineEntries(
        profile: UserProfile,
        modelContext: ModelContext
    ) -> [WidgetEntry] {
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)

        let theme = ThemeDefinition.allThemes.first(where: { $0.id == profile.selectedThemeID })
            ?? ThemeDefinition.allThemes[0]

        var entries: [WidgetEntry] = []
        var usedIDs: Set<UUID> = []

        // Generate entries for remaining windows today + first window tomorrow
        let allWindows = remainingWindows(fromHour: hour)

        for (window, date) in allWindows {
            if let content = bestContent(
                window: window,
                profile: profile,
                modelContext: modelContext,
                excluding: usedIDs
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
                    themeGradient: theme.previewGradient,
                    firstName: profile.firstName
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

        // Random jitter for freshness (tighter range for widgets)
        score *= Double.random(in: 0.85...1.15)

        return score
    }

    private static func bestContent(
        window: WidgetTimeWindow,
        profile: UserProfile,
        modelContext: ModelContext,
        excluding usedIDs: Set<UUID>
    ) -> PrayerContent? {
        let descriptor = FetchDescriptor<PrayerContent>()
        guard let allContent = try? modelContext.fetch(descriptor) else { return nil }

        let eligible = allContent.filter { content in
            !usedIDs.contains(content.id)
                && (!content.isProOnly || profile.isPro)
                && content.faithLevelMin.numericValue <= profile.faithLevel.numericValue
        }

        guard !eligible.isEmpty else { return nil }

        let scored = eligible.map { content in
            (content: content, score: score(content: content, profile: profile, window: window))
        }

        return scored.max(by: { $0.score < $1.score })?.content
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
