import StoreKit
import UIKit

@MainActor
@Observable
final class ReviewService {
    static let shared = ReviewService()

    var showPrompt = false

    private let lastPromptDateKey = "io.bibleplus.lastReviewPromptDate"
    private let minimumDaysBetweenPrompts = 7

    private init() {}

    /// Call at high-delight moments. Shows custom prompt with cooldown.
    func requestIfAppropriate() {
        let defaults = UserDefaults.standard
        let now = Date()

        // Cooldown: don't show our custom prompt more than once per 7 days
        if let lastPrompt = defaults.object(forKey: lastPromptDateKey) as? Date {
            let daysSince = Calendar.current.dateComponents([.day], from: lastPrompt, to: now).day ?? 0
            guard daysSince >= minimumDaysBetweenPrompts else { return }
        }

        // Record prompt date
        defaults.set(now, forKey: lastPromptDateKey)

        // Small delay so the user sees the delight moment first
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            showPrompt = true
        }
    }

    /// User tapped "Yes" — fire the real system review dialog.
    func userTappedYes() {
        showPrompt = false
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            AppStore.requestReview(in: scene)
        }
    }

    /// User tapped "Not yet" — dismiss, will ask again after cooldown.
    func userTappedNotYet() {
        showPrompt = false
    }
}
