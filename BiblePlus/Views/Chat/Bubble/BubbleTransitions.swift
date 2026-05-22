import SwiftUI

private struct CardRevealModifier: ViewModifier, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .scaleEffect(0.92 + (0.08 * progress), anchor: .top)
            .blur(radius: (1 - progress) * 10)
            .offset(y: (1 - progress) * 28)
    }
}

private struct TextSegmentRevealModifier: ViewModifier, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .offset(y: (1 - progress) * 6)
    }
}

extension AnyTransition {
    /// Slow, deliberate reveal for rich cards. Pairs with ChatBubble's
    /// ~0.95s spring so cards take ~1s to fully resolve.
    static var cardReveal: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: CardRevealModifier(progress: 0),
                identity: CardRevealModifier(progress: 1)
            ),
            removal: .opacity
        )
    }

    /// Light fade-up for plain text — never blurred (would distract
    /// from the typewriter feel).
    static var textSegmentReveal: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: TextSegmentRevealModifier(progress: 0),
                identity: TextSegmentRevealModifier(progress: 1)
            ),
            removal: .opacity
        )
    }
}
