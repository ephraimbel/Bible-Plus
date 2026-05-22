import UIKit

enum HapticService {
    // MARK: - Primitive APIs (existing)

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    static func lightImpact() {
        impact(.light)
    }

    static func success() {
        notification(.success)
    }

    // MARK: - Semantic APIs
    //
    // Use these instead of raw impact/selection calls. Each has a single
    // meaning tied to a moment in the app; the mapping to system feedback
    // can evolve without touching call sites.

    /// Text field or input focus. Subtle.
    static func fieldEntry() {
        selection()
    }

    /// Chip / option tap (onboarding, filter pills).
    static func chipTap() {
        impact(.soft)
    }

    /// Advance to next onboarding screen.
    static func stepAdvance() {
        impact(.light)
    }

    /// Name committed, verse revealed, answer accepted.
    static func commit() {
        notification(.success)
    }

    /// Purchase succeeded, streak unlocked, milestone. Triple-beat weight.
    /// The three-stage pattern is the single haptic that reads as "premium"
    /// to the user without them knowing why.
    static func consecrate() {
        notification(.success)
        Task {
            try? await Task.sleep(nanoseconds: 80_000_000)
            await MainActor.run { impact(.heavy) }
            try? await Task.sleep(nanoseconds: 120_000_000)
            await MainActor.run { notification(.success) }
        }
    }

    /// Invalid input, blocked action.
    static func invalid() {
        notification(.warning)
    }
}
