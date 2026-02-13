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
    @State private var showContent = false
    @State private var showFeatures = false
    @State private var showPlans = false
    @State private var showCTA = false
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

    // MARK: - Body

    var body: some View {
        ZStack {
            // Smooth dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.1, blue: 0.09),
                    Color(red: 0.07, green: 0.07, blue: 0.06),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Layer 4: Content
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
                    featureList
                    trustStrip
                    planCards
                    ctaSection
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
                showContent = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
                showFeatures = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.7)) {
                showPlans = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.0)) {
                showCTA = true
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
            // App logo
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color(red: 0.79, green: 0.66, blue: 0.43).opacity(0.3), radius: 12, y: 2)
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)

            // "Bible+ Pro" title
            HStack(spacing: 0) {
                Text("Bible")
                    .foregroundStyle(.white)
                Text("+")
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.3))
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 4)
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 10)
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.9), radius: 20)
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.6), radius: 40)
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.3), radius: 60)
                Text(" Pro")
                    .foregroundStyle(.white)
            }
            .font(.system(size: 34, weight: .bold, design: .serif))

            // Personalized subtitle
            Text(personalizedSubtitle)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, isOnboarding ? 60 : 32)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }

    private var personalizedSubtitle: String {
        let name = (viewModel?.firstName ?? "").trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            return "Unlock your complete spiritual companion"
        }
        return "\(name), unlock your complete\nspiritual companion"
    }

    // MARK: - Section 2: Feature List

    private var featureList: some View {
        VStack(spacing: 14) {
            featureRow(icon: "bubble.left.and.text.bubble.right.fill", title: "Unlimited AI Companion")
            featureRow(icon: "speaker.wave.2.fill", title: "Full Audio Bible")
            featureRow(icon: "waveform.circle.fill", title: "All 27 Soundscapes")
            featureRow(icon: "photo.on.rectangle.fill", title: "All 132 Backgrounds")
            featureRow(icon: "folder.fill", title: "Unlimited Collections")
        }
        .padding(.top, 28)
        .opacity(showFeatures ? 1 : 0)
        .offset(y: showFeatures ? 0 : 20)
    }

    private func featureRow(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(red: 0.79, green: 0.66, blue: 0.43))
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    // MARK: - Section 3: Trust Strip

    private var trustStrip: some View {
        HStack(spacing: 0) {
            trustItem(icon: "lock.shield.fill", label: "Secure")
            trustDot
            trustItem(icon: "hand.raised.fill", label: "Private")
            trustDot
            trustItem(icon: "arrow.uturn.left.circle.fill", label: "Cancel Anytime")
        }
        .padding(.top, 28)
        .opacity(showFeatures ? 1 : 0)
    }

    private func trustItem(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Color(red: 0.79, green: 0.66, blue: 0.43))
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

    // MARK: - Section 4: Plan Cards

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
                            .foregroundStyle(Color(red: 0.79, green: 0.66, blue: 0.43))
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
                                    Color(red: 0.79, green: 0.66, blue: 0.43),
                                    Color(red: 0.65, green: 0.52, blue: 0.3),
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
                        Text("\(yearlyWeeklyBreakdown)/week")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 2)
                                .frame(width: 24, height: 24)
                            if isSelected {
                                Circle()
                                    .fill(Color(red: 0.79, green: 0.66, blue: 0.43))
                                    .frame(width: 24, height: 24)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }

                        Text("Save 81%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 0.4))
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
                                    Color(red: 0.79, green: 0.66, blue: 0.43).opacity(0.25),
                                    Color(red: 0.65, green: 0.52, blue: 0.3).opacity(0.15),
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
                            ? Color(red: 0.79, green: 0.66, blue: 0.43).opacity(0.6)
                            : .white.opacity(0.1),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(
                color: isSelected ? Color(red: 0.79, green: 0.66, blue: 0.43).opacity(0.2) : .clear,
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
                            .fill(Color(red: 0.79, green: 0.66, blue: 0.43))
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

    // MARK: - Section 5: CTA

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
            return "Try Free for 3 Days"
        }
        return "Subscribe Now"
    }

    private var ctaSubtitle: String {
        if selectedProductID == StoreKitService.yearlyID {
            return "3-day free trial, then \(yearlyPriceLabel)/year. Cancel anytime."
        }
        return "\(weeklyPriceLabel)/week. Cancel anytime."
    }

    // MARK: - Section 6: Footer

    private var footerSection: some View {
        VStack(spacing: 14) {
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
                    Text("Terms")
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
                    Text("Privacy")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding(.top, 20)
        .opacity(showCTA ? 1 : 0)
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
