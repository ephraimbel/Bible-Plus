import SwiftUI

struct WelcomeView: View {
    let viewModel: OnboardingViewModel
    @Environment(\.bpPalette) private var palette
    @State private var showTagline = false
    @State private var showSubtitle = false
    @State private var showButton = false
    @State private var imageScale: CGFloat = 1.0

    // Opening-bloom transition into onboarding
    @State private var isTransitioning = false
    @State private var bloomScale: CGFloat = 0.45
    @State private var bloomOpacity: Double = 0.0
    @State private var innerBloomScale: CGFloat = 0.55
    @State private var innerBloomOpacity: Double = 0.0
    @State private var paintingDim: Double = 0.0
    @State private var paintingBlur: CGFloat = 0.0
    @State private var transitionZoom: CGFloat = 1.0
    @State private var textFade: Double = 1.0
    @State private var textOffset: CGFloat = 0.0
    @State private var buttonScale: CGFloat = 1.0

    private let accentGold = Color(red: 0.82, green: 0.65, blue: 0.35)
    private let warmCream = Color(red: 1.0, green: 0.96, blue: 0.88)
    private let softGold = Color(red: 0.95, green: 0.82, blue: 0.55)
    private let deepSepia = Color(red: 0.18, green: 0.12, blue: 0.06)
    // Exact match for the onboarding Warm Paper background (#FBF8F3) so the
    // opening bloom saturates to the SAME color the first question screen uses
    // — the swell "becomes" the onboarding page with no color jump on handoff.
    private let paperBright = Color(red: 0.984, green: 0.973, blue: 0.953)

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Sepia backdrop so any exposed edge blends with the art
                deepSepia.ignoresSafeArea()

                // Hero artwork — full-bleed so the composition extends edge to edge
                Image("welcome_divine_touch")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(imageScale * transitionZoom)
                    .blur(radius: paintingBlur)
                    .clipped()
                    .overlay(
                        deepSepia.opacity(paintingDim).ignoresSafeArea()
                    )
                    .ignoresSafeArea()

