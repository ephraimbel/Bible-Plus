import SwiftData
import SwiftUI

// MARK: - Paywall (Single Page)

struct PaywallContainerView: View {
    var onboardingViewModel: OnboardingViewModel? = nil
    var isOnboarding: Bool = true

    @Environment(StoreKitService.self) private var storeKitService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette

    @Query private var profiles: [UserProfile]

    @State private var vm: PaywallViewModel?
    @State private var showCTA = false

    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)

    /// Standalone initializer (from settings, pro gates, etc.)
    init() {
        self.onboardingViewModel = nil
        self.isOnboarding = false
    }

    /// Onboarding initializer
    init(viewModel: OnboardingViewModel) {
        self.onboardingViewModel = viewModel
        self.isOnboarding = true
    }

    var body: some View {
        ZStack {
            // Warm blurred biblical art background — consistent everywhere
            Image("biblical_jacob_ladder")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 30)
                .scaleEffect(1.15)
                .clipped()
                .ignoresSafeArea()

            palette.background.opacity(0.75)
                .ignoresSafeArea()

            // Gold glow at top
            RadialGradient(
                colors: [accentGold.opacity(0.10), Color.clear],
                center: .init(x: 0.5, y: 0.08),
                startRadius: 0,
                endRadius: 350
            )
            .ignoresSafeArea()

            if let vm {
                VStack(spacing: 0) {
                    topBar(vm: vm)
                    PaywallPage3View(vm: vm)
                    stickyCTA(vm: vm)
                }
            }
        }
        .onAppear {
            if vm == nil {
                if let onboardingViewModel {
                    vm = PaywallViewModel(viewModel: onboardingViewModel)
                } else {
                    vm = PaywallViewModel(profile: profiles.first)
                }
            }
            Analytics.track(.paywallViewed, properties: [
                "source": isOnboarding ? "onboarding" : "settings",
                "version": "single_page",
            ])

            if storeKitService.subscriptions.isEmpty && !storeKitService.productsLoadError {
                Task { await storeKitService.loadProducts() }
            }

            withAnimation(Animation.spring(response: 0.5, dampingFraction: 0.8).delay(0.3)) {
                showCTA = true
            }
        }
        .alert("Purchase Failed", isPresented: Binding(
            get: { vm?.purchaseError != nil },
            set: { if !$0 { vm?.purchaseError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm?.purchaseError ?? "")
        }
    }

    // MARK: - Top Bar

    private func topBar(vm: PaywallViewModel) -> some View {
        HStack {
            Spacer()
            Button {
                vm.dismissPaywall(dismiss: dismiss)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: isOnboarding ? 4 : 14, weight: .medium))
                    .foregroundStyle(isOnboarding ? .clear : palette.textMuted)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isOnboarding ? Color.clear : palette.surfaceElevated)
                    )
                    .opacity(isOnboarding ? 0.01 : 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    // MARK: - Sticky CTA

    private func stickyCTA(vm: PaywallViewModel) -> some View {
        VStack(spacing: 8) {
            Button {
                HapticService.impact(.light)
                Task { await vm.purchaseSelected(storeKitService: storeKitService, dismiss: dismiss) }
            } label: {
                Text(ctaTitle(vm: vm))
                    .font(.custom("Georgia-Bold", size: 17))
                    .tracking(0.3)
                    .foregroundStyle(palette.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        Capsule().fill(.ultraThinMaterial.opacity(0.6))
                    )
                    .background(
                        Capsule().fill(accentGold.opacity(0.12))
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [accentGold.opacity(0.5), palette.border.opacity(0.2), accentGold.opacity(0.5)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: accentGold.opacity(0.2), radius: 10, y: 4)
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(vm.isPurchasing)
            .padding(.horizontal, 32)

            Text(ctaSubtitle(vm: vm))
                .font(.custom("Georgia", size: 11))
                .foregroundStyle(palette.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                vm.dismissPaywall(dismiss: dismiss)
            } label: {
                Text("Maybe Later")
                    .font(.custom("Georgia", size: 11))
                    .foregroundStyle(palette.textMuted.opacity(0.4))
            }
            .padding(.top, 2)
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
        .opacity(showCTA ? 1 : 0)
        .offset(y: showCTA ? 0 : 20)
    }

    // MARK: - CTA Titles

    private func ctaTitle(vm: PaywallViewModel) -> String {
        if vm.isPurchasing { return "Processing..." }
        if vm.selectedProductID == StoreKitService.yearlyID {
            return "Start 3-Day Free Trial"
        }
        return "Subscribe Now"
    }

    private func ctaSubtitle(vm: PaywallViewModel) -> String {
        if vm.selectedProductID == StoreKitService.yearlyID {
            return "3 days free, then \(vm.yearlyPriceLabel(storeKitService)) per year. Cancel anytime."
        }
        return "\(vm.weeklyPriceLabel(storeKitService)) billed weekly. Cancel anytime."
    }
}
