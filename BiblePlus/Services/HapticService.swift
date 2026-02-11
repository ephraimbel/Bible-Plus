import UIKit

enum HapticService {
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

    static func heavyImpact() {
        impact(.heavy)
    }

    static func success() {
        notification(.success)
    }

    static func error() {
        notification(.error)
    }
}
