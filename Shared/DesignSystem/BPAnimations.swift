import SwiftUI

enum BPAnimation {
    // Primary spring — PRD spec: damping 0.8, response 0.4
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8)

    // Gentle spring for page transitions
    static let pageTransition = Animation.spring(response: 0.5, dampingFraction: 0.85)

    // Quick spring for selection feedback
    static let selection = Animation.spring(response: 0.3, dampingFraction: 0.7)

    // Slow pulse for glow effects (Welcome screen button)
    static let glowPulse = Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)

    // Fade in for content appearance
    static let fadeIn = Animation.easeIn(duration: 0.3)

    // Smooth fade for sound transitions
    static let soundCrossfade = Animation.easeInOut(duration: 1.5)

    // Stagger delay helper for sequential card animations
    static func staggered(index: Int, base: Double = 0.05) -> Animation {
        spring.delay(Double(index) * base)
    }
}

// MARK: - Transition Presets

extension AnyTransition {
    /// Forward navigation: slide in from right, slide out to left
    static var onboardingForward: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    /// Backward navigation: slide in from left, slide out to right
    static var onboardingBackward: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }

    /// Scale up with fade for card selections
    static var cardAppear: AnyTransition {
        .scale(scale: 0.9).combined(with: .opacity)
    }
}
