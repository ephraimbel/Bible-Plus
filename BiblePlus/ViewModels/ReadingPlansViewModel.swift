import Foundation
import SwiftData

@MainActor
@Observable
final class ReadingPlansViewModel {

    // MARK: - State

    var allPlans: [ReadingPlan] = []
    var activePlans: [(plan: ReadingPlan, progress: UserPlanProgress)] = []
    var recommendedPlans: [ReadingPlan] = []
    var showPaywall = false
    var showCompletion = false
    var completedPlanName = ""

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadPlans()
    }

    // MARK: - Load

    func loadPlans() {
        let planDescriptor = FetchDescriptor<ReadingPlan>(sortBy: [SortDescriptor(\.name)])
        do {
            allPlans = try modelContext.fetch(planDescriptor)
        } catch {
            print("[ReadingPlans] fetch error: \(error)")
            allPlans = []
        }

        let progressDescriptor = FetchDescriptor<UserPlanProgress>(
            predicate: #Predicate { $0.isActive == true }
        )
        let activeProgress = (try? modelContext.fetch(progressDescriptor)) ?? []

        activePlans = activeProgress.compactMap { progress in
            guard let plan = allPlans.first(where: { $0.id == progress.planID }) else { return nil }
            return (plan: plan, progress: progress)
        }

        computeRecommendations()
    }

    // MARK: - Recommendations (FeedEngine-style scoring)

    private func computeRecommendations() {
        let profileDescriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? modelContext.fetch(profileDescriptor).first else {
            recommendedPlans = Array(allPlans.prefix(5))
            return
        }

        let activePlanIDs = Set(activePlans.map { $0.plan.id })
        let completedDescriptor = FetchDescriptor<UserPlanProgress>(
            predicate: #Predicate { $0.completedDate != nil }
        )
        let completedIDs = Set(((try? modelContext.fetch(completedDescriptor)) ?? []).map { $0.planID })

        let userBurdens = Set(profile.currentBurdens.map { $0.rawValue })
        let userSeasons = Set(profile.lifeSeasons.map { $0.rawValue })

        let scored = allPlans
            .filter { !activePlanIDs.contains($0.id) && !completedIDs.contains($0.id) }
            .map { plan -> (plan: ReadingPlan, score: Double) in
                var score: Double = 1.0

                if !userBurdens.intersection(Set(plan.applicableBurdens)).isEmpty {
                    score *= 3.0
                }
                if !userSeasons.intersection(Set(plan.applicableSeasons)).isEmpty {
                    score *= 2.0
                }
                if plan.faithLevelMin == profile.faithLevel.rawValue {
                    score *= 1.5
                }

                score *= Double.random(in: 0.9...1.1)
                return (plan: plan, score: score)
            }
            .sorted { $0.score > $1.score }

        recommendedPlans = scored.prefix(5).map { $0.plan }
    }

    // MARK: - Actions

    func startPlan(_ plan: ReadingPlan, isPro: Bool) {
        if plan.isProOnly && !isPro {
            showPaywall = true
            return
        }

        // Free users: 1 active plan max
        if !isPro && !activePlans.isEmpty {
            showPaywall = true
            return
        }

        let progress = UserPlanProgress(planID: plan.id)
        modelContext.insert(progress)
        try? modelContext.save()
        HapticService.success()
        loadPlans()
    }

    func completeDay(progress: UserPlanProgress, day: Int, totalDays: Int) {
        guard !progress.completedDays.contains(day) else { return }
        progress.completedDays.append(day)
        progress.lastReadDate = Date()
        let planName = allPlans.first(where: { $0.id == progress.planID })?.name ?? "Plan"
        ActivityService.log(.planDayCompleted, detail: "\(planName) — Day \(day)", in: modelContext)

        if progress.completedDays.count >= totalDays {
            progress.completedDate = Date()
            progress.isActive = false
            completedPlanName = allPlans.first(where: { $0.id == progress.planID })?.name ?? "Reading Plan"
            showCompletion = true
        }

        try? modelContext.save()
        HapticService.success()
        loadPlans()
    }

    func abandonPlan(_ progress: UserPlanProgress) {
        progress.isActive = false
        try? modelContext.save()
        HapticService.lightImpact()
        loadPlans()
    }

    func restartPlan(_ plan: ReadingPlan, isPro: Bool) {
        if plan.isProOnly && !isPro {
            showPaywall = true
            return
        }
        if !isPro && !activePlans.isEmpty {
            showPaywall = true
            return
        }
        let progress = UserPlanProgress(planID: plan.id)
        modelContext.insert(progress)
        try? modelContext.save()
        HapticService.success()
        loadPlans()
    }

    func progressForPlan(_ planID: String) -> UserPlanProgress? {
        let descriptor = FetchDescriptor<UserPlanProgress>(
            predicate: #Predicate { $0.planID == planID && $0.isActive == true }
        )
        return try? modelContext.fetch(descriptor).first
    }

    /// Returns the most recent progress for a plan regardless of active/completed status.
    /// Use this in detail views where you need to show day checkmarks even after completion.
    func latestProgressForPlan(_ planID: String) -> UserPlanProgress? {
        var descriptor = FetchDescriptor<UserPlanProgress>(
            predicate: #Predicate { $0.planID == planID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func isCompleted(_ planID: String) -> Bool {
        let descriptor = FetchDescriptor<UserPlanProgress>(
            predicate: #Predicate { $0.planID == planID && $0.completedDate != nil }
        )
        return !((try? modelContext.fetch(descriptor))?.isEmpty ?? true)
    }

    // MARK: - Categories

    var categories: [String] {
        let cats = Set(allPlans.map { $0.category })
        return cats.sorted()
    }

    func plans(for category: String) -> [ReadingPlan] {
        allPlans.filter { $0.category == category }
    }
}
