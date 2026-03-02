import SwiftUI
import StoreKit
import AVFoundation

struct SummaryPaywallView: View {
    // Onboarding mode: viewModel is non-nil
    var viewModel: OnboardingViewModel? = nil
    var isOnboarding: Bool = true

    @Environment(StoreKitService.self) private var storeKitService
    @Environment(\.bpPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    // Animation phases (staggered entrance)
    @State private var showHero = false
    @State private var showVerse = false
    @State private var showSocial = false
    @State private var showFeatures = false
    @State private var showTimeline = false
    @State private var showPlans = false
    @State private var showCTA = false
    @State private var showFooter = false

    // Existing state
    @State private var isPurchasing = false
    @State private var selectedProductID: String? = nil
    @State private var purchaseError: String? = nil

    /// Standalone initializer for non-onboarding paywall presentation
    init() {
        self.viewModel = nil
        self.isOnboarding = false
    }

    /// Onboarding initializer
    init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
        self.isOnboarding = true
    }

    // MARK: - Price Helpers

    private var yearlyPriceLabel: String {
        storeKitService.yearlyProduct?.displayPrice ?? "$79.99"
    }

    private var weeklyPriceLabel: String {
        storeKitService.weeklyProduct?.displayPrice ?? "$4.99"
    }

    private var yearlyWeeklyBreakdown: String {
        if let product = storeKitService.yearlyProduct {
            let weekly = product.price / 52
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = product.priceFormatStyle.locale
            return formatter.string(from: weekly as NSDecimalNumber) ?? "$1.54"
        }
        return "$1.54"
    }

