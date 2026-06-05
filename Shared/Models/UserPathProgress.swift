import Foundation
import SwiftData

@Model
final class UserPathProgress {
    var id: UUID = UUID()
    var pathID: String = ""
    var completedDays: [Int] = []
    var startDate: Date = Date()
    var lastActiveDate: Date? = nil
    var completedDate: Date? = nil

    /// Date the user last completed a brand-new day (not a re-read of a day
    /// they'd already finished). Drives the one-day-per-day pacing gate: once
    /// today's day is done, the next day unlocks on the next calendar day.
    /// Re-reading a finished day never touches this.
    var lastNewDayCompletedDate: Date? = nil
    var isActive: Bool = true
    var createdAt: Date = Date()

    /// Per-day reflections written in the Reflection step. JSON-encoded
    /// `[String: String]` (day-number as string → text) — same pattern as
    /// `UserPlanProgress.reflectionsJSON` because SwiftData's default-value
    /// constraint doesn't play nicely with dictionary-typed properties.
    var reflectionsJSON: Data = Data()

    /// Per-day quiz results. JSON-encoded `[String: Bool]` (day-number → was
    /// the answer correct on first try). Used to surface a gentle "you got
    /// most of these right" recap at path completion — never to gate progress.
    var quizResultsJSON: Data = Data()

    /// Resumable mid-day state. JSON-encoded `PartialDayState?`. Set when a
    /// user opens a day session and completes some-but-not-all steps; cleared
    /// when the day is marked complete.
    var partialDayJSON: Data = Data()

    init(pathID: String) {
        self.id = UUID()
        self.pathID = pathID
        self.completedDays = []
        self.startDate = Date()
        self.lastActiveDate = Date()
        self.isActive = true
        self.createdAt = Date()
    }

    var isCompleted: Bool { completedDate != nil }

    func completionFraction(totalDays: Int) -> Double {
        guard totalDays > 0 else { return 0 }
        return Double(completedDays.count) / Double(totalDays)
    }

    func nextDay(totalDays: Int) -> Int {
        for day in 1...max(totalDays, 1) {
            if !completedDays.contains(day) { return day }
        }
        return totalDays
    }

    /// True if a brand-new day was already completed earlier today. When true,
    /// the next uncompleted day is held until tomorrow (one day per day).
    func completedNewDayToday(now: Date = Date()) -> Bool {
        guard let date = lastNewDayCompletedDate else { return false }
        return Calendar.current.isDate(date, inSameDayAs: now)
    }

    // MARK: - Reflections

    func reflection(for day: Int) -> String? {
        guard let dict = try? JSONDecoder().decode([String: String].self, from: reflectionsJSON) else { return nil }
        let raw = dict["\(day)"] ?? ""
        return raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : raw
    }

    func setReflection(_ text: String, for day: Int) {
        var dict = (try? JSONDecoder().decode([String: String].self, from: reflectionsJSON)) ?? [:]
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            dict.removeValue(forKey: "\(day)")
        } else {
            dict["\(day)"] = text
        }
        reflectionsJSON = (try? JSONEncoder().encode(dict)) ?? Data()
    }

    // MARK: - Quiz

    func recordQuizResult(_ correct: Bool, for day: Int) {
        var dict = (try? JSONDecoder().decode([String: Bool].self, from: quizResultsJSON)) ?? [:]
        dict["\(day)"] = correct
        quizResultsJSON = (try? JSONEncoder().encode(dict)) ?? Data()
    }

    func quizResult(for day: Int) -> Bool? {
        guard let dict = try? JSONDecoder().decode([String: Bool].self, from: quizResultsJSON) else { return nil }
        return dict["\(day)"]
    }

    // MARK: - Partial Day (Resume)

    var partialDay: PartialDayState? {
        guard !partialDayJSON.isEmpty else { return nil }
        return try? JSONDecoder().decode(PartialDayState.self, from: partialDayJSON)
    }

    func setPartialDay(_ state: PartialDayState?) {
        guard let state else {
            partialDayJSON = Data()
            return
        }
        partialDayJSON = (try? JSONEncoder().encode(state)) ?? Data()
    }
}
