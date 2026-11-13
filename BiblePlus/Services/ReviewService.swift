import StoreKit
import UIKit

/// Asks for an App Store rating using ONLY Apple's native prompt.
///
/// App Store Guideline 5.6.1: apps must use the provided API to prompt for
/// reviews — no custom "Enjoying Bible+?" pre-prompts that route happy users
/// to the review sheet ("review gating"), no incentives, and no prompts before
/// the user has actually used the app (e.g. during onboarding). The system
/// itself limits the native prompt to 3 displays per 365 days.
@MainActor
final class ReviewService {
    static let shared = ReviewService()

    private let lastPromptDateKey = "io.bibleplus.lastReviewPromptDate"
    private let firstSeenDateKey = "io.bibleplus.firstSeenDate"
    /// Our own extra spacing on top of Apple's 3-per-year system cap.
    private let minimumDaysBetweenPrompts = 120
    /// Don't ask until the user has had the app for a few days.
    private let minimumDaysSinceFirstUse = 3

    private init() {}

    /// Call after a genuine positive moment (finished a plan, etc.).
    func requestIfAppropriate() {
        let defaults = UserDefaults.standard
        let now = Date()

        guard let firstSeen = defaults.object(forKey: firstSeenDateKey) as? Date else {
            defaults.set(now, forKey: firstSeenDateKey)
            return
        }
        guard daysBetween(firstSeen, now) >= minimumDaysSinceFirstUse else { return }

        if let lastPrompt = defaults.object(forKey: lastPromptDateKey) as? Date,
           daysBetween(lastPrompt, now) < minimumDaysBetweenPrompts {
            return
        }

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        defaults.set(now, forKey: lastPromptDateKey)
        Task {
            // Let the moment land before the system sheet appears.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            AppStore.requestReview(in: scene)
        }
    }

    /// Opens the App Store "Write a Review" page. Use for an explicit,
    /// user-initiated "Rate the App" button (the native prompt may not show).
    static let writeReviewURL = URL(string: "https://apps.apple.com/app/id6759114318?action=write-review")!

    private func daysBetween(_ a: Date, _ b: Date) -> Int {
        Calendar.current.dateComponents([.day], from: a, to: b).day ?? 0
    }
}