    /// Computed as: ($4.99x52 - $79.99) / ($4.99x52) ~ 69%
    private var savingsPercent: Int {
        guard let yearly = storeKitService.yearlyProduct,
              let weekly = storeKitService.weeklyProduct,
              weekly.price > 0, yearly.price > 0 else {
            return 69
        }
        let weeklyAnnual = NSDecimalNumber(decimal: weekly.price).doubleValue * 52.0
        let yearlyPrice = NSDecimalNumber(decimal: yearly.price).doubleValue
        guard weeklyAnnual > yearlyPrice else { return 69 }
        let result = Int((weeklyAnnual - yearlyPrice) / weeklyAnnual * 100)
        return result > 0 ? result : 69
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.1, blue: 0.09),
                    Color(red: 0.07, green: 0.07, blue: 0.06),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Subtle radial gold glow behind hero area
            RadialGradient(
                colors: [
                    PaywallColors.gold.opacity(0.08),
                    Color.clear,
                ],
                center: .top,
                startRadius: 20,
                endRadius: 300
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    verseStrip
                    socialProofStrip
                    featureShowcase
                    trialTimeline
                    planCards
                    ctaSection
                    trustStrip
                    footerSection
                }
                .padding(.bottom, 40)
            }

            // Dismiss button (standalone paywall only)
            if !isOnboarding {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.08))
                                .stroke(.white.opacity(0.12), lineWidth: 0.5)
                        )
                }
                .padding(.top, 14)
                .padding(.trailing, 18)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            selectedProductID = StoreKitService.yearlyID

            let spring = Animation.spring(response: 0.6, dampingFraction: 0.8)
            withAnimation(spring.delay(0.1)) { showHero = true }
            withAnimation(spring.delay(0.35)) { showVerse = true }
            withAnimation(spring.delay(0.5)) { showSocial = true }
            withAnimation(spring.delay(0.65)) { showFeatures = true }
            withAnimation(spring.delay(0.85)) { showTimeline = true }
            withAnimation(spring.delay(0.95)) { showPlans = true }
            withAnimation(spring.delay(1.1)) { showCTA = true }
            withAnimation(spring.delay(1.25)) { showFooter = true }
        }
        .alert("Purchase Failed", isPresented: Binding(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseError ?? "")
        }
    }

    // MARK: - Section 1: Hero (Carousel + Title)

    private var heroSection: some View {
        VStack(spacing: 16) {
            PaywallCarousel()
                .frame(height: 340)

            Text("Bible Plus Pro")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(PaywallColors.goldGradient)

            Text(personalizedSubtitle)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, isOnboarding ? 20 : 10)
        .opacity(showHero ? 1 : 0)
        .offset(y: showHero ? 0 : 20)
    }

    private var personalizedSubtitle: String {
        let name = (viewModel?.firstName ?? "").trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            return "Your complete spiritual companion"
        }
        return "\(name), your complete spiritual companion"
    }

    // MARK: - Section 2: Inspirational Verse

    private var verseStrip: some View {
        VStack(spacing: 8) {
            // Ornamental divider
            HStack(spacing: 8) {
                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 40, height: 0.5)
                Image(systemName: "sparkle")
                    .font(.system(size: 8))
                    .foregroundStyle(PaywallColors.gold.opacity(0.6))
                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 40, height: 0.5)
            }

            Text("\u{201C}Seek and you shall find\u{201D}")
                .font(.system(size: 15, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(.white.opacity(0.6))

            Text("— Matthew 7:7")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.top, 20)
        .opacity(showVerse ? 1 : 0)
    }

    // MARK: - Section 3: Social Proof

    private var socialProofStrip: some View {
        EmptyView()
    }

    // MARK: - Section 4: Feature List

    private var featureShowcase: some View {
        VStack(spacing: 0) {
            featureRow("Unlimited AI Companion")
            featureRow("All 9 Reading Plans")
            featureRow("7 Translations + Audio Bible")
            featureRow("30 Soundscapes & 184 Backgrounds")
            featureRow("1500+ Daily Content")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .opacity(showFeatures ? 1 : 0)
        .offset(y: showFeatures ? 0 : 16)
    }

    private func featureRow(_ title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(PaywallColors.gold)
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
        }
        .padding(.vertical, 6)
    }

    // MARK: - Section 5: Trial Timeline (yearly only)

    private var trialTimeline: some View {
        Group {
            if selectedProductID == StoreKitService.yearlyID {
                VStack(spacing: 0) {
                    // Timeline circles + lines
                    HStack(spacing: 0) {
                        timelineCircle(icon: "lock.open.fill", isActive: true)
                        timelineLine
                        timelineCircle(icon: "bell.fill", isActive: false)
                        timelineLine
                        timelineCircle(icon: "creditcard.fill", isActive: false)
                    }
                    .padding(.horizontal, 50)

                    Spacer().frame(height: 8)

                    // Labels row
                    HStack(spacing: 0) {
                        timelineLabel(day: "Today", desc: "Full Access", isActive: true)
                        Spacer()
                        timelineLabel(day: "Day 2", desc: "Reminder", isActive: false)
                        Spacer()
                        timelineLabel(day: "Day 3", desc: "Billing Starts", isActive: false)
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.top, 24)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .opacity(showTimeline ? 1 : 0)
        .offset(y: showTimeline ? 0 : 10)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedProductID)
    }

    private func timelineCircle(icon: String, isActive: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isActive ? PaywallColors.gold.opacity(0.2) : .white.opacity(0.06))
                .frame(width: 38, height: 38)
            if isActive {
                Circle()
                    .stroke(PaywallColors.gold.opacity(0.4), lineWidth: 1)
                    .frame(width: 38, height: 38)
            }
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isActive ? PaywallColors.gold : .white.opacity(0.3))
        }
    }

    private var timelineLine: some View {
        Rectangle()
            .fill(.white.opacity(0.1))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    private func timelineLabel(day: String, desc: String, isActive: Bool) -> some View {
        VStack(spacing: 2) {
            Text(day)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? PaywallColors.gold : .white.opacity(0.45))
            Text(desc)
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(isActive ? .white.opacity(0.7) : .white.opacity(0.3))
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Section 6: Plan Cards

    private var planCards: some View {
        VStack(spacing: 12) {
            if storeKitService.productsLoadError && storeKitService.subscriptions.isEmpty {
                VStack(spacing: 12) {
                    Text("Unable to load subscription options")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    Button {
                        Task { await storeKitService.loadProducts() }
                    } label: {
                        Text("Tap to Retry")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(PaywallColors.gold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                yearlyCard
                weeklyCard
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .opacity(showPlans ? 1 : 0)
        .offset(y: showPlans ? 0 : 16)
    }

    private var yearlyCard: some View {
        let isSelected = selectedProductID == StoreKitService.yearlyID

        return Button {
            withAnimation(BPAnimation.selection) {
                selectedProductID = StoreKitService.yearlyID
            }
            HapticService.selection()
        } label: {
            VStack(spacing: 0) {
                // "BEST VALUE" badge
                Text("BEST VALUE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [
                                    PaywallColors.gold,
                                    PaywallColors.gold.opacity(0.8),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    )
                    .offset(y: -1)

                // Card content
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Yearly")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("\(yearlyPriceLabel)/year")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))

                        HStack(spacing: 6) {
                            Text("\(yearlyWeeklyBreakdown)/week")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))

                            Text("3-day free trial")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(PaywallColors.green)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 2)
                                .frame(width: 24, height: 24)
                            if isSelected {
                                Circle()
                                    .fill(PaywallColors.gold)
                                    .frame(width: 24, height: 24)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }

                        Text("Save \(savingsPercent)%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(PaywallColors.green)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [
                                    PaywallColors.gold.opacity(0.25),
                                    PaywallColors.gold.opacity(0.12),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [.white.opacity(0.06), .white.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected
                            ? PaywallColors.gold.opacity(0.6)
                            : .white.opacity(0.1),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(
                color: isSelected ? PaywallColors.gold.opacity(0.2) : .clear,
                radius: 12,
                y: 4
            )
        }
        .buttonStyle(.plain)
    }

    private var weeklyCard: some View {
        let isSelected = selectedProductID == StoreKitService.weeklyID

        return Button {
            withAnimation(BPAnimation.selection) {
                selectedProductID = StoreKitService.weeklyID
            }
            HapticService.selection()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("\(weeklyPriceLabel)/week")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Circle()
                            .fill(PaywallColors.gold)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [.white.opacity(0.1), .white.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [.white.opacity(0.04), .white.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected
                            ? .white.opacity(0.3)
                            : .white.opacity(0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section 7: CTA

    private var ctaSection: some View {
        VStack(spacing: 10) {
            GoldButton(
                title: isPurchasing ? "Processing..." : ctaButtonTitle,
                isEnabled: !isPurchasing,
                showGlow: true
            ) {
                Task { await purchaseSelected() }
            }
            .padding(.horizontal, 32)

            Text(ctaSubtitle)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 20)
        .opacity(showCTA ? 1 : 0)
        .offset(y: showCTA ? 0 : 12)
    }

    private var ctaButtonTitle: String {
        if selectedProductID == StoreKitService.yearlyID {
            return "Start My Free Trial"
        }
        return "Subscribe Now"
    }

    private var ctaSubtitle: String {
        if selectedProductID == StoreKitService.yearlyID {
            return "3-day free trial, then \(yearlyPriceLabel)/year. Cancel anytime."
        }
        return "\(weeklyPriceLabel) billed weekly. Cancel anytime."
    }

    // MARK: - Section 8: Trust Strip

    private var trustStrip: some View {
        HStack(spacing: 0) {
            trustItem(icon: "lock.shield.fill", label: "Secure")
            trustDot
            trustItem(icon: "hand.raised.fill", label: "Private")
            trustDot
            trustItem(icon: "arrow.uturn.left.circle.fill", label: "Cancel Anytime")
        }
        .padding(.top, 20)
        .opacity(showCTA ? 1 : 0)
    }

    private func trustItem(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(PaywallColors.gold)
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var trustDot: some View {
        Circle()
            .fill(.white.opacity(0.2))
            .frame(width: 3, height: 3)
            .padding(.horizontal, 10)
    }

    // MARK: - Section 9: Footer

    private var footerSection: some View {
        VStack(spacing: 14) {
            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions in your App Store account settings.")
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.25))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 4)

            Button {
                if isOnboarding {
                    viewModel?.goNext()
                } else {
                    dismiss()
                }
            } label: {
                Text(isOnboarding ? "Continue with free plan" : "Maybe Later")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .underline()
            }

            HStack(spacing: 16) {
                Button {
                    Task { await storeKitService.restorePurchases() }
                } label: {
                    Text("Restore")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                }

                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 3, height: 3)

                Button {
                    if let url = URL(string: "https://bibleplus.io/terms") {
                        openURL(url)
                    }
                } label: {
                    Text("Terms of Use (EULA)")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                }

                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 3, height: 3)

                Button {
                    if let url = URL(string: "https://bibleplus.io/privacy") {
                        openURL(url)
                    }
                } label: {
                    Text("Privacy Policy")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding(.top, 20)
        .opacity(showFooter ? 1 : 0)
    }

    // MARK: - Purchase

    private func purchaseSelected() async {
        guard let productID = selectedProductID,
              let product = storeKitService.subscriptions.first(where: { $0.id == productID })
        else { return }

        isPurchasing = true
        do {
            _ = try await storeKitService.purchase(product)
            if storeKitService.isPro {
                if isOnboarding {
                    viewModel?.goNext()
                } else {
                    dismiss()
                }
            }
        } catch is CancellationError {
            // User cancelled
        } catch StoreKitService.StoreError.failedVerification {
            purchaseError = "Purchase could not be verified. Please try again."
        } catch {
            purchaseError = "Something went wrong. Please try again."
        }
        isPurchasing = false
    }
}

// MARK: - Paywall Carousel (3 Scenes)

private struct PaywallCarousel: View {
    @State private var currentPage = 0
    @State private var autoTimer: Timer?

    private let sceneCount = 3
    private let autoAdvanceInterval: TimeInterval = 5.5

    var body: some View {
        VStack(spacing: 12) {
            TabView(selection: $currentPage) {
                FeedMockupScreen()
                    .tag(0)
                ChatMockupScreen()
                    .tag(1)
                BibleMockupScreen()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 310)

            // Page dots + labels
            HStack(spacing: 20) {
                pageDot(index: 0, label: "Daily Feed")
                pageDot(index: 1, label: "AI Chat")
                pageDot(index: 2, label: "Bible")
            }
        }
        .onAppear { startAutoAdvance() }
        .onDisappear { autoTimer?.invalidate() }
        .onChange(of: currentPage) { _, _ in
            // Reset timer on manual swipe
            startAutoAdvance()
        }
    }

    private func pageDot(index: Int, label: String) -> some View {
        let isActive = currentPage == index
        return VStack(spacing: 4) {
            Circle()
                .fill(isActive ? PaywallColors.gold : .white.opacity(0.2))
                .frame(width: isActive ? 8 : 6, height: isActive ? 8 : 6)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)

            Text(label)
                .font(.system(size: 10, weight: isActive ? .semibold : .regular, design: .rounded))
                .foregroundStyle(isActive ? PaywallColors.gold : .white.opacity(0.35))
                .animation(.easeOut(duration: 0.2), value: isActive)
        }
    }

    private func startAutoAdvance() {
        autoTimer?.invalidate()
        autoTimer = Timer.scheduledTimer(withTimeInterval: autoAdvanceInterval, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                currentPage = (currentPage + 1) % sceneCount
            }
        }
    }
}

// MARK: - Shared Phone Frame

private struct PhoneFrame<Content: View>: View {
    let screenBG: Color
    @ViewBuilder let content: Content

    // Realistic iPhone proportions (~1:2.03)
    private let phoneW: CGFloat = 148
    private let phoneH: CGFloat = 300
    private let bezel: CGFloat = 3
    private let outerRadius: CGFloat = 36
    private let innerRadius: CGFloat = 33

    var body: some View {
        ZStack {
            // Titanium frame — outer chassis
            RoundedRectangle(cornerRadius: outerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.22, blue: 0.21),
                            Color(red: 0.12, green: 0.12, blue: 0.11),
                            Color(red: 0.16, green: 0.16, blue: 0.15),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: phoneW, height: phoneH)
                .overlay(
                    RoundedRectangle(cornerRadius: outerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.30),
                                    .white.opacity(0.08),
                                    .white.opacity(0.15),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.75
                        )
                )
                .shadow(color: .black.opacity(0.55), radius: 24, y: 12)
                .shadow(color: PaywallColors.gold.opacity(0.08), radius: 40, y: 6)

            // Screen bg
            RoundedRectangle(cornerRadius: innerRadius)
                .fill(screenBG)
                .frame(width: phoneW - bezel * 2, height: phoneH - bezel * 2)

            // Screen content — fills full screen, Dynamic Island overlays on top
            VStack(spacing: 0) {
                content
            }
            .frame(width: phoneW - bezel * 2, height: phoneH - bezel * 2)
            .clipShape(RoundedRectangle(cornerRadius: innerRadius))
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.black)
                    .frame(width: 44, height: 12)
                    .padding(.top, 5)
            }

            // Side button (right) — subtle detail
            RoundedRectangle(cornerRadius: 1)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.15), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1.5, height: 28)
                .offset(x: phoneW / 2 + 0.25, y: -30)
        }
    }
}

// MARK: - Scene 1: AI Chat Mockup (Light Mode)

private struct ChatMockupScreen: View {
    @State private var question: String = ""
    @State private var answer: String = ""
    @State private var revealedChars = 0
    @State private var userOpacity: Double = 0
    @State private var aiOpacity: Double = 0
    @State private var dotsOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var cycleToken = 0
    @State private var exchangeIndex = 0
    @State private var hasStarted = false

    // Light mode palette
    private let bg = Color(hex: "FAF8F4")
    private let textPrimary = Color(hex: "2D2D2D")
    private let textMuted = Color(hex: "B8B0A0")
    private let surfaceEl = Color.white
    private let border = Color(hex: "E0D8C8")
    private let accent = Color(hex: "C9A96E")
    private let gradientTint = Color(red: 0.65, green: 0.48, blue: 0.25)

    private static let exchanges: [(q: String, a: String)] = [
        ("What does Psalm 23 mean?",
         "Psalm 23 is a beautiful psalm of comfort. David describes God as a caring shepherd who provides, protects, and guides us through life."),
        ("Pray with me about peace",
         "Dear Lord, we come before You seeking the peace that surpasses all understanding. Calm our hearts and minds today. Amen."),
    ]

    var body: some View {
        PhoneFrame(screenBG: bg) {
            ZStack {
                topGoldGradient.allowsHitTesting(false)

                VStack(spacing: 0) {
                    // Chat area (no nav bar — gold gradient extends to top)
                    VStack(alignment: .leading, spacing: 6) {
                        Spacer(minLength: 0)

                        // User bubble — always in tree, visibility via opacity
                        HStack {
                            Spacer(minLength: 16)
                            Text(question.isEmpty ? " " : question)
                                .font(.system(size: 8, weight: .regular, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 10,
                                        bottomLeadingRadius: 10,
                                        bottomTrailingRadius: 10,
                                        topTrailingRadius: 3
                                    )
                                    .fill(
                                        LinearGradient(
                                            colors: [accent, accent.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                )
                        }
                        .opacity(userOpacity)

                        // AI response — always in tree, both dots and text always rendered
                        HStack(alignment: .top, spacing: 4) {
                            aiAvatar(size: 14).padding(.top, 1)

                            ZStack(alignment: .topLeading) {
                                MockTypingDots(lightMode: true)
                                    .opacity(dotsOpacity)

                                Text(revealedChars > 0 ? String(answer.prefix(revealedChars)) : " ")
                                    .font(.system(size: 7, weight: .regular, design: .serif))
                                    .foregroundStyle(textPrimary)
                                    .lineSpacing(2.5)
                                    .opacity(textOpacity)
                            }

                            Spacer(minLength: 6)
                        }
                        .opacity(aiOpacity)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                    // Input bar
                    VStack(spacing: 0) {
                        border.opacity(0.3).frame(height: 0.5)
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(surfaceEl)
                                .frame(height: 22)
                                .overlay(alignment: .leading) {
                                    Text("Ask anything about Scripture...")
                                        .font(.system(size: 6.5, weight: .regular, design: .rounded))
                                        .foregroundStyle(textMuted)
                                        .padding(.leading, 8)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(border.opacity(0.3), lineWidth: 0.5)
                                )
                                .shadow(color: .black.opacity(0.03), radius: 2, y: 1)

                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [accent, accent.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 20, height: 20)
                                    .shadow(color: accent.opacity(0.2), radius: 2, y: 1)
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(bg.opacity(0.95))
                    }
                }
            }
        }
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            beginCycle()
        }
    }

    private func aiAvatar(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [accent.opacity(0.15), accent.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
            Text("+")
                .font(.system(size: size * 0.7, weight: .medium, design: .serif))
                .foregroundStyle(LinearGradient(colors: [Color(red: 1.0, green: 0.84, blue: 0.3), accent], startPoint: .top, endPoint: .bottom))
        }
    }

    private var topGoldGradient: some View {
        let s: CGFloat = 0.28
        return LinearGradient(
            stops: [
                .init(color: bg.blend(with: gradientTint, amount: s), location: 0.0),
                .init(color: bg.blend(with: gradientTint, amount: s * 0.9), location: 0.12),
                .init(color: bg.blend(with: gradientTint, amount: s * 0.7), location: 0.25),
                .init(color: bg.blend(with: gradientTint, amount: s * 0.45), location: 0.40),
                .init(color: bg.blend(with: gradientTint, amount: s * 0.15), location: 0.55),
                .init(color: bg, location: 0.65),
                .init(color: bg, location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Animation cycle

    private func beginCycle() {
        // Increment token first — cancels ALL in-flight async blocks from any previous cycle
        cycleToken += 1
        let token = cycleToken
        let ex = Self.exchanges[exchangeIndex % Self.exchanges.count]

        // Snap to initial state (no animation)
        question = ex.q
        answer = ex.a
        revealedChars = 0
        dotsOpacity = 0
        textOpacity = 0
        userOpacity = 0
        aiOpacity = 0

        // Step 1: Fade in user message
        after(0.6) {
            guard cycleToken == token else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                userOpacity = 1
            }
        }

        // Step 2: Fade in AI row with typing dots visible
        after(1.6) {
            guard cycleToken == token else { return }
            dotsOpacity = 1
            textOpacity = 0
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                aiOpacity = 1
            }
        }

        // Step 3: Crossfade dots → text, then stream
        after(2.6) {
            guard cycleToken == token else { return }
            dotsOpacity = 0
            textOpacity = 1
            streamAnswer(token: token)
        }
    }

    private func streamAnswer(token: Int) {
        let total = answer.count
        let pace: TimeInterval = 0.018

        for i in 1...total {
            after(pace * Double(i)) {
                guard cycleToken == token else { return }
                revealedChars = i
            }
        }

        let streamDuration = pace * Double(total)

        // Step 4: Fade out both bubbles
        after(streamDuration + 2.0) {
            guard cycleToken == token else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                userOpacity = 0
                aiOpacity = 0
            }
        }

        // Step 5: Start next cycle after fade fully completes
        after(streamDuration + 2.6) {
            guard cycleToken == token else { return }
            exchangeIndex += 1
            beginCycle()
        }
    }

    private func after(_ delay: TimeInterval, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }
}

// MARK: - Scene 2: Bible Reader Mockup (Verse Cascade)

private struct BibleMockupScreen: View {
    /// How many verses are currently visible (0 = all hidden, 5 = all showing)
    @State private var visibleCount = 0
    @State private var cycleToken = 0
    @State private var hasStarted = false

    private let parchment = Color(hex: "FAF8F4")
    private let textDark = Color(hex: "2D2D2D")
    private let accent = Color(hex: "C9A96E")

    private let verses: [(Int, String)] = [
        (1, "The Lord is my shepherd; I shall not want."),
        (2, "He maketh me to lie down in green pastures: he leadeth me beside the still waters."),
        (3, "He restoreth my soul: he leadeth me in the paths of righteousness for his name\u{2019}s sake."),
        (4, "Yea, though I walk through the valley of the shadow of death, I will fear no evil: for thou art with me; thy rod and thy staff they comfort me."),
        (5, "Thou preparest a table before me in the presence of mine enemies."),
    ]

    var body: some View {
        PhoneFrame(screenBG: parchment) {
            // Nav bar — padded below Dynamic Island overlay
            HStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(textDark.opacity(0.35))
                Spacer()
                Text("Psalm 23")
                    .font(.system(size: 9, weight: .semibold, design: .serif))
                    .foregroundStyle(textDark)
                Spacer()
                Image(systemName: "textformat.size")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(textDark.opacity(0.35))
            }
            .padding(.horizontal, 10)
            .padding(.top, 22)
            .padding(.bottom, 4)

            // Chapter heading
            Text("Psalm 23")
                .font(.system(size: 11, weight: .semibold, design: .serif))
                .foregroundStyle(textDark)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 2)

            // Ornamental dots
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(accent.opacity(0.4))
                        .frame(width: 2, height: 2)
                }
            }
            .padding(.bottom, 6)

            // Verses — cascade fade-in, each verse always rendered
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(verses.enumerated()), id: \.element.0) { index, verse in
                    let isVisible = index < visibleCount
                    verseRow(number: verse.0, text: verse.1)
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: isVisible ? 0 : 4)
                        .animation(
                            .easeOut(duration: 0.4).delay(Double(index) * 0.08),
                            value: visibleCount
                        )
                }
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 0)
        }
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            runCascade()
        }
    }

    private func verseRow(number: Int, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(number)")
                .font(.system(size: 5, weight: .bold, design: .serif))
                .foregroundStyle(accent)
                .baselineOffset(3)

            Text("\u{2009}\(text) ")
                .font(.system(size: 7, weight: .regular, design: .serif))
                .foregroundStyle(textDark.opacity(0.85))
                .lineSpacing(2.5)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 3)
    }

    // MARK: - Cascade Animation

    private func runCascade() {
        cycleToken += 1
        let token = cycleToken

        // Reset: all hidden
        visibleCount = 0

        // Reveal verses one by one (0.5s stagger between each)
        let stagger: TimeInterval = 0.5
        for i in 1...verses.count {
            after(stagger * Double(i)) {
                guard cycleToken == token else { return }
                visibleCount = i
            }
        }

        // Hold fully visible for reading
        let holdStart = stagger * Double(verses.count) + 2.5

        // Fade all out at once
        after(holdStart) {
            guard cycleToken == token else { return }
            visibleCount = 0
        }

        // Restart cycle after fade out completes
        after(holdStart + 0.8) {
            guard cycleToken == token else { return }
            runCascade()
        }
    }

    private func after(_ delay: TimeInterval, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }
}

