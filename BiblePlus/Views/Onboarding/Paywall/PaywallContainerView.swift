import SwiftData
import SwiftUI

// MARK: - Paywall (Dark, two-card, Perplexity-inspired)
//
// Midnight palette. A centered serif hero + headline, a clean checkmark
// benefit list, and two side-by-side price cards pinned above the CTA:
// Weekly (3-day free trial) and Yearly (Best Value, showing the exact dollar
// savings). Yearly is pre-selected to steer plan mix toward the higher-LTV
// annual plan. Hard paywall in onboarding (no close); closable from Settings.
//
// Locked to the DARK palette so the paywall reads identically across system
// theme settings and conversion stays predictable.
struct PaywallContainerView: View {
    var onboardingViewModel: OnboardingViewModel? = nil
    var isOnboarding: Bool = true

    @Environment(StoreKitService.self) private var storeKitService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @Query private var profiles: [UserProfile]

    @State private var vm: PaywallViewModel?
    @State private var showContent = false
    @State private var shimmerPhase: CGFloat = 0   // sweeping light on the CTA

    private let palette = BPColorPalette.dark
    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)
    private let starGold = Color(red: 1.0, green: 0.84, blue: 0.3)

    init() {
        self.onboardingViewModel = nil
        self.isOnboarding = false
    }

    init(viewModel: OnboardingViewModel) {
        self.onboardingViewModel = viewModel
        self.isOnboarding = true
    }

    var body: some View {
        ZStack {
            backgroundLayers

            if let vm {
                scrollContent(vm: vm)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        bottomRegion(vm: vm)
                    }
            }

            // Top bar: Restore is always reachable (top-right). The close (X,
            // top-left) appears ONLY in the Settings presentation — the
            // onboarding paywall is hard, so there is no skip/close there.
            topBar
        }
        .environment(\.bpPalette, palette)
        .preferredColorScheme(.dark)
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
                "version": "dark_two_card",
            ])

            if storeKitService.subscriptions.isEmpty && !storeKitService.productsLoadError {
                Task { await storeKitService.loadProducts() }
            }

            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                showContent = true
            }
            // Continuous, gentle shimmer sweep on the CTA. The band is off-screen
            // at both ends, so the loop reset is invisible.
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
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

    // MARK: - Background

    private var backgroundLayers: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            // Soft gold halo behind the hero — quiet ambient light at the top.
            RadialGradient(
                colors: [accentGold.opacity(0.16), accentGold.opacity(0.0)],
                center: .init(x: 0.5, y: 0.08),
                startRadius: 0,
                endRadius: 280
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack {
            HStack {
                if !isOnboarding {
                    closeButton
                } else {
                    // Keep Restore right-aligned even with no close button.
                    Color.clear.frame(width: 32, height: 32)
                }
                Spacer()
                restoreButton
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            Spacer()
        }
    }

    private var closeButton: some View {
        Button {
            HapticService.lightImpact()
            Analytics.track(.paywallDismissed, properties: ["reason": "close"])
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.textSecondary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(palette.surfaceElevated))
        }
        .accessibilityLabel("Close")
    }

    private var restoreButton: some View {
        Button {
            Analytics.track(.paywallRestoreTapped)
            Task { await storeKitService.restorePurchases() }
        } label: {
            Text("Restore")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.textSecondary)
                .padding(.horizontal, 15)
                .padding(.vertical, 7)
                .background(Capsule().fill(palette.surfaceElevated))
        }
        .accessibilityLabel("Restore purchases")
    }

    // MARK: - Scroll Content

    private func scrollContent(vm: PaywallViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroLogo
                    .padding(.top, 52)

                eyebrow
                    .padding(.top, 16)

                headline
                    .padding(.top, 8)

                subtitle(vm: vm)
                    .padding(.top, 6)

                featureList
                    .padding(.top, 32)
                    .padding(.horizontal, 28)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 14)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 10)
        }
    }

    // MARK: - Hero (glowing Bible star)

    private var heroLogo: some View {
        HStack(spacing: 5) {
            Text("Bible")
                .font(.system(size: 34, weight: .light, design: .serif))
                .foregroundStyle(palette.textPrimary)

            Image(systemName: "sparkle")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(starGold)
                .shadow(color: starGold, radius: 6)
                .shadow(color: starGold.opacity(0.7), radius: 14)
                .shadow(color: starGold.opacity(0.4), radius: 26)
        }
        .frame(maxWidth: .infinity)
    }

    private var eyebrow: some View {
        HStack(spacing: 5) {
            Image(systemName: "sparkle")
                .font(.system(size: 8, weight: .semibold))
            Text("BIBLE PLUS PRO")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(2.2)
        }
        .foregroundStyle(accentGold)
        .frame(maxWidth: .infinity)
    }

    private var headline: some View {
        Text("Everything, unlocked.")
            .font(.custom("Baskerville-Bold", size: 30))
            .foregroundStyle(palette.textPrimary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func subtitle(vm: PaywallViewModel) -> some View {
        let name = vm.firstName.trimmingCharacters(in: .whitespaces)
        let text = name.isEmpty
            ? "Built around the way you believe."
            : "Built around the way you believe, \(name)."
        return Text(text)
            .font(.custom("Georgia-Italic", size: 14))
            .foregroundStyle(palette.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
    }

    // MARK: - Feature List (clean checkmarks)

    private let proFeatures: [String] = [
        "Unlimited AI companion \u{2014} ask anything, anytime",
        "All 29 guided reading plans",
        "Every Bible translation \u{2014} all 8",
        "Audio Bible in 9 lifelike voices",
        "1,500+ daily prayers, verses & devotionals",
        "Sanctuary soundscapes, widgets & more",
    ]

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(proFeatures, id: \.self) { feature in
                HStack(alignment: .center, spacing: 13) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(accentGold)
                        .frame(width: 18)

                    Text(feature)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - Bottom Region (price cards + CTA + footer, pinned)

    private func bottomRegion(vm: PaywallViewModel) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                priceCard(
                    vm: vm,
                    productID: StoreKitService.weeklyID,
                    title: "Weekly",
                    price: vm.weeklyPriceLabel(storeKitService),
                    sub: "3-day free trial",
                    subHighlighted: true,
                    badge: nil
                )
                priceCard(
                    vm: vm,
                    productID: StoreKitService.yearlyID,
                    title: "Yearly",
                    price: vm.yearlyPriceLabel(storeKitService),
                    sub: "\(vm.yearlyMonthlyEquivalent(storeKitService))/month",
                    subHighlighted: false,
                    badge: "SAVE \(vm.yearlySavingsAmount(storeKitService))"
                )
            }
            .padding(.top, 10) // room for the floating savings badge
            .padding(.horizontal, 20)

            ctaButton(vm: vm)
                .padding(.horizontal, 20)

            Text(ctaSubtitle(vm: vm))
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(palette.textMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 24)

            footerLinks
                .padding(.top, 1)
        }
        .padding(.top, 14)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [palette.background.opacity(0), palette.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 22)

                palette.background
            }
            .ignoresSafeArea(edges: .bottom)
        )
        .opacity(showContent ? 1 : 0)
    }

    // MARK: - Price Card

    private func priceCard(
        vm: PaywallViewModel,
        productID: String,
        title: String,
        price: String,
        sub: String,
        subHighlighted: Bool,
        badge: String?
    ) -> some View {
        let isSelected = vm.selectedProductID == productID
        return Button {
            vm.selectedProductID = productID
            HapticService.impact(.medium)
            Analytics.track(.paywallPriceCardSelected, properties: ["product": title.lowercased()])
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.custom("Georgia-Bold", size: 16))
                    .foregroundStyle(isSelected ? accentGold : palette.textPrimary)

                Text(price)
                    .font(.custom("Baskerville-Bold", size: 27))
                    .foregroundStyle(isSelected ? accentGold : palette.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(sub)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(subHighlighted ? accentGold : palette.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? accentGold.opacity(0.10) : palette.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                isSelected ? accentGold : palette.border,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .overlay(alignment: .top) {
                if let badge {
                    savingsBadge(badge)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: isSelected)
    }

    // Warm gold pill floating over the yearly card's top edge — "SAVE $209".
    private func savingsBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
            .tracking(0.4)
            .foregroundStyle(Color(red: 0.16, green: 0.11, blue: 0.04))
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accentGold.blend(with: .white, amount: 0.28), accentGold],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: accentGold.opacity(0.45), radius: 6, y: 2)
            )
            .offset(y: -10)
    }

    // MARK: - CTA

    private func ctaButton(vm: PaywallViewModel) -> some View {
        Button {
            HapticService.impact(.light)
            Analytics.track(.paywallCTATapped, properties: [
                "product": vm.selectedProductID ?? "unknown",
            ])
            Task { await vm.purchaseSelected(storeKitService: storeKitService, dismiss: dismiss) }
        } label: {
            Text(ctaTitle(vm: vm))
                .font(.custom("Georgia-Bold", size: 17))
                .tracking(0.3)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(ctaBackground())
                .shadow(color: accentGold.opacity(0.42), radius: 18, y: 7)
                .shadow(color: .black.opacity(0.30), radius: 6, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(vm.isPurchasing)
    }

    // Premium metallic gold CTA: champagne→bronze gradient, glossy top sheen,
    // a slow shimmer sweep, and a beveled rim — feels high-end on the dark bg.
    private func ctaBackground() -> some View {
        let deepGold = accentGold.blend(with: Color(red: 0.28, green: 0.18, blue: 0.06), amount: 0.34)
        return ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: accentGold.blend(with: .white, amount: 0.36), location: 0.0),
                            .init(color: accentGold, location: 0.52),
                            .init(color: deepGold, location: 1.0)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            // Glossy top sheen — light catching the top curve of the pill.
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.34), Color.white.opacity(0.0)],
                        startPoint: .top, endPoint: .center
                    )
                )

            // Soft, wide shimmer sweep travelling across the metal.
            GeometryReader { geo in
                let w = geo.size.width
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.30), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: w * 0.55)
                    .offset(x: -w * 0.6 + shimmerPhase * (w * 1.8))
            }
            .clipShape(Capsule())
            .allowsHitTesting(false)
        }
        .overlay(
            Capsule().stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.55), accentGold.opacity(0.25), Color.black.opacity(0.16)],
                    startPoint: .top, endPoint: .bottom
                ),
                lineWidth: 1
            )
        )
    }

    private func ctaTitle(vm: PaywallViewModel) -> String {
        if vm.isPurchasing { return "Processing..." }
        // Weekly is the only plan with a trial, so it's the only one that may
        // honestly say "Start Free Trial". Yearly is an immediate purchase.
        if vm.selectedProductID == StoreKitService.weeklyID {
            return "Start Free Trial"
        }
        return "Get Bible Plus Pro"
    }

    private func ctaSubtitle(vm: PaywallViewModel) -> String {
        if vm.selectedProductID == StoreKitService.weeklyID {
            return "Then \(vm.weeklyPriceLabel(storeKitService))/wk after 3 days · Cancel anytime"
        }
        return "Billed annually at \(vm.yearlyPriceLabel(storeKitService))/yr · Cancel anytime"
    }

    // MARK: - Footer

    private var footerLinks: some View {
        HStack(spacing: 14) {
            footerLink("Terms") {
                if let url = URL(string: "https://bibleplus.io/terms") { openURL(url) }
            }
            footerDot
            footerLink("Privacy") {
                if let url = URL(string: "https://bibleplus.io/privacy") { openURL(url) }
            }
        }
    }

    private func footerLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(palette.textMuted)
        }
    }

    private var footerDot: some View {
        Circle().fill(palette.border).frame(width: 2.5, height: 2.5)
    }
}
