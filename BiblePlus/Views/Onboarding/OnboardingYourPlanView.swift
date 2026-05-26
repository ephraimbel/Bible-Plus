import SwiftUI
import SwiftData

// MARK: - Your Plan (Reveal Act)
//
// The tangible "we built you a plan" payoff — a reading plan auto-chosen from
// the user's burden, presented on a matched biblical painting. Earn-it: a
// concrete thing they'd lose by not continuing. Warm Paper / light.
struct OnboardingYourPlanView: View {
    @Bindable var viewModel: OnboardingViewModel
    var onContinue: () -> Void = {}

    @Environment(\.bpPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false

    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)

    private var name: String {
        let n = viewModel.firstName.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "" : n
    }

    private struct Plan {
        let title: String
        let days: Int
        let blurb: String
        let art: String
    }

    private var plan: Plan {
        switch viewModel.selectedBurdens.first {
        case .anxiety: return Plan(title: "Peace That Surpasses", days: 14, blurb: "Quiet an anxious heart, one day at a time.", art: "biblical_jesus_calms_storm")
        case .grief: return Plan(title: "Comfort in the Valley", days: 10, blurb: "God's nearness through loss.", art: "biblical_bethany_mary_martha")
        case .doubt: return Plan(title: "Honest Faith", days: 12, blurb: "For the questions you've been afraid to ask.", art: "biblical_baptism_jesus")
        case .loneliness: return Plan(title: "Never Alone", days: 10, blurb: "His presence in the empty spaces.", art: "biblical_elijah_ravens")
        case .anger: return Plan(title: "A Gentle Spirit", days: 10, blurb: "Trading frustration for peace.", art: "biblical_sermon_mount")
        case .temptation: return Plan(title: "Strength to Stand", days: 14, blurb: "Renewed resolve, every morning.", art: "biblical_brazen_serpent")
        case .health: return Plan(title: "Healing & Hope", days: 10, blurb: "Hope and peace through every season.", art: "biblical_loaves_fishes")
        case .financial: return Plan(title: "Trusting His Provision", days: 10, blurb: "Peace about what lies ahead.", art: "biblical_loaves_fishes")
        case .relationship: return Plan(title: "Love That Lasts", days: 14, blurb: "Patience, grace, and lasting love.", art: "biblical_jacob_rachel_well")
        case .purpose: return Plan(title: "Finding Your Why", days: 14, blurb: "Clarity and direction for your path.", art: "biblical_jacob_ladder")
        default: return Plan(title: "Foundations of Faith", days: 21, blurb: "A gentle daily rhythm to begin.", art: "biblical_sermon_mount")
        }
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer(minLength: 10)

                VStack(spacing: 8) {
                    Text("YOUR FIRST PLAN")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .tracking(2.4)
                        .foregroundStyle(accentGold)
                    Text(name.isEmpty ? "We picked this for you." : "We picked this for you, \(name).")
                        .font(.custom("Baskerville-Bold", size: 26))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.textPrimary)
                        .padding(.horizontal, 24)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

                planCard
                    .padding(.horizontal, 26)
                    .padding(.top, 26)
                    .scaleEffect(appeared ? 1 : 0.96)
                    .opacity(appeared ? 1 : 0)

                Text("Chosen from what you shared — ready on day one.")
                    .font(.custom("Georgia-Italic", size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)
                    .padding(.top, 18)
                    .opacity(appeared ? 1 : 0)

                Spacer(minLength: 12)

                GoldButton(title: "Continue", showGlow: true) { onContinue() }
                    .padding(.horizontal, 30)
                    .opacity(appeared ? 1 : 0)
            }
            .padding(.vertical, 16)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.9)) {
                appeared = true
            }
        }
    }

    // MARK: - Plan card

    private var planCard: some View {
        ZStack(alignment: .bottomLeading) {
            // Painting base (bounded so it can't over-widen the layout)
            Color.black
                .overlay { Image(plan.art).resizable().aspectRatio(contentMode: .fill) }
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.15), location: 0.0),
                            .init(color: .black.opacity(0.35), location: 0.45),
                            .init(color: .black.opacity(0.82), location: 1.0)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 5) {
                    Image(systemName: "book.pages.fill")
                    Text("READING PLAN").tracking(1.6)
                }
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))

                Text(plan.title)
                    .font(.custom("Baskerville-Bold", size: 27))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

                Text(plan.blurb)
                    .font(.custom("Georgia-Italic", size: 14.5))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 1)

                HStack(spacing: 7) {
                    Image(systemName: "calendar")
                    Text("\(plan.days)-day journey · 5 min a day")
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
    }

    private var background: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            RadialGradient(colors: [accentGold.opacity(0.12), .clear], center: .init(x: 0.5, y: 0.42), startRadius: 0, endRadius: 340)
                .ignoresSafeArea()
        }
    }
}

#Preview("Your Plan") {
    OnboardingYourPlanView(viewModel: OnboardingViewModel(
        modelContext: try! ModelContainer(for: UserProfile.self, configurations: .init(isStoredInMemoryOnly: true)).mainContext,
        storeKitService: StoreKitService()
    ))
    .environment(\.bpPalette, .light)
}
