import SwiftData
import SwiftUI

// MARK: - Paywall (Clean, centered, high-end)
//
// Editorial single-column layout modelled on the NurseMind Pro paywall:
// a glowing brand hero centered at the top, a tight value headline, a
// left-aligned benefit list (no dense comparison matrix), two radio plan
// cards, and a full-width CTA. Content scrolls; the CTA + footer stay
// pinned to the bottom safe area so the action is always reachable.
//
// Locked to the LIGHT palette so the paywall reads identically across
// system theme settings and conversion stays predictable.
struct PaywallContainerView: View {
    var onboardingViewModel: OnboardingViewModel? = nil
    var isOnboarding: Bool = true

    @Environment(StoreKitService.self) private var storeKitService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var profiles: [UserProfile]

    @State private var vm: PaywallViewModel?
    @State private var showContent = false
    @State private var shimmerPhase: CGFloat = 0   // sweeping light on the trial CTA

    private let palette = BPColorPalette.light
    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)
    private let saveGreen = Color(red: 0.20, green: 0.58, blue: 0.25)
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
                        ctaRegion(vm: vm)
                    }
            }

            // Hard paywall: during onboarding there is no skip/close — the only
            // ways forward are the 3-day weekly trial or the yearly plan. The
            // close button is kept ONLY for the Settings presentation (where the
            // paywall is a dismissable sheet and must be closable).
            if !isOnboarding {
                VStack {
                    HStack {
                        Spacer()
                        closeButton
                            .padding(.trailing, 18)
                            .padding(.top, 8)
                    }
                    Spacer()
                }
            }
        }
        .environment(\.bpPalette, palette)
        .preferredColorScheme(.light)
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
                "version": "clean_centered",
            ])

            if storeKitService.subscriptions.isEmpty && !storeKitService.productsLoadError {
                Task { await storeKitService.loadProducts() }
            }

            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                showContent = true
            }
            // Continuous, gentle shimmer sweep used by the trial CTA. The band
            // is off-screen at both ends, so the loop reset is invisible.
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

            // Soft gold halo behind the hero star — gives the "glowing
            // star centered at the top" its quiet ambient light.
            RadialGradient(
                colors: [accentGold.opacity(0.14), accentGold.opacity(0.0)],
                center: .init(x: 0.5, y: 0.10),
                startRadius: 0,
                endRadius: 240
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Close Button

    // Only shown when !isOnboarding (Settings), so it simply dismisses. The
    // onboarding paywall is hard — no close.
    private var closeButton: some View {
        Button {
            HapticService.lightImpact()
            Analytics.track(.paywallDismissed, properties: ["reason": "close"])
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.textMuted)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(palette.surfaceElevated)
                        .overlay(Circle().stroke(palette.border, lineWidth: 0.5))
                )
        }
        .accessibilityLabel("Close")
    }

    // MARK: - Scroll Content

    private func scrollContent(vm: PaywallViewModel) -> some View {
        // GeometryReader + minHeight lets the content vertically CENTER when
        // it fits the viewport (large phones) and SCROLL when it doesn't
        // (small phones / Dynamic Type) — so it adapts cleanly to every size
        // instead of stranding the content at the top with a gap above the CTA.
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroLogo
                        .padding(.top, 10)

                    eyebrow
                        .padding(.top, 14)

                    headline
                        .padding(.top, 8)

                    subtitle(vm: vm)
                        .padding(.top, 6)

                    // The feature list absorbs the leftover height by spreading
                    // its rows, so the page fills evenly — no stranded gap at
                    // the top, between sections, or under the plan cards.
                    featureList(vm: vm)
                        .padding(.top, 28)
                        .padding(.horizontal, 26)
                        .frame(maxHeight: .infinity)

                    planSection(vm: vm)
                        .padding(.top, 24)
                        .padding(.horizontal, 22)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 10)
            }
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
            .font(.custom("Baskerville-Bold", size: 28))
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

    // MARK: - Feature List

    // Loss-framed feature list: each row pairs the Pro abundance with the
    // free cap (lock + "Free: only X"). Seeing the ceiling they're stuck
    // under on Free creates real missing-out pressure — stronger than a
    // plain benefit list. Numbers mirror the actual Free/Pro entitlements.
    private struct ProFeature: Identifiable {
        var id: String { title }
        let icon: String
        let title: String
        let freeLimit: String
    }

    private let proFeatures: [ProFeature] = [
        ProFeature(icon: "infinity", title: "Unlimited AI companion", freeLimit: "Free stops after 5 messages, ever"),
        ProFeature(icon: "calendar", title: "All 29 guided reading plans", freeLimit: "Free unlocks just 1"),
        ProFeature(icon: "book.closed.fill", title: "Every Bible translation \u{2014} all 8", freeLimit: "Free gives you only 2"),
        ProFeature(icon: "headphones", title: "Audio Bible in 9 voices", freeLimit: "Free gives you just 1"),
    ]

    private func featureList(vm: PaywallViewModel) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(proFeatures.enumerated()), id: \.element.id) { index, feature in
                if index > 0 {
                    Spacer(minLength: 18)
                }
                featureRow(feature)
            }
        }
    }

    private func featureRow(_ feature: ProFeature) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: feature.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(accentGold)
                .frame(width: 26, height: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.custom("Georgia-Bold", size: 16))
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 5) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(palette.textMuted.opacity(0.6))
                    Text(feature.freeLimit)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Plan Section

    private func planSection(vm: PaywallViewModel) -> some View {
        VStack(spacing: 11) {
            HStack {
                Text("CHOOSE YOUR PLAN")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(palette.textMuted)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)

            weeklyPlanCard(vm: vm)
                .padding(.top, 7) // room for the floating trial badge
            yearlyPlanCard(vm: vm)
        }
    }

    // The featured option: taller, gold-emphasized, and topped with a floating
    // "3-DAY FREE TRIAL" badge so the trial is the first thing the eye lands on.
    private func weeklyPlanCard(vm: PaywallViewModel) -> some View {
        let isSelected = vm.selectedProductID == StoreKitService.weeklyID
        return Button {
            vm.selectedProductID = StoreKitService.weeklyID
            HapticService.impact(.medium)
            Analytics.track(.paywallPriceCardSelected, properties: ["product": "weekly"])
        } label: {
            HStack(spacing: 13) {
                selectionRadio(isSelected: isSelected)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly")
                        .font(.custom("Georgia-Bold", size: 18))
                        .foregroundStyle(palette.textPrimary)

                    Text("Free for 3 days, then billed weekly")
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                Text("\(vm.weeklyPriceLabel(storeKitService))/wk")
                    .font(.custom("Georgia-Bold", size: 14))
                    .foregroundStyle(palette.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .background(planCardBackground(isSelected: isSelected, dominant: true))
            .overlay(alignment: .top) {
                Text("✦  3-DAY FREE TRIAL")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(accentGold)
                            .shadow(color: accentGold.opacity(0.45), radius: 7, y: 2)
                    )
                    .offset(y: -11)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: isSelected)
    }

    // The value option: no trial, plain card. Keeps the SAVE % pill and a
    // per-week reframe so committing yearly still reads as the rational deal.
    private func yearlyPlanCard(vm: PaywallViewModel) -> some View {
        let isSelected = vm.selectedProductID == StoreKitService.yearlyID
        return Button {
            vm.selectedProductID = StoreKitService.yearlyID
            HapticService.impact(.medium)
            Analytics.track(.paywallPriceCardSelected, properties: ["product": "yearly"])
        } label: {
            HStack(spacing: 13) {
                selectionRadio(isSelected: isSelected)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Yearly")
                            .font(.custom("Georgia-Bold", size: 17))
                            .foregroundStyle(palette.textPrimary)

                        Text("SAVE \(vm.savingsPercent(storeKitService))%")
                            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                            .tracking(0.5)
                            .foregroundStyle(saveGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Capsule().fill(saveGreen.opacity(0.15)))
                    }

                    Text("Just \(vm.yearlyWeeklyBreakdown(storeKitService))/week · billed yearly")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                Text("\(vm.yearlyPriceLabel(storeKitService))/yr")
                    .font(.custom("Georgia-Bold", size: 14))
                    .foregroundStyle(palette.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(planCardBackground(isSelected: isSelected))
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: isSelected)
    }

    private func planCardBackground(isSelected: Bool, dominant: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(isSelected ? accentGold.opacity(dominant ? 0.09 : 0.07) : palette.surfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? accentGold : palette.border,
                        lineWidth: isSelected ? (dominant ? 2.0 : 1.6) : 1
                    )
            )
    }

    private func selectionRadio(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(isSelected ? accentGold : palette.border, lineWidth: 1.5)
                .frame(width: 22, height: 22)
            if isSelected {
                Circle()
                    .fill(accentGold)
                    .frame(width: 12, height: 12)
            }
        }
    }

    // MARK: - CTA Region (pinned)

    private func ctaRegion(vm: PaywallViewModel) -> some View {
        VStack(spacing: 10) {
            Button {
                HapticService.impact(.light)
                Analytics.track(.paywallCTATapped, properties: [
                    "product": vm.selectedProductID ?? "unknown",
                ])
                Task { await vm.purchaseSelected(storeKitService: storeKitService, dismiss: dismiss) }
            } label: {
                let isTrial = vm.selectedProductID == StoreKitService.weeklyID
                HStack(spacing: 7) {
                    if isTrial {
                        Image(systemName: "sparkle")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text(ctaTitle(vm: vm))
                        .font(.custom("Georgia-Bold", size: isTrial ? 16.5 : 16))
                        .tracking(0.3)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, isTrial ? 18 : 17)
                .background(ctaBackground(isTrial: isTrial))
                .shadow(color: accentGold.opacity(isTrial ? 0.42 : 0.22), radius: isTrial ? 18 : 11, y: isTrial ? 7 : 4)
                .shadow(color: .black.opacity(isTrial ? 0.16 : 0.08), radius: isTrial ? 6 : 4, y: 3)
                .animation(.easeOut(duration: 0.28), value: isTrial)
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(vm.isPurchasing)
            .padding(.horizontal, 22)

            Text(ctaSubtitle(vm: vm))
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(palette.textMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 24)

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
            .padding(.top, 1)
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(
            // Opaque region with only a short fade at the very top edge, so
            // scrolling content dissolves cleanly into the CTA instead of
            // bleeding through a tall transparent gradient (which made the
            // last plan card look clipped on shorter phones).
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [palette.background.opacity(0), palette.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 18)

                palette.background
            }
            .ignoresSafeArea(edges: .bottom)
        )
        .opacity(showContent ? 1 : 0)
    }

    // Trial CTA = richer gold + a sweeping shimmer + glossy top edge (feels
    // special, "your free trial"). Weekly CTA = a plain, calm gold pill.
    private func ctaBackground(isTrial: Bool) -> some View {
        // Deep bronze for the bottom of the metallic gradient — gives the gold
        // pill real dimensionality instead of a flat fill.
        let deepGold = accentGold.blend(with: Color(red: 0.28, green: 0.18, blue: 0.06), amount: 0.34)
        return ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        stops: isTrial
                            ? [
                                .init(color: accentGold.blend(with: .white, amount: 0.36), location: 0.0),
                                .init(color: accentGold, location: 0.52),
                                .init(color: deepGold, location: 1.0)
                              ]
                            : [
                                .init(color: accentGold.blend(with: .white, amount: 0.12), location: 0.0),
                                .init(color: accentGold.opacity(0.95), location: 1.0)
                              ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            if isTrial {
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
        }
        .overlay(
            // Beveled metallic rim: bright at the top, shadowed at the bottom.
            Capsule().stroke(
                LinearGradient(
                    colors: isTrial
                        ? [Color.white.opacity(0.55), accentGold.opacity(0.25), Color.black.opacity(0.16)]
                        : [Color.white.opacity(0.20), Color.clear],
                    startPoint: .top, endPoint: .bottom
                ),
                lineWidth: isTrial ? 1 : 0.5
            )
        )
    }

    private func ctaTitle(vm: PaywallViewModel) -> String {
        if vm.isPurchasing { return "Processing..." }
        if vm.selectedProductID == StoreKitService.weeklyID {
            return "Start Free Trial"
        }
        return "Continue with Yearly"
    }

    private func ctaSubtitle(vm: PaywallViewModel) -> String {
        if vm.selectedProductID == StoreKitService.weeklyID {
            return "Then \(vm.weeklyPriceLabel(storeKitService))/wk after 3 days · Cancel anytime"
        }
        return "\(vm.yearlyPriceLabel(storeKitService))/yr · Cancel anytime"
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
