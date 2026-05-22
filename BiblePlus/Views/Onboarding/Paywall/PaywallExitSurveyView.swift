import SwiftUI

// MARK: - Paywall Exit Downsell
//
// Replaces the prior reason-only exit survey with a soft downsell. Research
// shows post-dismissal downsell offers can recover 10–15% of ARPU without
// perceiving as desperate, as long as the offer is single, clean, and the
// "No thanks" escape is always one tap away.
//
// Architecture:
//   1. Hero: "Try it free — upgrade anytime." The headline re-frames the
//      exit as a positive choice rather than a rejection.
//   2. Primary CTA: "Continue with Free." Gold, prominent, one tap out.
//      Dismissing via this button sends `.wantToExplore` as the reason so
//      downstream analytics still measure intent.
//   3. Optional reason chips below, collapsed behind an "Optional: help us
//      improve" disclosure. Users who want to vent can; users who just want
//      out don't have to.
//
// The view still respects Apple's Guideline 3.1.2: no countdown, no guilt,
// no fake scarcity, no second modal on top of the first.

struct PaywallExitSurveyView: View {
    @Environment(\.dismiss) private var dismiss

    /// Fired ONLY when the user explicitly chooses to leave the paywall
    /// via the "Continue with Free" button. Tapping the X, swiping the
    /// sheet down, tapping outside, or selecting a reason chip never
    /// advances the user — those interactions just close the sheet and
    /// return them to the paywall. The only way out of the paywall is
    /// to tap the primary action.
    let onAnswer: (ExitReason) -> Void

    @State private var selected: ExitReason? = nil
    @State private var showContent = false
    @State private var showReasons = false

    // Locked to the light palette so the sheet matches the paywall
    // beneath it. Without this, the sheet inherits the surrounding
    // ConversationalOnboardingView's dark environment palette and the
    // slide-up reads as a color flash before the paywall comes back.
    private let palette = BPColorPalette.light
    private let gold = Color(red: 0.79, green: 0.66, blue: 0.43)

    enum ExitReason: String, CaseIterable, Identifiable {
        case tooExpensive = "too_expensive"
        case notRightTime = "not_right_time"
        case wantToExplore = "want_to_explore"
        case other = "other"

        var id: String { rawValue }
        var label: String {
            switch self {
            case .tooExpensive: return "Too expensive right now"
            case .notRightTime: return "Not the right time"
            case .wantToExplore: return "I want to explore the app first"
            case .other: return "Something else"
            }
        }
        var icon: String {
            switch self {
            case .tooExpensive: return "dollarsign.circle"
            case .notRightTime: return "clock"
            case .wantToExplore: return "magnifyingglass"
            case .other: return "ellipsis.circle"
            }
        }
    }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Close — tapping X just dismisses the sheet, returning
                // the user to the paywall. Doesn't fire onAnswer.
                HStack {
                    Spacer()
                    Button {
                        HapticService.lightImpact()
                        Analytics.track(.paywallDownsellShown, properties: ["dismissed": "x"])
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.textMuted)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(palette.surfaceElevated.opacity(0.9)))
                            .overlay(Circle().stroke(palette.border.opacity(0.4), lineWidth: 0.5))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer(minLength: 0)

                header

                Spacer(minLength: 20)

                primaryCTA
                    .padding(.horizontal, 28)

                reasonsDisclosure
                    .padding(.top, 18)
                    .padding(.horizontal, 24)

                Spacer(minLength: 0)

                Text("You can upgrade to Pro from Settings anytime.")
                    .font(.custom("Georgia-Italic", size: 11))
                    .foregroundStyle(palette.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
            }
            // Single fade-in on the whole content stack — no per-element
            // staggered offsets. Staggered animations on a sheet that's
            // already mid-presentation animation compound into jank.
            .opacity(showContent ? 1 : 0)
        }
        .onAppear {
            Analytics.track(.paywallDownsellShown)
            withAnimation(.easeOut(duration: 0.22)) {
                showContent = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            // Gold ornament — same visual hallmark as the paywall itself
            HStack(spacing: 6) {
                Circle().fill(gold.opacity(0.5)).frame(width: 3, height: 3)
                Rectangle().fill(gold.opacity(0.35)).frame(width: 28, height: 0.5)
                Image(systemName: "diamond.fill")
                    .font(.system(size: 5, weight: .light))
                    .foregroundStyle(gold.opacity(0.7))
                Rectangle().fill(gold.opacity(0.35)).frame(width: 28, height: 0.5)
                Circle().fill(gold.opacity(0.5)).frame(width: 3, height: 3)
            }

            Text("Try it free for now")
                .font(.custom("Baskerville-Bold", size: 26))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)

            Text("Start with the free version. Upgrade\nto Pro from Settings anytime.")
                .font(.custom("Georgia-Italic", size: 14))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Primary CTA

    private var primaryCTA: some View {
        Button {
            // "Continue with Free" logs as wantToExplore since that's the
            // signal: user isn't saying no to Pro, just wants to try first.
            HapticService.impact(.light)
            Analytics.track(.paywallDownsellAccepted)
            onAnswer(.wantToExplore)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                Text("Continue with Free")
                    .font(.custom("Georgia-Bold", size: 16))
                    .tracking(0.3)
            }
            .foregroundStyle(palette.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            // Solid surface fill — no ultraThinMaterial. Material in a
            // sheet re-blurs the underlying paywall on every animation
            // frame, which was the primary source of slide-up jank.
            .background(
                Capsule().fill(palette.surfaceElevated)
            )
            .overlay(
                Capsule()
                    .stroke(gold.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: gold.opacity(0.18), radius: 8, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Optional Reasons Disclosure

    private var reasonsDisclosure: some View {
        VStack(spacing: 10) {
            Button {
                HapticService.chipTap()
                // Fast easeOut, not a spring. Spring response curves
                // for layout-changing animations (insertion of 4 rows)
                // compound the layout pass cost over the full bounce
                // window; a 0.18s easeOut snaps in and out cleanly.
                withAnimation(.easeOut(duration: 0.18)) {
                    showReasons.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(showReasons ? "Hide feedback" : "Optional: help us improve")
                        .font(.custom("Georgia-Italic", size: 12))
                        .foregroundStyle(palette.textMuted)
                    Image(systemName: showReasons ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(palette.textMuted)
                }
            }
            .buttonStyle(.plain)

            if showReasons {
                VStack(spacing: 8) {
                    ForEach(ExitReason.allCases) { reason in
                        reasonRow(reason)
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private func reasonRow(_ reason: ExitReason) -> some View {
        let isSelected = selected == reason

        return Button {
            HapticService.chipTap()
            withAnimation(.easeOut(duration: 0.18)) {
                selected = reason
            }
            // Reason chips are pure feedback — they record analytics and
            // show the selected state but do NOT exit the paywall. The
            // user must explicitly press "Continue with Free" to leave.
            Analytics.track(.paywallExitSurveyAnswered, properties: [
                "reason": reason.rawValue,
            ])
        } label: {
            HStack(spacing: 12) {
                Image(systemName: reason.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? .white : gold)
                    .frame(width: 22, height: 22)

                Text(reason.label)
                    .font(.custom("Georgia", size: 14))
                    .foregroundStyle(isSelected ? .white : palette.textPrimary)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            // Solid palette fill — no ultraThinMaterial. Materials
            // re-blur the underlying paywall every frame, which was
            // tanking interaction smoothness.
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? gold : palette.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? gold.opacity(0.8) : palette.border.opacity(0.15),
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}
