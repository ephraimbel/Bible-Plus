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
}
