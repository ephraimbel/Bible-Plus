import SwiftUI
import StoreKit

struct SummaryPaywallView: View {
    @Bindable var viewModel: OnboardingViewModel
    var isOnboarding: Bool = true

    @Environment(\.bpPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    @State private var showFeatures = false
    @State private var showPlans = false
    @State private var showCTA = false
    @State private var isPurchasing = false
    @State private var selectedProductID: String? = nil
    @State private var purchaseError: String? = nil

    // MARK: - Price Helpers

    private var yearlyPriceLabel: String {
        viewModel.storeKitService.yearlyProduct?.displayPrice ?? "$39.99"
    }

    private var weeklyPriceLabel: String {
        viewModel.storeKitService.weeklyProduct?.displayPrice ?? "$4.99"
    }

    private var yearlyWeeklyBreakdown: String {
        if let product = viewModel.storeKitService.yearlyProduct {
            let weekly = product.price / 52
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = product.priceFormatStyle.locale
            return formatter.string(from: weekly as NSDecimalNumber) ?? "$0.77"
        }
        return "$0.77"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Layer 1: Video background
            LoopingVideoPlayer(videoName: "water-ripples")
                .ignoresSafeArea()

            // Layer 2: Dark gradient overlay
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.15), location: 0.0),
                    .init(color: .black.opacity(0.5), location: 0.3),
                    .init(color: .black.opacity(0.8), location: 0.6),
                    .init(color: .black.opacity(0.92), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Layer 3: Radial gold glow behind logo
            RadialGradient(
                colors: [
                    Color(red: 0.79, green: 0.66, blue: 0.43).opacity(0.15),
                    .clear,
                ],
                center: .top,
                startRadius: 20,
                endRadius: 250
            )
            .offset(y: 60)
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
                    featureCarousel
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
                .shadow(color: Color(red: 0.79, green: 0.66, blue: 0.43).opacity(0.4), radius: 20, y: 4)
                .shadow(color: .black.opacity(0.5), radius: 10, y: 6)

            // "Bible+ Pro" title
            HStack(spacing: 0) {
                Text("Bible")
                    .foregroundStyle(.white)
                Text("+")
                    .foregroundStyle(Color(red: 0.79, green: 0.66, blue: 0.43))
                    .shadow(color: Color(red: 0.79, green: 0.66, blue: 0.43), radius: 8)
                    .shadow(color: Color(red: 0.79, green: 0.66, blue: 0.43), radius: 16)
                    .shadow(color: Color(red: 0.79, green: 0.66, blue: 0.43).opacity(0.6), radius: 30)
                Text(" Pro")
                    .foregroundStyle(.white)
            }
            .font(.system(size: 34, weight: .bold, design: .serif))
            .goldShimmer()

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
        let name = viewModel.firstName.trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            return "Unlock your complete spiritual companion"
        }
        return "\(name), unlock your complete\nspiritual companion"
    }

    // MARK: - Section 2: Feature Carousel

    private var featureCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                featureCard(
                    icon: "bubble.left.and.text.bubble.right.fill",
                    title: "AI Companion",
                    freeLabel: "10/day",
                    proLabel: "Unlimited",
                    gradient: [Color(red: 0.1, green: 0.15, blue: 0.35), Color(red: 0.15, green: 0.22, blue: 0.5)]
                )
                featureCard(
                    icon: "speaker.wave.2.fill",
                    title: "Audio Bible",
                    freeLabel: "3 ch/day",
                    proLabel: "Every chapter",
                    gradient: [Color(red: 0.25, green: 0.18, blue: 0.1), Color(red: 0.4, green: 0.28, blue: 0.15)]
                )
                featureCard(
                    icon: "waveform.circle.fill",
                    title: "Soundscapes",
                    freeLabel: "4 of 11",
                    proLabel: "All 11",
                    gradient: [Color(red: 0.08, green: 0.22, blue: 0.12), Color(red: 0.12, green: 0.35, blue: 0.18)]
                )
                featureCard(
                    icon: "photo.on.rectangle.fill",
                    title: "Backgrounds",
                    freeLabel: "Limited set",
                    proLabel: "All 52",
                    gradient: [Color(red: 0.2, green: 0.1, blue: 0.3), Color(red: 0.35, green: 0.15, blue: 0.5)]
                )
                featureCard(
                    icon: "folder.fill",
                    title: "Collections",
                    freeLabel: "1 collection",
                    proLabel: "Unlimited",
                    gradient: [Color(red: 0.22, green: 0.16, blue: 0.1), Color(red: 0.38, green: 0.25, blue: 0.12)]
                )
            }
            .padding(.horizontal, 24)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .padding(.top, 32)
        .opacity(showFeatures ? 1 : 0)
        .offset(y: showFeatures ? 0 : 20)
    }

    @ViewBuilder
    private func featureCard(
        icon: String,
        title: String,
        freeLabel: String,
        proLabel: String,
        gradient: [Color]
    ) -> some View {
        VStack(spacing: 0) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            }
            .padding(.top, 20)

            // Title
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 10)

            Spacer()

            // Free → Pro comparison
            VStack(spacing: 4) {
                Text(freeLabel)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .strikethrough(color: .white.opacity(0.3))

                Text(proLabel)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.79, green: 0.66, blue: 0.43))
            }
            .padding(.bottom, 18)
        }
        .frame(width: 140, height: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Section 3: Trust Strip

    private var trustStrip: some View {
        HStack(spacing: 0) {
            trustItem(icon: "star.fill", label: "4.9 Rating")
            trustDot
            trustItem(icon: "person.2.fill", label: "50K+ Users")
            trustDot
            trustItem(icon: "lock.shield.fill", label: "Private")
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
            yearlyCard
            weeklyCard
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

                        Text("Save 84%")
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
                title: isPurchasing ? "Processing..." : "Try Free for 3 Days",
                isEnabled: !isPurchasing,
                showGlow: true
            ) {
                Task { await purchaseSelected() }
            }
            .padding(.horizontal, 32)

            Text("3-day free trial, then \(selectedPriceDescription). Cancel anytime.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 24)
        .opacity(showCTA ? 1 : 0)
        .offset(y: showCTA ? 0 : 12)
    }

    private var selectedPriceDescription: String {
        if selectedProductID == StoreKitService.yearlyID {
            return "\(yearlyPriceLabel)/year"
        }
        return "\(weeklyPriceLabel)/week"
    }

    // MARK: - Section 6: Footer

    private var footerSection: some View {
        VStack(spacing: 14) {
            Button {
                if isOnboarding {
                    viewModel.goNext()
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
                    Task { await viewModel.storeKitService.restorePurchases() }
                } label: {
                    Text("Restore")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                }

                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 3, height: 3)

                Button {} label: {
                    Text("Terms")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                }

                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 3, height: 3)

                Button {} label: {
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
              let product = viewModel.storeKitService.subscriptions.first(where: { $0.id == productID })
        else { return }

        isPurchasing = true
        do {
            _ = try await viewModel.storeKitService.purchase(product)
            if viewModel.storeKitService.isPro {
                if isOnboarding {
                    viewModel.goNext()
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
