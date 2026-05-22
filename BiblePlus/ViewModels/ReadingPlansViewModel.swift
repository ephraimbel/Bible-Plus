import Foundation
import SwiftData

@MainActor
@Observable
final class ReadingPlansViewModel {

    // MARK: - State

    var allPlans: [ReadingPlan] = []
    var activePlans: [(plan: ReadingPlan, progress: UserPlanProgress)] = []
    var recommendedPlans: [ReadingPlan] = []
    /// Active progress keyed by planID, refreshed in `loadPlans`. Lets grid
    /// cards look up progress in O(1) instead of running a fresh
    /// FetchDescriptor for every card on every render.
    private(set) var activeProgressByPlanID: [String: UserPlanProgress] = [:]
    /// Completed plan IDs cached at load time so grid cards can render the
    /// "DONE" badge without doing a per-card fetch.
    private(set) var completedPlanIDs: Set<String> = []
    var showPaywall = false
    var showCompletion = false
    var completedPlanName = ""
    /// Gradient hex for the plan just completed — lets `PlanCompletionView`
    /// paint the trophy/glow in the plan's own palette instead of the generic
    /// accent. Captured at completion so the overlay matches the plan the user
    /// actually finished, not whatever plan gets tapped next.
    var completedPlanGradient: [String] = []
    /// Curated artwork key for the plan just completed — the completion
    /// overlay uses it as a dimmed radial backdrop so each finish feels
    /// specific (Romans ≠ Psalms of Peace ≠ Jonah).
    var completedPlanImageKey: String = ""
    var refreshToken: Int = 0
    var navigateToPlanDayID: String?

    /// Milestone just crossed by the most recent `completeDay` call. Detail
    /// view observes this to fire the milestone celebration overlay.
    var pendingMilestonePercent: Int?
    var pendingMilestonePlanID: String?

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
            // Fetch failed — fall back to empty list
            allPlans = []
        }

        let progressDescriptor = FetchDescriptor<UserPlanProgress>(
            predicate: #Predicate { $0.isActive && $0.completedDate == nil }
        )
        let activeProgress = (try? modelContext.fetch(progressDescriptor)) ?? []

        activePlans = activeProgress.compactMap { progress in
            guard let plan = allPlans.first(where: { $0.id == progress.planID }) else { return nil }
            return (plan: plan, progress: progress)
        }

        activeProgressByPlanID = Dictionary(
            uniqueKeysWithValues: activePlans.map { ($0.plan.id, $0.progress) }
        )

        let completedDescriptor = FetchDescriptor<UserPlanProgress>(
            predicate: #Predicate { $0.completedDate != nil }
        )
        completedPlanIDs = Set(((try? modelContext.fetch(completedDescriptor)) ?? []).map { $0.planID })

        computeRecommendations()
        refreshToken += 1
    }

    // MARK: - Recommendations (FeedEngine-style scoring)

    private func computeRecommendations() {
        let profileDescriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? modelContext.fetch(profileDescriptor).first else {
            recommendedPlans = Array(allPlans.prefix(5))
            return
        }

        let activePlanIDs = Set(activePlans.map { $0.plan.id })
        let completedIDs = completedPlanIDs

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
        modelContext.safeSave()
        HapticService.success()
        Analytics.track(.planStarted, properties: ["plan": plan.name])
        loadPlans()
        navigateToPlanDayID = plan.id
    }

    func completeDay(progress: UserPlanProgress, day: Int, totalDays: Int) {
        guard !progress.completedDays.contains(day) else { return }
        progress.completedDays.append(day)
        progress.lastReadDate = Date()
        let planName = allPlans.first(where: { $0.id == progress.planID })?.name ?? "Plan"
        ActivityService.log(.planDayCompleted, detail: "\(planName) — Day \(day)", in: modelContext)

        let isFinishing = progress.completedDays.count >= totalDays
        let milestone = isFinishing ? nil : progress.milestoneJustCrossed(totalDays: totalDays)

        var analyticsProps: [String: String] = ["plan": planName, "day": "\(day)"]
        if let milestone { analyticsProps["milestone"] = "\(milestone)" }
        Analytics.track(.planDayCompleted, properties: analyticsProps)

        if isFinishing {
            progress.completedDate = Date()
            progress.isActive = false
            let finished = allPlans.first(where: { $0.id == progress.planID })
            completedPlanName = finished?.name ?? "Reading Plan"
            completedPlanGradient = finished?.gradientColors ?? []
            completedPlanImageKey = finished?.imageKey ?? ""
            showCompletion = true
            ReviewService.shared.requestIfAppropriate()
        } else if let milestone {
            // First 25/50/75 crossing — mark it before saving so it doesn't
            // re-trigger on reload, and publish to the detail view.
            progress.markMilestoneCelebrated(milestone)
            pendingMilestonePercent = milestone
            pendingMilestonePlanID = progress.planID
        }

        modelContext.safeSave()
        HapticService.success()
        loadPlans()
    }

    func saveReflection(_ text: String, for day: Int, progress: UserPlanProgress) {
        progress.setReflection(text, for: day)
        modelContext.safeSave()
        refreshToken += 1
    }

    func consumePendingMilestone(planID: String) -> Int? {
        guard pendingMilestonePlanID == planID,
              let percent = pendingMilestonePercent else { return nil }
        pendingMilestonePercent = nil
        pendingMilestonePlanID = nil
        return percent
    }

    func abandonPlan(_ progress: UserPlanProgress) {
        progress.isActive = false
        modelContext.safeSave()
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
        modelContext.safeSave()
        HapticService.success()
        loadPlans()
        navigateToPlanDayID = plan.id
    }

    func progressForPlan(_ planID: String) -> UserPlanProgress? {
        activeProgressByPlanID[planID]
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
        completedPlanIDs.contains(planID)
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
