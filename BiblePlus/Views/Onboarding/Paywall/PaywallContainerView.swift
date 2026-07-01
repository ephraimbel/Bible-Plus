import SwiftData
import SwiftUI

// MARK: - Paywall (cinematic photo hero + plans)
//
// Premium paywall pattern (Calm / Masterclass / Lifesum): a full-bleed
// photographic hero — our editorial model shot with a gentle Ken Burns — that
// dissolves seamlessly into a deep base. An elegant
// serif promise sits over the image; a tight benefit list, the recommended
// Yearly plan, and one gold CTA sit below. Dark Midnight palette so the moody
// photography and gold accents read cinematic. Typography matches onboarding:
// regular Baskerville headlines, clean sans labels.
struct PaywallContainerView: View {
    var onboardingViewModel: OnboardingViewModel? = nil
    var isOnboarding: Bool = true

    @Environment(StoreKitService.self) private var storeKitService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @Query private var profiles: [UserProfile]

    @State private var vm: PaywallViewModel?
    @State private var heroIndex = 0
    @State private var kenBurns = false
    @State private var contentIn = false

    private let heroImages = [
        "PaywallSlide1",
    ]

    // A deep, warm near-black base so the church photography melts into it.
    private let base = Color(red: 0.09, green: 0.08, blue: 0.07)
    private let palette = BPColorPalette.dark
    private let accentGold = Color(red: 0.82, green: 0.67, blue: 0.42)
    private let starGold = Color(red: 1.0, green: 0.84, blue: 0.3)
    private let cream = Color(red: 0.96, green: 0.93, blue: 0.87)

    init() {
        self.onboardingViewModel = nil
        self.isOnboarding = false
    }

    init(viewModel: OnboardingViewModel) {
        self.onboardingViewModel = viewModel
        self.isOnboarding = true
    }

