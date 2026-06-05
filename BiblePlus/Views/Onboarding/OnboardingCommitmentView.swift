import SwiftUI
import SwiftData

// MARK: - Commitment Pledge (Pre-Paywall Moment)
//
// A single micro-commitment right before the paywall: the user taps "I'm
// ready," making an active promise to show up. A committed user converts far
// better than a passive one — this is the psychological hinge between the
// reveal and the offer. Warm Paper / light, fully animated.
struct OnboardingCommitmentView: View {
    @Bindable var viewModel: OnboardingViewModel
    var onContinue: () -> Void = {}

    @Environment(\.bpPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false
    @State private var sealPulse = false

    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)

    private var name: String {
        let n = viewModel.firstName.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "" : n
    }

    private var minutes: String {
        viewModel.selectedTimeCommitment?.minutesLabel ?? "5"
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer(minLength: 20)

                // Seal / emblem
                ZStack {
                    Circle()
                        .fill(accentGold.opacity(0.10))
                        .frame(width: 116, height: 116)
                        .scaleEffect(sealPulse ? 1.06 : 0.96)
                    Circle()
                        .stroke(accentGold.opacity(0.4), lineWidth: 1)
                        .frame(width: 116, height: 116)
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(accentGold)
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.85)

                VStack(spacing: 14) {
                    Text("YOUR COMMITMENT")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .tracking(2.6)
                        .foregroundStyle(accentGold)

                    Text(name.isEmpty ? "Will you show up?" : "Will you show up, \(name)?")
                        .font(.custom("Baskerville-Bold", size: 30))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Just \(minutes) minutes a day. Show up, and we'll walk the rest with you — verse by verse, day by day.")
                        .font(.custom("Georgia-Italic", size: 16))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.textSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 30)
                }
                .padding(.top, 30)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)

                Spacer(minLength: 20)

                VStack(spacing: 6) {
                    GoldButton(title: "I'm ready", showGlow: true) {
                        HapticService.consecrate()
                        onContinue()
                    }
                    Text("A promise to yourself.")
                        .font(.custom("Georgia-Italic", size: 13))
                        .foregroundStyle(palette.textSecondary.opacity(0.8))
                        .padding(.top, 4)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 18)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
            }
            .padding(.vertical, 24)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.86)) {
                appeared = true
            }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                sealPulse = true
            }
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

#Preview("Commitment") {
    OnboardingCommitmentView(viewModel: OnboardingViewModel(
        modelContext: try! ModelContainer(for: UserProfile.self, configurations: .init(isStoredInMemoryOnly: true)).mainContext,
        storeKitService: StoreKitService()
    ))
    .environment(\.bpPalette, .light)
}
