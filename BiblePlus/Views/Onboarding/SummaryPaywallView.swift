import SwiftUI
import StoreKit

struct SummaryPaywallView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.bpPalette) private var palette
    @State private var showContent = false
    @State private var isPurchasing = false
    @State private var selectedProductID: String? = nil
    @State private var purchaseError: String? = nil

    private let features: [(icon: String, label: String)] = [
        ("bubble.left.and.text.bubble.right.fill", "Unlimited AI Chat"),
        ("waveform.circle.fill", "All Soundscapes"),
        ("photo.on.rectangle.fill", "Premium Backgrounds"),
        ("folder.fill", "Unlimited Collections"),
        ("speaker.wave.2.fill", "Background Audio"),
    ]

    private var yearlyPriceLabel: String {
        if let price = viewModel.storeKitService.yearlyProduct?.displayPrice {
            return "\(price)/year"
        }
        return "$39.99/year"
    }

    private var weeklyPriceLabel: String {
        if let price = viewModel.storeKitService.weeklyProduct?.displayPrice {
            return "\(price)/week"
        }
        return "$4.99/week"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // MARK: - Hero
            VStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(palette.accent)
                    .padding(.bottom, 4)

                Text("Bible+ Pro")
                    .font(BPFont.headingMedium)
                    .foregroundStyle(palette.textPrimary)

                Text("Your full spiritual companion")
                    .font(BPFont.body)
                    .foregroundStyle(palette.textSecondary)
            }
            .opacity(showContent ? 1 : 0)

            Spacer().frame(height: 28)

            // MARK: - Feature Pills
            VStack(spacing: 10) {
                ForEach(features, id: \.label) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(palette.accent)
                            .frame(width: 24, alignment: .center)
                        Text(feature.label)
                            .font(BPFont.body)
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 40)
            .opacity(showContent ? 1 : 0)

            Spacer().frame(height: 28)

            // MARK: - Plan Cards
            VStack(spacing: 12) {
                planCard(
                    id: StoreKitService.yearlyID,
                    title: yearlyPriceLabel,
                    subtitle: "$0.77/week",
                    badge: "Best Value"
                )

                planCard(
                    id: StoreKitService.weeklyID,
                    title: weeklyPriceLabel,
                    subtitle: nil,
                    badge: nil
                )
            }
            .padding(.horizontal, 24)
            .opacity(showContent ? 1 : 0)

            Spacer().frame(height: 24)

            // MARK: - CTA
            GoldButton(
                title: isPurchasing ? "Processing..." : "Start Free Trial",
                isEnabled: !isPurchasing,
                showGlow: true
            ) {
                Task { await purchaseSelected() }
            }
            .padding(.horizontal, 32)
            .opacity(showContent ? 1 : 0)

            Spacer().frame(height: 16)

            // MARK: - Footer Links
            VStack(spacing: 8) {
                Button {
                    viewModel.goNext()
                } label: {
                    Text("Continue with free plan")
                        .font(BPFont.button)
                        .foregroundStyle(palette.textMuted)
                        .underline()
                }

                Button {
                    Task { await viewModel.storeKitService.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(BPFont.reference)
                        .foregroundStyle(palette.textMuted)
                }

                Text("Cancel anytime")
                    .font(BPFont.caption)
                    .foregroundStyle(palette.textMuted.opacity(0.7))
            }
            .opacity(showContent ? 1 : 0)

            Spacer()
        }
        .onAppear {
            withAnimation(BPAnimation.spring.delay(0.2)) {
                showContent = true
            }
            selectedProductID = StoreKitService.yearlyID
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

    // MARK: - Plan Card

    @ViewBuilder
    private func planCard(id: String, title: String, subtitle: String?, badge: String?) -> some View {
        let isSelected = selectedProductID == id

        Button {
            withAnimation(BPAnimation.selection) {
                selectedProductID = id
            }
            HapticService.selection()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(BPFont.headingSmall)
                        .foregroundStyle(isSelected ? .white : palette.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(BPFont.reference)
                            .foregroundStyle(isSelected ? .white.opacity(0.7) : palette.textMuted)
                    }
                }

                Spacer()

                if let badge {
                    Text(badge)
                        .font(BPFont.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(
                                isSelected ? Color.white.opacity(0.25) : palette.accent
                            )
                        )
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? palette.accent : palette.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? palette.accent : palette.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
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
                viewModel.goNext()
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
