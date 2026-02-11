import Foundation
import SwiftData

@MainActor
final class StreakService {
    private let personalizationService: PersonalizationService

    init(modelContext: ModelContext) {
        self.personalizationService = PersonalizationService(modelContext: modelContext)
    }

    // MARK: - Result Types

    struct StreakCheckResult {
        let currentStreak: Int
        let isNewDay: Bool
        let isMilestone: Bool
        let milestoneType: MilestoneType?
    }

    enum MilestoneType {
        case weekly(Int)
        case monthly(Int)
        case century
        case yearly
        case epic(Int)

        var icon: String {
            switch self {
            case .weekly: "flame.fill"
            case .monthly: "star.fill"
            case .century: "crown.fill"
            case .yearly: "trophy.fill"
            case .epic: "sparkles"
            }
        }

        var celebrationMessage: String {
            switch self {
            case .weekly(7): "A whole week with God!\nKeep going."
            case .weekly(14): "Two weeks of faithfulness!"
            case .weekly(21): "Three weeks strong!"
            case .weekly: "Another week of faithfulness!"
            case .monthly(30): "30 days of devotion.\nYou're building a beautiful habit."
            case .monthly(60): "60 days. Your faithfulness\nis becoming who you are."
            case .monthly(90): "90 days. This is no longer\na habit — it's your rhythm."
            case .monthly: "Another month of devotion."
            case .century: "100 days!\nWhat a testimony."
            case .yearly: "365 days. A full year with God.\nIncredible."
            case .epic(500): "500 days of faithfulness.\nYou inspire others."
            case .epic(1000): "1,000 days. Legendary."
            case .epic: "An extraordinary milestone."
            }
        }
    }

    // MARK: - Core Logic

    func checkAndUpdateStreak() -> StreakCheckResult {
        let profile = personalizationService.getOrCreateProfile()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // First ever open
        guard let lastActive = profile.lastActiveDate else {
            profile.streakCount = 1
            profile.lastActiveDate = today
            profile.longestStreak = max(profile.longestStreak, 1)
            profile.updatedAt = Date()
            personalizationService.save()
            return StreakCheckResult(
                currentStreak: 1,
                isNewDay: true,
                isMilestone: false,
                milestoneType: nil
            )
        }

        let lastActiveDay = calendar.startOfDay(for: lastActive)

        // Already checked in today
        if lastActiveDay == today {
            return StreakCheckResult(
                currentStreak: profile.streakCount,
                isNewDay: false,
                isMilestone: false,
                milestoneType: nil
            )
        }

        let daysBetween = calendar.dateComponents([.day], from: lastActiveDay, to: today).day ?? 0

        if daysBetween == 1 {
            // Consecutive day
            profile.streakCount += 1
        } else {
            // Streak broken
            profile.streakCount = 1
        }

        profile.lastActiveDate = today
        profile.longestStreak = max(profile.longestStreak, profile.streakCount)
        profile.updatedAt = Date()
        personalizationService.save()

        let milestone = Self.milestoneType(for: profile.streakCount)
        return StreakCheckResult(
            currentStreak: profile.streakCount,
            isNewDay: true,
            isMilestone: milestone != nil,
            milestoneType: milestone
        )
    }

    // MARK: - Milestone Detection

    private static let milestoneNumbers: Set<Int> = [7, 14, 21, 30, 60, 90, 100, 365, 500, 1000]

    static func milestoneType(for count: Int) -> MilestoneType? {
        switch count {
        case 7, 14, 21: .weekly(count)
        case 30, 60, 90: .monthly(count)
        case 100: .century
        case 365: .yearly
        case 500, 1000: .epic(count)
        default: nil
        }
    }
}
