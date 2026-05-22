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

    // Quick spring for button press feedback
    static let buttonPress = Animation.spring(response: 0.2, dampingFraction: 0.6)

    // Smooth spring for tab/segment content switches
    static let contentSwitch = Animation.spring(response: 0.35, dampingFraction: 0.8)

    // Stagger delay helper for sequential card animations
    static func staggered(index: Int, base: Double = 0.05) -> Animation {
        spring.delay(Double(index) * base)
    }

    // MARK: - Premium motion vocabulary
    //
    // Five intentional curves, one for each role. New code in the onboarding
    // and paywall flows should reach for these instead of ad-hoc springs —
    // it gives every entrance/selection/reveal a consistent, considered feel.

    /// Element arrives into the scene. Slight settle, never bouncy.
    static let arrive = Animation.spring(response: 0.55, dampingFraction: 0.88)

    /// Hero/headline arrival. Slower, more composed.
    static let hero = Animation.spring(response: 0.7, dampingFraction: 0.9)

    /// Selection acknowledgement. Tight, responsive, never mushy.
    static let press = Animation.spring(response: 0.32, dampingFraction: 0.72)

    /// Content reveal (fade + subtle slide). Linear-ish, no overshoot.
    static let reveal = Animation.easeOut(duration: 0.45)

    /// Breathing auras and long ambient pulses. Respect reduce-motion.
    static let breathe = Animation.easeInOut(duration: 3.2).repeatForever(autoreverses: true)

    /// Weighty, one-shot spring for commitment moments — purchase success,
    /// verse reveal completion. Slower response, heavier damping than
    /// `arrive`. Use sparingly; over-use dilutes the weight.
    static let consecrate = Animation.spring(response: 0.9, dampingFraction: 0.78, blendDuration: 0.3)

    /// Visible scale pulse for idle CTAs (scale 1.0 ↔ 1.035). 1.6s cycle is
    /// the industry standard for pulsing CTAs — slow enough to feel intentional,
    /// fast enough to pull the eye. Pair with a scaleEffect bound to a @State
    /// bool toggling on the same rhythm, plus a shadow that breathes with it.
    /// Decorative only — callers must gate with `reduceMotion`.
    static let ctaBreath = Animation.easeInOut(duration: 1.6).repeatForever(autoreverses: true)
}

// MARK: - Reduce-Motion Helpers

extension View {
    /// Conditionally applies an animation, replacing it with nil when the
    /// user has Reduce Motion enabled. Use on views whose animation is
    /// decorative (auras, parallax, particles) — functional transitions
    /// can stay animated.
    @ViewBuilder
    func bpAnimation<V: Equatable>(_ animation: Animation?, value: V, reduceMotion: Bool) -> some View {
        if reduceMotion {
            self.animation(nil, value: value)
        } else {
            self.animation(animation, value: value)
        }
    }
}

// MARK: - Pressable Button Style

/// Premium scale-on-press button style — applies to CTAs for tactile feedback
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(BPAnimation.buttonPress, value: configuration.isPressed)
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
