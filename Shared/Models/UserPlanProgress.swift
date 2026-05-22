import Foundation
import SwiftData

@Model
final class UserPlanProgress {
    var id: UUID = UUID()
    var planID: String = ""
    var completedDays: [Int] = []
    var startDate: Date = Date()
    var lastReadDate: Date? = nil
    var completedDate: Date? = nil
    var isActive: Bool = true
    var createdAt: Date = Date()

    /// Per-day reflections. Encoded as JSON `[String: String]` (day-number → text)
    /// because SwiftData's default value constraint doesn't play well with
    /// dictionary-typed stored properties, and JSON keeps keys as strings which
    /// is the least-surprising on-disk representation.
    var reflectionsJSON: Data = Data()

    /// Milestone celebration flags. Encoded as JSON `[Int]` of milestone
    /// percentages (25/50/75) already celebrated for this plan run, so the
    /// overlay only fires once per crossing.
    var celebratedMilestonesJSON: Data = Data()

    init(planID: String) {
        self.id = UUID()
        self.planID = planID
        self.completedDays = []
        self.startDate = Date()
        self.isActive = true
        self.createdAt = Date()
    }

    var isCompleted: Bool { completedDate != nil }

    func completionFraction(totalDays: Int) -> Double {
        guard totalDays > 0 else { return 0 }
        return Double(completedDays.count) / Double(totalDays)
    }

    func nextDay(totalDays: Int) -> Int {
        for day in 1...totalDays {
            if !completedDays.contains(day) { return day }
        }
        return totalDays
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

    // MARK: - Milestones

    var celebratedMilestones: Set<Int> {
        let arr = (try? JSONDecoder().decode([Int].self, from: celebratedMilestonesJSON)) ?? []
        return Set(arr)
    }

    func markMilestoneCelebrated(_ percent: Int) {
        var set = celebratedMilestones
        set.insert(percent)
        celebratedMilestonesJSON = (try? JSONEncoder().encode(Array(set).sorted())) ?? Data()
    }

    /// Returns the newly crossed milestone (25/50/75) if this completion is the
    /// first one to hit or pass that threshold. Nil if no new milestone fired.
    ///
    /// Skipped for plans shorter than 8 days: on a 4- or 7-day plan a "25% done"
    /// ribbon would fire on day 1 or 2 and feel noisy rather than celebratory.
    /// PlanDetailView also hides milestone flags for <8-day plans, so gating
    /// here keeps both surfaces consistent.
    func milestoneJustCrossed(totalDays: Int) -> Int? {
        guard totalDays >= 8 else { return nil }
        let pct = Int(completionFraction(totalDays: totalDays) * 100)
        let already = celebratedMilestones
        for threshold in [75, 50, 25] where pct >= threshold && !already.contains(threshold) {
            return threshold
        }
        return nil
    }
}
