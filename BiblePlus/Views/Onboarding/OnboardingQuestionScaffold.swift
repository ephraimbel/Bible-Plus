import SwiftUI

// MARK: - Onboarding Question Scaffold
//
// The clean, light, editorial chrome shared by every onboarding question
// (name, faith, season, burdens, notifications). Replaces the old book-page +
// typewriter "parchment" aesthetic. Warm Paper background + soft gold glow, a
// slim segmented progress bar, a gold eyebrow, a Baskerville headline, an
// optional italic subtitle, the question's input, and a pinned footer action.
//
// Content and footer arrive with a gentle staggered rise so each screen feels
// composed, not popped — enterprise-grade calm.
struct OnboardingQuestionScaffold<Content: View, Footer: View>: View {
    let stepNumber: Int       // 1-based position among the question steps
    let totalSteps: Int
    let eyebrow: String
    let headline: String
    var subtitle: String? = nil
    var showBack: Bool = true
    var onBack: () -> Void = {}
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    @Environment(\.bpPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 14)

                        content()
                            .padding(.top, 28)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(
                                reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.86).delay(0.10),
                                value: appeared
                            )
                    }
                    .padding(.horizontal, 26)
                    .padding(.top, 22)
                    .padding(.bottom, 24)
                }

                footer()
                    .padding(.horizontal, 26)
                    .padding(.bottom, 12)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.20),
                        value: appeared
                    )
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.86)) {
                appeared = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(eyebrow)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .tracking(2.6)
                .foregroundStyle(accentGold)

            Text(headline)
                .font(.custom("Baskerville-Bold", size: 30))
                .foregroundStyle(palette.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                Text(subtitle)
                    .font(.custom("Georgia-Italic", size: 16))
                    .foregroundStyle(palette.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Top bar (back + segmented progress)

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { onBack() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(palette.surfaceElevated))
                    .overlay(Circle().stroke(palette.border.opacity(0.45), lineWidth: 0.5))
            }
            .opacity(showBack ? 1 : 0)
            .allowsHitTesting(showBack)

            HStack(spacing: 5) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i < stepNumber ? accentGold : palette.border.opacity(0.30))
                        .frame(height: 4)
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: stepNumber)
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            RadialGradient(
                colors: [accentGold.opacity(0.10), .clear],
                center: .init(x: 0.5, y: 0.14),
                startRadius: 0,
                endRadius: 320
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Selectable Card
//
// The clean tappable option used across the question steps — a 2-column chip
// or a full-width row. Solid Warm-Paper card by default; fills with gold and
// turns the label white when selected, with a soft gold glow. Replaces the old
// gradient "gem" chips.
struct OnboardingSelectableCard: View {
    let label: String
    let isSelected: Bool
    var fullWidth: Bool = false
    let action: () -> Void

    @Environment(\.bpPalette) private var palette
    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.custom(fullWidth ? "Georgia" : "Georgia", size: fullWidth ? 17 : 15.5))
                    .foregroundStyle(isSelected ? .white : palette.textPrimary)
                    .multilineTextAlignment(fullWidth ? .leading : .center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .allowsTightening(true)
                    .fixedSize(horizontal: false, vertical: true)

                if fullWidth { Spacer(minLength: 0) }

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: fullWidth ? 13 : 10, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.4).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .padding(.horizontal, fullWidth ? 20 : 12)
            .padding(.vertical, fullWidth ? 17 : 15)
            .frame(maxWidth: .infinity, alignment: fullWidth ? .leading : .center)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(isSelected ? accentGold : palette.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.25) : accentGold.opacity(0.18), lineWidth: isSelected ? 1 : 0.7)
            )
            .shadow(
                color: isSelected ? accentGold.opacity(0.32) : .black.opacity(0.05),
                radius: isSelected ? 11 : 5,
                y: isSelected ? 5 : 3
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(PressableButtonStyle())
    }
}