// MARK: - Scene 3: Daily Feed Mockup
//
// Architecture: The AVQueuePlayer + AVPlayerLooper live in @State on this view,
// so they persist across TabView page changes. The UIViewRepresentable is just a
// thin AVPlayerLayer wrapper — it can be destroyed/recreated without affecting
// playback. This eliminates all lifecycle-related freezing.

private struct FeedMockupScreen: View {
    // Player lives here in @State — SwiftUI NEVER destroys it during TabView rotation
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper? // must hold strong ref

    @State private var appeared = false
    @State private var heartPop = false

    // PhoneFrame inner dimensions: (148 - 2*3) x (300 - 2*3)
    private let screenW: CGFloat = 142
    private let screenH: CGFloat = 294

    // Flowing Water gradient fallback
    private let waterGradient: [Color] = [
        Color(hex: "1A5276"),
        Color(hex: "2980B9"),
        Color(hex: "5DADE2"),
    ]

    var body: some View {
        PhoneFrame(screenBG: Color(hex: "1A5276")) {
            ZStack {
                // Layer 1: Gradient fallback (visible instantly while video loads)
                LinearGradient(
                    colors: waterGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: screenW, height: screenH)

                // Layer 2: Video — thin layer view, player persists in @State
                if let player {
                    PersistentPlayerLayer(player: player)
                        .frame(width: screenW, height: screenH)
                        .clipped()
                }

                // Layer 3: Vignette
                Color.black.opacity(0.06)
                    .frame(width: screenW, height: screenH)

                RadialGradient(
                    colors: [.clear, .black.opacity(0.18)],
                    center: .center,
                    startRadius: 80,
                    endRadius: 200
                )
                .frame(width: screenW, height: screenH)

                // Layer 4: Content
                VStack(spacing: 0) {
                    Spacer(minLength: 30)

                    Text("VERSE OF THE DAY")
                        .font(.system(size: 5.5, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                        .padding(.bottom, 12)

                    Text("Be still, and know\nthat I am God.")
                        .font(.system(size: 12, weight: .regular, design: .serif))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .shadow(color: .black.opacity(0.5), radius: 4, y: 1)

                    HStack(spacing: 4) {
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 12, height: 0.5)
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 3))
                            .foregroundStyle(.white.opacity(0.35))
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 12, height: 0.5)
                    }
                    .padding(.top, 10)

                    Text("\u{2014} Psalm 46:10")
                        .font(.system(size: 7, weight: .medium, design: .serif))
                        .foregroundStyle(.white.opacity(0.75))
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .padding(.top, 5)

                    Spacer(minLength: 20)
                }
                .frame(width: screenW, height: screenH)
                .padding(.horizontal, 14)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 6)

