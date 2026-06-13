import SwiftUI

// MARK: - Review Prompt
//
// The custom "Enjoying Bible Plus?" card shown at a high-delight moment (e.g.
// after the first AI chat). Editorial / premium to match the rest of the app:
// a row of gold stars that settles in with a soft stagger, a serif headline,
// a gold gradient CTA, and a quiet decline. Tapping "Rate" hands off to the
// native App Store sheet.
struct ReviewPromptView: View {
    @Environment(\.bpPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onYes: () -> Void
    let onNotYet: () -> Void

    @State private var appeared = false

    private let gold = Color(red: 0.79, green: 0.66, blue: 0.43)
    private let goldLight = Color(red: 1.0, green: 0.88, blue: 0.5)

    var body: some View {
        VStack(spacing: BPSpacing.lg) {
            starRow

            VStack(spacing: BPSpacing.xs) {
                Text("Enjoying Bible Plus?")
                    .font(.custom("Baskerville-Bold", size: 24))
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Your rating helps others find\nGod's Word through this app.")
                    .font(.custom("Georgia-Italic", size: 15))
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: BPSpacing.sm) {
                Button(action: onYes) {
                    Text("Rate Bible Plus")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .tracking(0.2)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BPSpacing.md)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [gold, gold.opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: gold.opacity(0.35), radius: 12, y: 5)
                        )
                        .overlay(Capsule().strokeBorder(goldLight.opacity(0.45), lineWidth: 0.5))
                }
                .buttonStyle(.plain)

                Button(action: onNotYet) {
                    Text("Maybe later")
                        .font(.custom("Georgia", size: 14))
                        .foregroundStyle(palette.textSecondary.opacity(0.85))
                        .padding(.vertical, BPSpacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(BPSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: BPRadius.xl, style: .continuous)
                .fill(palette.surfaceElevated)
                .overlay(
                    // A soft gold bloom behind the stars so the top of the card
                    // feels lit, not flat.
                    RadialGradient(
                        colors: [gold.opacity(0.12), .clear],
                        center: .init(x: 0.5, y: 0.10),
                        startRadius: 0,
                        endRadius: 190
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: BPRadius.xl, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: BPRadius.xl, style: .continuous)
                .strokeBorder(gold.opacity(0.22), lineWidth: 0.7)
        )
        .shadow(color: .black.opacity(0.22), radius: 28, y: 14)
        .padding(.horizontal, BPSpacing.xxl)
        .onAppear {
            if reduceMotion { appeared = true }
            else { withAnimation { appeared = true } }
        }
    }

    // Five gold stars, each settling in with a soft staggered pop.
    private var starRow: some View {
        HStack(spacing: BPSpacing.xs) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: "star.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        LinearGradient(colors: [goldLight, gold], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: gold.opacity(0.35), radius: 5, y: 2)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        reduceMotion ? nil
                        : .spring(response: 0.5, dampingFraction: 0.6).delay(0.06 + Double(i) * 0.07),
                        value: appeared
                    )
            }
        }
    }
}
