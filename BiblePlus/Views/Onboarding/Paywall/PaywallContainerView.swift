import SwiftData
import SwiftUI

// MARK: - Paywall (Dark, two-card, Perplexity-inspired)
//
// Midnight palette. A centered serif hero + headline, a clean checkmark
// benefit list, and two side-by-side price cards pinned above the CTA:
// Monthly and Yearly (Best Value, 7-day free trial, showing the exact dollar
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

            // Close (X, top-right) appears ONLY in the in-app / Settings
            // presentation so a free user can leave. The onboarding paywall is
            // hard — no close — the only way forward is choosing a plan.
            if !isOnboarding {
                topBar
            }
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
                // Onboarding leads with Yearly (the free-trial / funnel plan).
                // The in-app paywall only offers Monthly (no trial), so it must
                // select Monthly so the CTA reads correctly.
                vm?.selectedProductID = isOnboarding ? StoreKitService.yearlyID : StoreKitService.monthlyID
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
                Spacer()
                closeButton
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

    // MARK: - Content
    //
    // Perplexity-style anchored layout: the header + feature list sit at the
    // TOP (scrolling content) and the plan cards + CTA + footer are pinned to
    // the BOTTOM. The leftover height on taller phones falls as a single gap
    // between the features and the cards — no top/bottom void; the design is
    // identical on every iPhone, it just breathes a little more on larger ones.
    // Scrolls on small phones (SE) and at large Dynamic Type sizes.
    private func scrollContent(vm: PaywallViewModel) -> some View {
        GeometryReader { proxy in
            // Scale the header + feature spacing with the available height so the
            // top section fills proportionally on taller phones — keeping the gap
            // above the pinned cards a consistent *fraction* of the screen rather
            // than growing 1:1. Clamped to the iPhone-16 baseline at the low end
            // so small phones (SE) keep their compact spacing and simply scroll.
            let scale = min(max(proxy.size.height / 520, 0.8), 1.5)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroLogo
                        .padding(.top, 44 * scale)

                    eyebrow
                        .padding(.top, 16 * scale)

                    headline
                        .padding(.top, 8 * scale)

                    subtitle(vm: vm)
                        .padding(.top, 6)

                    featureList(rowSpacing: 24 * scale)
                        .padding(.top, 42 * scale)
                        .padding(.horizontal, 28)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 10)
            }
        }
    }

    private func bottomRegion(vm: PaywallViewModel) -> some View {
        VStack(spacing: 14) {
            planCards(vm: vm)
                .padding(.top, 10) // room for the floating badges
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
            // Short fade into an opaque base so the scrolling features dissolve
            // cleanly behind the pinned region instead of bleeding through.
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [palette.background.opacity(0), palette.background],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 22)
                palette.background
            }
            .ignoresSafeArea(edges: .bottom)
        )
        .opacity(showContent ? 1 : 0)
    }

    // Onboarding shows BOTH plans (Monthly + Yearly "best value") to steer a
    // warm new user toward the higher-LTV annual plan with the free trial. The
    // in-app paywall (hit from Settings / a locked feature) shows ONLY the
    // monthly plan — a single, low-friction offer to unlock a feature.
    private func planCards(vm: PaywallViewModel) -> some View {
        HStack(spacing: 12) {
            priceCard(
                vm: vm,
                productID: StoreKitService.monthlyID,
                title: "Monthly",
                price: vm.monthlyPriceLabel(storeKitService),
                sub: "per month",
                badge: nil
            )
            if isOnboarding {
                priceCard(
                    vm: vm,
                    productID: StoreKitService.yearlyID,
                    title: "Yearly",
                    price: vm.yearlyPriceLabel(storeKitService),
                    sub: "\(vm.yearlyMonthlyBreakdown(storeKitService))/month",
                    badge: "7-DAY FREE TRIAL"
                )
            }
        }
    }

    // Whether the plan cards are laid out as a single centered card (in-app,
    // monthly-only) vs. two left-aligned cards side by side (onboarding).
    private var isSinglePlan: Bool { !isOnboarding }

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

    private func featureList(rowSpacing: CGFloat) -> some View {
        // Uniform spacing between rows (scaled per device) — organized and
        // consistent everywhere; the leftover height becomes one gap below the
        // list, not gaps between each feature.
        VStack(alignment: .leading, spacing: rowSpacing) {
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

    // MARK: - Price Card

    private func priceCard(
        vm: PaywallViewModel,
        productID: String,
        title: String,
        price: String,
        sub: String,
        badge: String?
    ) -> some View {
        let isSelected = vm.selectedProductID == productID
        return Button {
            vm.selectedProductID = productID
            HapticService.impact(.medium)
            Analytics.track(.paywallPriceCardSelected, properties: ["product": title.lowercased()])
        } label: {
            Group {
                if isSinglePlan {
                    // One full-width card → a horizontal row so the content
                    // fills the button: name on the left, price on the right.
                    // The centered stack used for the two-column layout looks
                    // small and lost when stretched edge-to-edge.
                    HStack(alignment: .center, spacing: 12) {
                        Text(title)
                            .font(.custom("Georgia-Bold", size: 23))
                            .foregroundStyle(isSelected ? accentGold : palette.textPrimary)

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(price)
                                .font(.custom("Baskerville-Bold", size: 31))
                                .foregroundStyle(isSelected ? accentGold : palette.textPrimary)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Text(sub)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(palette.textMuted)
                        }
                    }
                } else {
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
                            .foregroundStyle(palette.textMuted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, isSinglePlan ? 22 : 16)
            .padding(.vertical, isSinglePlan ? 22 : 17)
            .background(cardBackground(isSelected: isSelected))
            .overlay(alignment: .top) {
                if let badge {
                    planBadge(badge)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }

    // Subtle, elegant card surface: an elevated base, a soft gold gradient
    // overlay when selected (the "subtle overlay"), and a hairline border that
    // warms to gold on selection.
    private func cardBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(palette.surfaceElevated)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accentGold.opacity(0.16), accentGold.opacity(0.05)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? accentGold : palette.border, lineWidth: isSelected ? 1.5 : 1)
            )
    }

    // Floating gold pill over a card's top edge — "7-DAY FREE TRIAL" / "SAVE $44".
    private func planBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .tracking(0.4)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(Color(red: 0.16, green: 0.11, blue: 0.04))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accentGold.blend(with: .white, amount: 0.28), accentGold],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.28), radius: 4, y: 2)
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
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .tracking(0.2)
                .foregroundStyle(Color(red: 0.16, green: 0.11, blue: 0.04))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(ctaBackground())
                .shadow(color: accentGold.opacity(0.25), radius: 12, y: 5)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(vm.isPurchasing)
    }

    // Clean, elegant gold CTA: a soft champagne→gold gradient with a single
    // hairline top rim for a touch of dimension. No shimmer — calm and premium.
    private func ctaBackground() -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [accentGold.blend(with: .white, amount: 0.14), accentGold],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5)
            )
    }

    private func ctaTitle(vm: PaywallViewModel) -> String {
        if vm.isPurchasing { return "Processing..." }
        // Yearly is now the only plan with a free trial, so it's the only one
        // that may honestly say "Start Free Trial". Monthly is an immediate
        // (no-trial) purchase.
        if vm.selectedProductID == StoreKitService.yearlyID {
            return "Start Free Trial"
        }
        return "Subscribe Now"
    }

    private func ctaSubtitle(vm: PaywallViewModel) -> String {
        if vm.selectedProductID == StoreKitService.yearlyID {
            return "Then \(vm.yearlyPriceLabel(storeKitService))/yr after 7 days · Cancel anytime"
        }
        return "\(vm.monthlyPriceLabel(storeKitService))/mo · Cancel anytime"
    }

    // MARK: - Footer

    private var footerLinks: some View {
        HStack(spacing: 14) {
            footerLink("Restore") {
                Analytics.track(.paywallRestoreTapped)
                Task { await storeKitService.restorePurchases() }
            }
            footerDot
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