                // Layer 5: Action bar
                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 14) {
                        feedIcon("heart.fill", tinted: heartPop)
                        feedIcon("square.and.arrow.up", tinted: false)
                        feedIcon("pin", tinted: false)
                        feedIcon("bubble.left.and.bubble.right", tinted: false)
                    }
                    Spacer()
                }
                .frame(width: screenW, height: screenH, alignment: .trailing)
                .padding(.trailing, 8)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            // Create player once; on subsequent onAppear calls just resume
            if player == nil {
                setupPlayer()
            } else {
                player?.play()
            }

            if !appeared {
                withAnimation(.easeOut(duration: 0.5).delay(0.2)) { appeared = true }
                heartLoop()
            }
        }
        // Resume when app returns from background
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            player?.play()
        }
    }

    private func setupPlayer() {
        guard let url = Bundle.main.url(forResource: "water-ripples", withExtension: "mp4") else { return }
        let asset = AVAsset(url: url)
        let template = AVPlayerItem(asset: asset)
        let qp = AVQueuePlayer()
        qp.isMuted = true
        looper = AVPlayerLooper(player: qp, templateItem: template)
        player = qp
        qp.play()
    }

    private func feedIcon(_ name: String, tinted: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(tinted ? PaywallColors.gold : .white.opacity(0.85))
            .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
            .scaleEffect(tinted && name == "heart.fill" ? 1.2 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: tinted)
    }

    private func heartLoop() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { heartPop = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation { heartPop = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            heartLoop()
        }
    }
}