    // The hero ignores the top safe area, so SwiftUI's GeometryReader reports a
    // 0 top inset here — read the real inset off the key window so the close
    // button always clears the Dynamic Island / status bar on every device.
    private var topSafeInset: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
        return window?.safeAreaInsets.top ?? 47
    }

    private let benefits: [String] = [
        "Unlimited AI companion, anytime",
        "Listen to the Bible in 9 lifelike voices",
        "All 29 plans \u{2014} free unlocks just one",
        "Every Bible translation",
        "1,500+ prayers & verses for your season",
        "Soundscapes, widgets & full Sanctuary",
    ]

    var body: some View {
        GeometryReader { geo in
            let heroHeight = geo.size.height * 0.49

            ZStack(alignment: .top) {
                base.ignoresSafeArea()

                if let vm {
                    VStack(spacing: 0) {
                        hero(height: heroHeight, topInset: geo.safeAreaInsets.top)
                        content(vm: vm)
                            .padding(.horizontal, 26)
                            .padding(.top, 18)
                            .padding(.bottom, max(geo.safeAreaInsets.bottom, 14) + 8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .opacity(contentIn ? 1 : 0)
                            .offset(y: contentIn ? 0 : 14)
                    }
                    .ignoresSafeArea(edges: .top)
                }

                topBar.padding(.top, max(topSafeInset - 52, 2))
            }
        }
        .environment(\.bpPalette, palette)
        .preferredColorScheme(.dark)
        .onAppear {
            if vm == nil {
                vm = onboardingViewModel.map { PaywallViewModel(viewModel: $0) } ?? PaywallViewModel(profile: profiles.first)
                vm?.selectedProductID = StoreKitService.yearlyID
            }
            Analytics.track(.paywallViewed, properties: [
                "source": isOnboarding ? "onboarding" : "settings", "version": "photo_hero",
            ])
            if storeKitService.subscriptions.isEmpty && !storeKitService.productsLoadError {
                Task { await storeKitService.loadProducts() }
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) { contentIn = true }
            withAnimation(.easeInOut(duration: 22).repeatForever(autoreverses: true)) { kenBurns = true }
        }
        .alert("Purchase Failed", isPresented: Binding(
            get: { vm?.purchaseError != nil },
            set: { if !$0 { vm?.purchaseError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm?.purchaseError ?? "") }
    }

    // MARK: - Hero (crossfading photos → fade into base)

    private func hero(height: CGFloat, topInset: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            // Crossfading photographs — each fills the hero frame with a center
            // crop (a square photo into this near-square frame trims only the
            // sides, so faces stay fully visible). Slow Ken Burns drift.
            ZStack {
                ForEach(heroImages.indices, id: \.self) { i in
                    Image(heroImages[i])
                        .resizable()
                        .scaledToFill()
                        .frame(width: UIScreen.main.bounds.width, height: height)
                        .clipped()
                        .opacity(i == heroIndex ? 1 : 0)
                }
            }
            // Slight scale-up + downward shift so the subjects sit a touch lower
            // in the frame (more headroom up top), with no gap exposed.
            .scaleEffect(kenBurns ? 1.16 : 1.12)
            .offset(y: 22)

            // Long, smooth dissolve into the base so the photo melts into the
            // content with no seam.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .clear, location: 0.20),
                    .init(color: base.opacity(0.06), location: 0.38),
                    .init(color: base.opacity(0.18), location: 0.52),
                    .init(color: base.opacity(0.36), location: 0.64),
                    .init(color: base.opacity(0.58), location: 0.75),
                    .init(color: base.opacity(0.80), location: 0.86),
                    .init(color: base.opacity(0.95), location: 0.95),
                    .init(color: base, location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom
            )

            // The Bible✦ wordmark sits above the promise, centered over the
            // faded base of the photo.
            VStack(spacing: 12) {
                wordmark
                Text("Everything you need\nto grow closer to God.")
                    .font(.custom("Baskerville", size: 28))
                    .foregroundStyle(cream)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
        .frame(height: height)
        .clipped()
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4.5))
                withAnimation(.easeInOut(duration: 1.6)) {
                    heroIndex = (heroIndex + 1) % heroImages.count
                }
            }
        }
    }

    private var wordmark: some View {
        HStack(spacing: 5) {
            Text("Bible")
                .font(.custom("Baskerville", size: 22))
                .foregroundStyle(cream)
            Image(systemName: "sparkle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(starGold)
                .shadow(color: starGold.opacity(0.8), radius: 8)
        }
        .shadow(color: .black.opacity(0.35), radius: 8, y: 1)
    }

    // MARK: - Content (benefits + plans + CTA)

    private func content(vm: PaywallViewModel) -> some View {
        VStack(spacing: 0) {
            // Benefits sit just under the hero with comfortable, even spacing.
            VStack(alignment: .leading, spacing: 13) {
                ForEach(benefits, id: \.self) { benefit in
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(accentGold)
                        Text(benefit)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(cream.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Flexible gap so the list never crowds the plan cards; absorbs the
            // leftover height and keeps the plans + CTA anchored at the bottom.
            Spacer(minLength: 14)

            VStack(spacing: 12) {
                planCards(vm: vm)
                ctaButton(vm: vm)

                Text(ctaSubtitle(vm: vm))
                    .font(.system(size: 11.5))
                    .foregroundStyle(cream.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                footerLinks
            }
        }
    }

    // MARK: - Top bar (close)

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                HapticService.lightImpact()
                if isOnboarding {
                    Analytics.track(.paywallDismissed, properties: ["reason": "skip_onboarding"])
                    onboardingViewModel?.goNext()
                } else {
                    Analytics.track(.paywallDismissed, properties: ["reason": "close"])
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(.white.opacity(0.05))
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 14)
    }

    // MARK: - Plans

    private func planCards(vm: PaywallViewModel) -> some View {
        HStack(spacing: 12) {
            priceCard(vm: vm, productID: StoreKitService.monthlyID, title: "Monthly",
                      price: vm.monthlyPriceLabel(storeKitService), sub: "per month", badge: nil)
            priceCard(vm: vm, productID: StoreKitService.yearlyID, title: "Yearly",
                      price: vm.yearlyPriceLabel(storeKitService),
                      sub: "\(vm.yearlyMonthlyBreakdown(storeKitService))/month", badge: "7-DAY FREE TRIAL")
        }
    }

    private func priceCard(vm: PaywallViewModel, productID: String, title: String,
                           price: String, sub: String, badge: String?) -> some View {
        let isSelected = vm.selectedProductID == productID
        return Button {
            vm.selectedProductID = productID
            HapticService.impact(.medium)
            Analytics.track(.paywallPriceCardSelected, properties: ["product": title.lowercased()])
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? accentGold : cream)
                Text(price)
                    .font(.custom("Baskerville", size: 26))
                    .foregroundStyle(isSelected ? accentGold : cream)
                    .minimumScaleFactor(0.7).lineLimit(1)
                Text(sub)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(cream.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? accentGold.opacity(0.10) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isSelected ? accentGold : Color.white.opacity(0.15),
                                    lineWidth: isSelected ? 1.5 : 1)
                    )
            )
            .overlay(alignment: .top) { if let badge { planBadge(badge) } }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }

    private func planBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .heavy, design: .rounded))
            .tracking(0.4).lineLimit(1).fixedSize()
            .foregroundStyle(Color(red: 0.12, green: 0.09, blue: 0.04))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [accentGold.blend(with: .white, amount: 0.3), accentGold],
                                         startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            )
            .offset(y: -10)
    }

    // MARK: - CTA

    private func ctaButton(vm: PaywallViewModel) -> some View {
        Button {
            HapticService.impact(.light)
            Analytics.track(.paywallCTATapped, properties: ["product": vm.selectedProductID ?? "unknown"])
            Task { await vm.purchaseSelected(storeKitService: storeKitService, dismiss: dismiss) }
        } label: {
            Text(ctaTitle(vm: vm))
                .font(.system(size: 18, weight: .semibold))
                .tracking(0.2)
                .foregroundStyle(Color(red: 0.12, green: 0.09, blue: 0.04))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [accentGold.blend(with: .white, amount: 0.16), accentGold],
                                             startPoint: .top, endPoint: .bottom))
                )
                .shadow(color: accentGold.opacity(0.35), radius: 16, y: 6)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(vm.isPurchasing)
    }

    private func ctaTitle(vm: PaywallViewModel) -> String {
        if vm.isPurchasing { return "Processing..." }
        return vm.selectedProductID == StoreKitService.yearlyID ? "Start Free Trial" : "Subscribe Now"
    }

    private func ctaSubtitle(vm: PaywallViewModel) -> String {
        if vm.selectedProductID == StoreKitService.yearlyID {
            return "Then \(vm.yearlyPriceLabel(storeKitService))/yr after 7 days \u{00B7} Cancel anytime"
        }
        return "\(vm.monthlyPriceLabel(storeKitService))/mo \u{00B7} Cancel anytime"
    }

    // MARK: - Footer

    private var footerLinks: some View {
        HStack(spacing: 14) {
            footerLink("Restore") {
                Analytics.track(.paywallRestoreTapped)
                Task { await storeKitService.restorePurchases() }
            }
            footerDot
            footerLink("Terms") { if let url = URL(string: "https://bibleplus.io/terms") { openURL(url) } }
            footerDot
            footerLink("Privacy") { if let url = URL(string: "https://bibleplus.io/privacy") { openURL(url) } }
        }
    }

    private func footerLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 11)).foregroundStyle(cream.opacity(0.45))
        }
    }

    private var footerDot: some View {
        Circle().fill(cream.opacity(0.3)).frame(width: 2.5, height: 2.5)
    }
}
