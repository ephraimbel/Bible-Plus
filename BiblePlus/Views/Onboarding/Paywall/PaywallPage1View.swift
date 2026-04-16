import SwiftUI

// MARK: - Page 1: Personalized Benefits ("Built for You")

struct PaywallPage1View: View {
    @Bindable var vm: PaywallViewModel
    private let palette = BPColorPalette.dark

    // Staggered entrance
    @State private var showHeadline = false
    @State private var showSubtitle = false
    @State private var showBenefits = false
    @State private var showVerse = false
    @State private var hasAnimated = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {

                // MARK: - Eyebrow Label
                // A small, tracked, all-caps wordmark replaces the round
                // sparkle medallion. It reads like a chapter heading in a
                // well-set Bible — quiet, premium, unmistakably editorial.
                (Text("BIBLE\u{2009}") + Text(Image(systemName: "sparkle")) + Text("\u{2009}PRO"))
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .tracking(4.5)
                    .foregroundStyle(palette.accent.opacity(0.75))
                    .padding(.top, 36)
                    .opacity(showHeadline ? 1 : 0)

                // Hairline ornament under the eyebrow — a single thin gold
                // rule with a tiny diamond, like a missal divider.
                topOrnament
                    .padding(.top, 14)
                    .opacity(showHeadline ? 1 : 0)

                // MARK: - Personalized Headline
                // Larger, lighter serif. A bold serif at this size feels
                // chunky; a regular weight reads like book typography.
                Text(vm.personalizedHeadline)
                    .font(.custom("NewYorkLarge-Regular", size: 34, relativeTo: .largeTitle))
                    .lineSpacing(2)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .padding(.top, 22)
                    .opacity(showHeadline ? 1 : 0)
                    .offset(y: showHeadline ? 0 : 16)

                // MARK: - Subtitle
                // Italic serif in a softer tone — feels like an editor's
                // standfirst, not a marketing tagline.
                Text(vm.personalizedSubtitle)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(palette.textSecondary.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 44)
                    .padding(.top, 10)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 10)

                // MARK: - Benefit Rows
                // Pure typographic list. No icon medallions, no rounded
                // chips — just elegant serif titles with body copy and a
                // hairline divider between rows.
                VStack(spacing: 0) {
                    ForEach(Array(vm.benefits.enumerated()), id: \.element.id) { index, benefit in
                        benefitRow(benefit, index: index)
                        if index < vm.benefits.count - 1 {
                            Rectangle()
                                .fill(palette.border.opacity(0.35))
                                .frame(height: 0.5)
                                .padding(.leading, 22)
                                .opacity(showBenefits ? 1 : 0)
                        }
                    }
                }
                .padding(.top, 36)
                .padding(.horizontal, 32)

                // MARK: - Inspirational Verse
                VStack(spacing: 10) {
                    ornamentalDivider

                    Text("\u{201C}I can do all things through Christ who strengthens me.\u{201D}")
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)

                    Text("Philippians 4:13")
                        .font(.system(size: 11, weight: .regular, design: .serif))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundStyle(palette.textMuted.opacity(0.7))
                }
                .padding(.top, 40)
                .padding(.horizontal, 44)
                .opacity(showVerse ? 1 : 0)

                Spacer(minLength: 16)
            }
        }
        .onAppear {
            guard !hasAnimated else { return }
            hasAnimated = true
            triggerEntranceAnimations()
        }
    }

    // MARK: - Benefit Row

    private func benefitRow(_ benefit: PaywallBenefit, index: Int) -> some View {
        // Gold roman numeral as marker — feels like a chapter index in a
        // study Bible. Numerals replace SF Symbol icons entirely.
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            Text(Self.romanNumeral(index + 1))
                .font(.system(size: 13, weight: .regular, design: .serif))
                .tracking(1.5)
                .foregroundStyle(palette.accent.opacity(0.85))
                .frame(width: 22, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text(benefit.title)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(benefit.subtitle)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(palette.textSecondary.opacity(0.78))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 18)
        .opacity(showBenefits ? 1 : 0)
        .offset(y: showBenefits ? 0 : 12)
        .animation(
            BPAnimation.spring.delay(Double(index) * 0.1),
            value: showBenefits
        )
    }

    /// Convert 1...4 into Roman numerals for benefit row markers. Bounded
    /// (1...8) so a future fifth/sixth benefit still renders correctly; we
    /// fall back to the arabic value above 8 just in case.
    private static func romanNumeral(_ n: Int) -> String {
        switch n {
        case 1: return "I"
        case 2: return "II"
        case 3: return "III"
        case 4: return "IV"
        case 5: return "V"
        case 6: return "VI"
        case 7: return "VII"
        case 8: return "VIII"
        default: return "\(n)"
        }
    }

    // MARK: - Top Ornament
    //
    // A pair of thin gold hairlines flanking a tiny diamond glyph. Replaces
    // the round sparkle medallion with something that reads as illuminated-
    // manuscript heritage rather than App Store stock art.

    private var topOrnament: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [palette.accent.opacity(0), palette.accent.opacity(0.55)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 56, height: 0.5)

            Image(systemName: "diamond.fill")
                .font(.system(size: 5))
                .foregroundStyle(palette.accent.opacity(0.85))

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [palette.accent.opacity(0.55), palette.accent.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 56, height: 0.5)
        }
    }

    // MARK: - Ornamental Divider

    private var ornamentalDivider: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [palette.accent.opacity(0), palette.accent.opacity(0.45)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 48, height: 0.5)
            Image(systemName: "diamond.fill")
                .font(.system(size: 4))
                .foregroundStyle(palette.accent.opacity(0.7))
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [palette.accent.opacity(0.45), palette.accent.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 48, height: 0.5)
        }
    }

    // MARK: - Entrance Animations

    private func triggerEntranceAnimations() {
        let spring = Animation.spring(response: 0.6, dampingFraction: 0.82)
        withAnimation(spring.delay(0.15)) { showHeadline = true }
        withAnimation(spring.delay(0.35)) { showSubtitle = true }
        withAnimation(spring.delay(0.55)) { showBenefits = true }
        withAnimation(spring.delay(0.85)) { showVerse = true }
    }
}