// MARK: - Typing Dots for Mockup

private struct MockTypingDots: View {
    var lightMode: Bool = false
    @State private var dotScale: [CGFloat] = [0.5, 0.5, 0.5]

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(lightMode ? Color(hex: "B8B0A0") : .white.opacity(0.35))
                    .frame(width: 3.5, height: 3.5)
                    .scaleEffect(dotScale[i])
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .onAppear {
            for i in 0..<3 {
                withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(Double(i) * 0.15)) {
                    dotScale[i] = 1.0
                }
            }
        }
    }
}

// MARK: - Persistent Player Layer (thin AVPlayerLayer wrapper — no playback logic)
//
// The AVPlayer is owned by FeedMockupScreen's @State, NOT by this UIView.
// This view just creates an AVPlayerLayer to display the player's output.
// SwiftUI can destroy/recreate this freely without affecting playback.

private struct PersistentPlayerLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PersistentPlayerLayerView {
        let view = PersistentPlayerLayerView()
        view.attach(player)
        player.play() // ensure playing when layer is created
        return view
    }

    func updateUIView(_ uiView: PersistentPlayerLayerView, context: Context) {
        uiView.attach(player)
        player.play() // ensure playing on every SwiftUI update
    }

    static func dismantleUIView(_ uiView: PersistentPlayerLayerView, coordinator: ()) {
        // Only detach the layer — do NOT pause or nil the player
        uiView.detach()
    }
}

private final class PersistentPlayerLayerView: UIView {
    private var playerLayer: AVPlayerLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func attach(_ player: AVPlayer) {
        // Already attached to this player — no-op
        if playerLayer?.player === player { return }
        playerLayer?.removeFromSuperlayer()
        let l = AVPlayerLayer(player: player)
        l.videoGravity = .resizeAspectFill
        l.frame = bounds
        layer.addSublayer(l)
        playerLayer = l
    }

    func detach() {
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
}

// MARK: - Private Helpers

private enum PaywallColors {
    static let gold = Color(red: 0.79, green: 0.66, blue: 0.43)
    static let goldLight = Color(red: 1.0, green: 0.88, blue: 0.5)
    static let goldGradient = LinearGradient(
        colors: [goldLight, gold],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let green = Color(red: 0.4, green: 0.8, blue: 0.4)
}
