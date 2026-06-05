import SwiftUI
import StoreKit
import UIKit

// MARK: - Review Request (Pre-Paywall Moment)
//
// Placed right after the commitment pledge and just before the paywall — the
// single warmest, highest-intent moment in the funnel. The page is a clean,
// editorial "would you leave a review?" beat on the light Warm Paper palette;
// the native App Store rating sheet pops up over it automatically.
//
// The paywall is gated behind the review interaction: it does NOT appear until
// the user has dismissed the native rating prompt (whether they left a review
// or tapped "Not Now"). StoreKit gives no completion callback for the prompt,
// so we infer its dismissal from window key-status: presenting the prompt makes
// our window resign key, and dismissing it makes our window key again. A grace
// timer covers the case where iOS suppresses the prompt entirely (rate limit),
// so the funnel can never stall.
//
// Why here: a user who has just pledged to show up is at peak goodwill, before
// any price is shown. Asking now (rather than after the paywall) keeps the ask
// untainted by the purchase decision.
struct OnboardingReviewView: View {
    var onContinue: () -> Void = {}

    @Environment(\.bpPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview

    @State private var appeared = false
    @State private var starsLit = false
    @State private var hasRequested = false
    @State private var promptIsShowing = false
    @State private var didAdvance = false

    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer(minLength: 20)

                // Five gold stars — the visual anchor, lit with a staggered pop.
                HStack(spacing: 10) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: "star.fill")
                            .font(.system(size: 26, weight: .regular))
                            .foregroundStyle(accentGold)
                            .shadow(color: accentGold.opacity(0.35), radius: 6, y: 2)
                            .scaleEffect(starsLit ? 1 : 0.4)
                            .opacity(starsLit ? 1 : 0)
                            .animation(
                                reduceMotion ? nil :
                                    .spring(response: 0.5, dampingFraction: 0.6)
                                    .delay(0.25 + Double(i) * 0.08),
                                value: starsLit
                            )
                    }
                }

                VStack(spacing: 14) {
                    Text("BEFORE YOU BEGIN")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .tracking(2.6)
                        .foregroundStyle(accentGold)

                    Text("Would you leave a review?")
                        .font(.custom("Baskerville-Bold", size: 30))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Your review helps more people discover Bible Plus and draw closer to God.")
                        .font(.custom("Georgia-Italic", size: 16))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.textSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 30)
                }
                .padding(.top, 28)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)

                Spacer(minLength: 20)

                VStack(spacing: 10) {
                    GoldButton(title: "Leave a review", showGlow: true) {
                        HapticService.lightImpact()
                        requestReviewThenAdvance()
                    }

                    Button {
                        HapticService.lightImpact()
                        advanceToPaywall()
                    } label: {
                        Text("Maybe later")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(palette.textSecondary.opacity(0.75))
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 14)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
            }
            .padding(.vertical, 24)
        }
        // Our window resigns key when the system rating prompt appears over it.
        .onReceive(NotificationCenter.default.publisher(for: UIWindow.didResignKeyNotification)) { _ in
            if hasRequested && !didAdvance {
                promptIsShowing = true
            }
        }
        // …and becomes key again once the user dismisses the prompt (rated or
        // tapped "Not Now"). That's our cue to hand off to the paywall.
        .onReceive(NotificationCenter.default.publisher(for: UIWindow.didBecomeKeyNotification)) { _ in
            if promptIsShowing {
                promptIsShowing = false
                advanceToPaywall(delay: 0.35)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.86)) {
                appeared = true
            }
            starsLit = true

            // Pop the native rating sheet automatically once the page has
            // settled — the user explicitly wanted the review to surface here.
            // The paywall stays hidden until the prompt is dismissed.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                triggerReview()
            }
        }
    }

    /// Fires the system rating sheet once. Apple rate-limits the prompt, so a
    /// second call (e.g. the user also tapping the button) is harmlessly
    /// ignored — we just guard against a redundant request in the same view.
    private func triggerReview() {
        guard !hasRequested else { return }
        hasRequested = true
        requestReview()
    }

    /// "Leave a review" CTA: surface the prompt and let the window-key observer
    /// advance once it's dismissed. If the prompt never appears (iOS rate limit
    /// / already reviewed), a grace timer advances so the user isn't stranded.
    private func requestReviewThenAdvance() {
        triggerReview()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if !promptIsShowing { advanceToPaywall() }
        }
    }

    /// Hand off to the paywall exactly once.
    private func advanceToPaywall(delay: TimeInterval = 0) {
        guard !didAdvance else { return }
        didAdvance = true
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { onContinue() }
        } else {
            onContinue()
        }
    }

    private var background: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            RadialGradient(colors: [accentGold.opacity(0.12), .clear],
                           center: .init(x: 0.5, y: 0.30), startRadius: 0, endRadius: 340)
                .ignoresSafeArea()
        }
    }
}
