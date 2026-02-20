import SwiftUI
import StoreKit

struct SummaryPaywallView: View {
    // Onboarding mode: viewModel is non-nil
    var viewModel: OnboardingViewModel? = nil
    var isOnboarding: Bool = true

    @Environment(StoreKitService.self) private var storeKitService
    @Environment(\.bpPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    // Animation phases (8 staggered entrance beats)
    @State private var showHero = false
    @State private var showSocialProof = false
    @State private var showFeatures = false
    @State private var showTimeline = false
    @State private var showPlans = false
    @State private var showCTA = false
    @State private var showTrust = false
    @State private var showFooter = false

    // Hero continuous animations
    @State private var pulseScale: CGFloat = 1.0
    @State private var heroGlow: Double = 0.3

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
        storeKitService.yearlyProduct?.displayPrice ?? "$49.99"
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
            return formatter.string(from: weekly as NSDecimalNumber) ?? "$0.77"
        }
        return "$0.96"
    }

    private var savingsPercent: Int {
        guard let yearly = storeKitService.yearlyProduct,
              let weekly = storeKitService.weeklyProduct,
              weekly.price > 0 else {
            return 81 // Default: ($4.99*52 - $49.99) / ($4.99*52) ≈ 81%
        }
        let weeklyAnnual = weekly.price * 52
        guard weeklyAnnual > 0 else { return 81 }
        let savings = (weeklyAnnual - yearly.price) / weeklyAnnual * 100
        return max(NSDecimalNumber(decimal: savings).intValue, 0)
    }

    // MARK: - Feature Data

    private var proFeatures: [ProFeature] {
        [
            ProFeature(icon: "bubble.left.and.text.bubble.right.fill", title: "Unlimited AI Companion"),
            ProFeature(icon: "book.closed.fill", title: "All 9 Reading Plans"),
            ProFeature(icon: "character.book.closed.fill", title: "7 Bible Translations"),
            ProFeature(icon: "speaker.wave.2.fill", title: "Full Audio Bible"),
            ProFeature(icon: "waveform.circle.fill", title: "All 30 Soundscapes"),
            ProFeature(icon: "photo.on.rectangle.fill", title: "184 Backgrounds"),
            ProFeature(icon: "text.book.closed.fill", title: "1500+ Daily Content"),
            ProFeature(icon: "book.pages.fill", title: "Unlimited Journal"),
        ]
    }

    // MARK: - Body

    var body: some View {
        ZStack {
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

            // Subtle radial gold glow behind hero
            RadialGradient(
                colors: [
                    PaywallColors.gold.opacity(0.08),
                    Color.clear,
                ],
                center: .top,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Dismiss button (sheet mode only)
                    if !isOnboarding {
                        HStack {
                            Spacer()
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(.white.opacity(0.1)))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }

                    heroSection
                    inspirationalVerse
                    featureShowcase
                    trialTimeline
                    planCards
                    ctaSection
                    trustStrip
                    footerSection
                }
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            selectedProductID = StoreKitService.yearlyID

            // Staggered entrance beats
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15)) {
                showHero = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35)) {
                showSocialProof = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.55)) {
                showFeatures = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.75)) {
                showTimeline = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.95)) {
                showPlans = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.15)) {
                showCTA = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.3)) {
                showTrust = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.45)) {
                showFooter = true
            }

            // Continuous hero pulse
            withAnimation(BPAnimation.glowPulse) {
                pulseScale = 1.15
                heroGlow = 0.7
            }
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

    // MARK: - Section 1: Hero

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Pulsing concentric rings with cross icon
            ZStack {
                // Outermost ring
                Circle()
                    .stroke(PaywallColors.gold.opacity(0.08), lineWidth: 1)
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulseScale)

                // Middle ring
                Circle()
                    .stroke(PaywallColors.gold.opacity(0.15), lineWidth: 1)
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseScale)

                // Inner ring
                Circle()
                    .stroke(PaywallColors.gold.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseScale)

                // Sparkle icon (matches Ask page)
                Image(systemName: "sparkle")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(PaywallColors.goldGradient)
                    .shadow(color: PaywallColors.gold.opacity(heroGlow), radius: 16)
            }
            .frame(height: 170)

            // Title
            Text("Bible Plus Pro")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(PaywallColors.goldGradient)
                .shadow(color: PaywallColors.gold.opacity(0.4), radius: 8)

            // Personalized subtitle
            Text(personalizedSubtitle)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, isOnboarding ? 48 : 24)
        .opacity(showHero ? 1 : 0)
        .offset(y: showHero ? 0 : 20)
    }

    private var personalizedSubtitle: String {
        let name = (viewModel?.firstName ?? "").trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            return "Your complete spiritual\ncompanion awaits"
        }
        return "\(name), your complete spiritual\ncompanion awaits"
    }

    // MARK: - Section 2: Inspirational Verse

    private var inspirationalVerse: some View {
        VStack(spacing: 8) {
            OrnamentalDivider(color: .white, opacity: 0.2)

            Text("\"Seek and you shall find\"")
                .font(.system(size: 15, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(.white.opacity(0.6))

            Text("— Matthew 7:7")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.top, 24)
        .opacity(showSocialProof ? 1 : 0)
    }

    // MARK: - Section 3: Feature List

    private var featureShowcase: some View {
        VStack(spacing: 8) {
            ForEach(Array(proFeatures.enumerated()), id: \.element.title) { index, feature in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PaywallColors.gold)

                    Text(feature.title)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))

                    Spacer()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .opacity(showFeatures ? 1 : 0)
        .offset(y: showFeatures ? 0 : 20)
    }

    // MARK: - Section 4: Trial Timeline

    private var trialTimeline: some View {
        Group {
            if selectedProductID == StoreKitService.yearlyID {
                HStack(spacing: 0) {
                    timelineStep(icon: "lock.open.fill", label: "Full access", caption: "Today", isActive: true)

                    // Connector line
                    Rectangle()
                        .fill(.white.opacity(0.12))
                        .frame(height: 1)

                    timelineStep(icon: "bell.fill", label: "Reminder", caption: "Day 3", isActive: false)

                    // Connector line
                    Rectangle()
                        .fill(.white.opacity(0.12))
                        .frame(height: 1)

                    timelineStep(icon: "creditcard.fill", label: "Billing starts", caption: "Day 3", isActive: false)
                }
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(BPAnimation.spring, value: selectedProductID)
        .opacity(showTimeline ? 1 : 0)
    }

    private func timelineStep(icon: String, label: String, caption: String, isActive: Bool) -> some View {
        VStack(spacing: 6) {
            Text(caption)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(isActive ? PaywallColors.gold : .white.opacity(0.35))

            ZStack {
                Circle()
                    .fill(isActive ? PaywallColors.gold.opacity(0.2) : .white.opacity(0.06))
                    .frame(width: 36, height: 36)

                if isActive {
                    Circle()
                        .stroke(PaywallColors.gold.opacity(0.4), lineWidth: 1)
                        .frame(width: 36, height: 36)
                }

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isActive ? PaywallColors.gold : .white.opacity(0.3))
            }

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(isActive ? .white.opacity(0.7) : .white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section 5: Plan Cards

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
        .padding(.top, 24)
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

    // MARK: - Section 6: CTA

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
        .padding(.top, 24)
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

    // MARK: - Section 7: Trust Strip

    private var trustStrip: some View {
        HStack(spacing: 0) {
            trustItem(icon: "lock.shield.fill", label: "Secure")
            trustDot
            trustItem(icon: "hand.raised.fill", label: "Private")
            trustDot
            trustItem(icon: "arrow.uturn.left.circle.fill", label: "Cancel Anytime")
        }
        .padding(.top, 24)
        .opacity(showTrust ? 1 : 0)
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

    // MARK: - Section 8: Footer

    private var footerSection: some View {
        VStack(spacing: 14) {
            // Auto-renewal disclosure (required by App Store 3.1.2)
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

private struct ProFeature {
    let icon: String
    let title: String
}