                // Bottom warm fade — grounds the text without flattening the clouds.
                // Lighter and shorter than before so more of the artwork reads.
                LinearGradient(
                    colors: [
                        Color.clear,
                        deepSepia.opacity(0.35),
                        deepSepia.opacity(0.72)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: geo.size.height * 0.26)
                .allowsHitTesting(false)
                .ignoresSafeArea()

                // Inner bloom — a tight, warm pool that appears to gather
                // at the Bible first, before the wider spread catches up.
                // Two-layer bloom reads as light having depth instead of
                // a single uniform wash. Clipped to a Circle so the fade
                // is round (gradient frames otherwise clip to a square).
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: paperBright.opacity(0.90), location: 0.0),
                                .init(color: paperBright.opacity(0.60), location: 0.30),
                                .init(color: softGold.opacity(0.32), location: 0.58),
                                .init(color: accentGold.opacity(0.10), location: 0.82),
                                .init(color: .clear, location: 1.0)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 260
                        )
                    )
                    .frame(width: 520, height: 520)
                    .blur(radius: 26)
                    .scaleEffect(innerBloomScale)
                    .opacity(innerBloomOpacity)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.48)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()

                // Opening bloom — a warm radial light that swells from the
                // Bible's position in the painting and "becomes" the page
                // the user is flipped into. Clipped to a Circle and sized
                // so endRadius == frame/2 — the gradient fits its bounding
                // box exactly, so there are no square edges as it scales.
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: paperBright, location: 0.0),
                                .init(color: paperBright.opacity(0.95), location: 0.44),
                                .init(color: softGold.opacity(0.30), location: 0.70),
                                .init(color: accentGold.opacity(0.10), location: 0.88),
                                .init(color: .clear, location: 1.0)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: max(geo.size.width, geo.size.height) * 1.25
                        )
                    )
                    .frame(
                        width: max(geo.size.width, geo.size.height) * 2.5,
                        height: max(geo.size.width, geo.size.height) * 2.5
                    )
                    .blur(radius: 40)
                .scaleEffect(bloomScale)
                .opacity(bloomOpacity)
                .position(x: geo.size.width * 0.5, y: geo.size.height * 0.48)
                .allowsHitTesting(false)
                .ignoresSafeArea()

                // Content — minimal: tagline + CTA only
                VStack(spacing: 26) {
                    VStack(spacing: 10) {
                        HStack(spacing: 14) {
                            hairline(trailingFade: false)
                            Text("A Sacred Companion")
                                .font(.custom("Baskerville", size: 28))
                                .tracking(0.4)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [warmCream, softGold, warmCream],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: accentGold.opacity(0.35), radius: 10)
                                .shadow(color: deepSepia.opacity(0.55), radius: 8, y: 2)
                                .fixedSize()
                                .opacity(showTagline ? 1 : 0)
                                .offset(y: showTagline ? 0 : 10)
                            hairline(trailingFade: true)
                        }

                        Text("✦")
                            .font(.system(size: 10, weight: .light))
                            .foregroundStyle(softGold.opacity(0.85))
                            .shadow(color: accentGold.opacity(0.55), radius: 4)
                            .shadow(color: deepSepia.opacity(0.5), radius: 3, y: 1)
                            .opacity(showSubtitle ? 1 : 0)

                        Text("For prayer, scripture, and quiet moments.")
                            .font(.custom("Georgia-Italic", size: 15))
                            .foregroundStyle(warmCream.opacity(0.8))
                            .tracking(0.4)
                            .shadow(color: deepSepia.opacity(0.55), radius: 6, y: 1)
                            .opacity(showSubtitle ? 1 : 0)
                            .offset(y: showSubtitle ? 0 : 8)
                    }
                    .multilineTextAlignment(.center)

                    Button {
                        beginOpeningTransition()
                    } label: {
                        Text("Begin Your Journey")
                            .font(.custom("Georgia", size: 18))
                            .tracking(0.4)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial.opacity(0.5))
                            )
                            .background(
                                Capsule()
                                    .fill(accentGold.opacity(0.22))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(accentGold.opacity(0.55), lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.horizontal, 44)
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 16)
                    .scaleEffect(buttonScale)
                    .disabled(isTransitioning)
                }
                .padding(.bottom, 44)
                .opacity(textFade)
                .offset(y: textOffset)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            viewModel.audioService.playResource("heavenlyWorship", ext: "m4a")

            // Very subtle Ken Burns — keep the centered composition anchored
            withAnimation(.easeInOut(duration: 32).repeatForever(autoreverses: true)) {
                imageScale = 1.04
            }

            withAnimation(.easeOut(duration: 0.9).delay(0.3)) {
                showTagline = true
            }

            withAnimation(.easeOut(duration: 0.9).delay(0.7)) {
                showSubtitle = true
            }

            withAnimation(.easeOut(duration: 0.8).delay(1.1)) {
                showButton = true
            }
        }
    }

    /// Plays the opening-bloom transition, then advances the onboarding
    /// view model. The bloom swells from the Bible's center, dimming the
    /// painting and fading the text; at peak brightness the container
    /// crossfades to the first chat page, so the warm gold light reads as
    /// the book opening into the onboarding itself.
    private func beginOpeningTransition() {
        guard !isTransitioning else { return }
        isTransitioning = true

        HapticService.impact(.light)

        // Text drifts up as it fades — small offset (-10) reads as calm;
        // anything bigger feels like it's being flicked off.
        withAnimation(.timingCurve(0.33, 0.0, 0.15, 1.0, duration: 0.8)) {
            textFade = 0.0
            textOffset = -10
        }

        // Button contracts slightly as it leaves — gives it a sense of
        // settling back rather than just disappearing.
        withAnimation(.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.7)) {
            buttonScale = 0.96
        }

        // Painting exhales: slow zoom + dim + soft blur on a critically-
        // damped spring so it settles without overshoot. Longer response
        // reads as depth-of-field pulling focus away.
        withAnimation(.spring(response: 1.5, dampingFraction: 1.0)) {
            paintingDim = 0.26
            paintingBlur = 8.0
            transitionZoom = 1.05
        }

        // Inner bloom arrives first — warm light pools at the Bible
        // before the wider spread catches up. Opacity front-loaded so
        // the glow is present early, while the scale keeps growing.
        withAnimation(.easeOut(duration: 0.75).delay(0.18)) {
            innerBloomOpacity = 1.0
        }
        withAnimation(.spring(response: 1.25, dampingFraction: 1.0).delay(0.18)) {
            innerBloomScale = 1.0
        }

        // Outer bloom — opacity and scale intentionally decoupled so the
        // light arrives faster than it spreads. Feels like the light is
        // settling into the space rather than swelling outward.
        withAnimation(.easeOut(duration: 0.95).delay(0.4)) {
            bloomOpacity = 1.0
        }
        withAnimation(.spring(response: 1.6, dampingFraction: 1.0).delay(0.4)) {
            bloomScale = 1.0
        }

        // Hand off at 1.9s — bloom opacity saturated by ~1.35s, scale
        // settled by ~1.6s, leaving ~300ms of held peak light before the
        // container crossfades to the first chat page. The hold is where
        // the transition stops feeling like an animation and starts
        // feeling like a moment.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            viewModel.goNext()
        }
    }

    /// Short hairline flourish flanking the tagline. Gradient fades to
    /// transparent on the outer edge so the line reads as drawn-in rather
    /// than a hard rule.
    private func hairline(trailingFade: Bool) -> some View {
        let colors: [Color] = trailingFade
            ? [accentGold.opacity(0.55), accentGold.opacity(0)]
            : [accentGold.opacity(0), accentGold.opacity(0.55)]
        return LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 26, height: 0.6)
        .opacity(showTagline ? 1 : 0)
    }
}
