import SwiftUI
import StoreKit

struct SummaryPaywallView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.bpPalette) private var palette
    @State private var showContent = false
    @State private var isPurchasing = false
    @State private var selectedProductID: String? = nil
    @State private var purchaseError: String? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                // Personalized summary header
                VStack(spacing: 16) {
                    Text(viewModel.firstName.isEmpty
                        ? "Your Bible Plus is ready."
                        : "\(viewModel.firstName),\nyour Bible Plus is ready.")
                        .font(BPFont.headingMedium)
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)

                    // Summary items
                    VStack(spacing: 12) {
                        ForEach(viewModel.summaryItems, id: \.label) { item in
                            HStack(alignment: .top) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(palette.accent)
                                    .font(.body)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.label)
                                        .font(BPFont.reference)
                                        .foregroundStyle(palette.textMuted)
                                    Text(item.value)
                                        .font(BPFont.button)
                                        .foregroundStyle(palette.textPrimary)
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(palette.surfaceElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(palette.border, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 24)
                .opacity(showContent ? 1 : 0)

                Spacer().frame(height: 32)

                // Personal letter
                VStack(spacing: 16) {
                    Text("Unlock Your Full Journey")
                        .font(BPFont.headingSmall)
                        .foregroundStyle(palette.textPrimary)

                    Text(viewModel.firstName.isEmpty
                        ? "Thank you for sharing your heart with us. Bible Plus was built to walk with you every day — through prayers that call you by name, an AI that knows Scripture deeply, and a space designed for your peace."
                        : "\(viewModel.firstName), thank you for sharing your heart with us. Bible Plus was built to walk with you every day — through prayers that call you by name, an AI that knows Scripture deeply, and a space designed for your peace."
                    )
                    .font(BPFont.body)
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                }
                .padding(.horizontal, 24)
                .opacity(showContent ? 1 : 0)

                Spacer().frame(height: 24)

                // Pro features list
                VStack(alignment: .leading, spacing: 10) {
                    proFeatureRow("Unlimited AI Bible conversations")
                    proFeatureRow("All 11 ambient soundscapes")
                    proFeatureRow("50+ premium backgrounds")
                    proFeatureRow("Custom app icons")
                    proFeatureRow("Unlimited collections & highlights")
                    proFeatureRow("Background audio playback")
                }
                .padding(.horizontal, 32)
                .opacity(showContent ? 1 : 0)

                Spacer().frame(height: 24)

                // Subscription options
                VStack(spacing: 12) {
                    if let yearly = viewModel.storeKitService.yearlyProduct {
                        subscriptionCard(
                            product: yearly,
                            badge: "Best Value",
                            subtitle: "Save 52%"
                        )
                    }

                    if let monthly = viewModel.storeKitService.monthlyProduct {
                        subscriptionCard(
                            product: monthly,
                            badge: nil,
                            subtitle: "Cancel anytime"
                        )
                    }
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 20)

                // Purchase button
                if selectedProductID != nil {
                    GoldButton(
                        title: isPurchasing ? "Processing..." : "Start Your Journey",
                        isEnabled: !isPurchasing,
                        showGlow: true
                    ) {
                        Task { await purchaseSelected() }
                    }
                    .padding(.horizontal, 32)
                }

                Spacer().frame(height: 16)

                // Free plan option
                Button {
                    viewModel.goNext()
                } label: {
                    Text("Continue with free plan")
                        .font(BPFont.button)
                        .foregroundStyle(palette.textMuted)
                        .underline()
                }

                Spacer().frame(height: 12)

                // Restore purchases
                Button {
                    Task { await viewModel.storeKitService.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(BPFont.reference)
                        .foregroundStyle(palette.textMuted)
                }

                Spacer().frame(height: 40)
            }
        }
        .onAppear {
            withAnimation(BPAnimation.spring.delay(0.2)) {
                showContent = true
            }
            // Default to yearly
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

    // MARK: - Components

    @ViewBuilder
    private func proFeatureRow(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(palette.accent)
                .font(.body)
            Text(text)
                .font(BPFont.body)
                .foregroundStyle(palette.textPrimary)
        }
    }

    @ViewBuilder
    private func subscriptionCard(product: Product, badge: String?, subtitle: String) -> some View {
        let isSelected = selectedProductID == product.id

        Button {
            selectedProductID = product.id
            HapticService.selection()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(BPFont.button)
                            .foregroundStyle(
                                isSelected ? .white : palette.textPrimary
                            )

                        if let badge {
                            Text(badge)
                                .font(BPFont.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(
                                            isSelected
                                                ? Color.white.opacity(0.3)
                                                : palette.accent
                                        )
                                )
                        }
                    }

                    Text(subtitle)
                        .font(BPFont.reference)
                        .foregroundStyle(
                            isSelected ? .white.opacity(0.7) : palette.textMuted
                        )
                }

                Spacer()

                Text(product.displayPrice)
                    .font(BPFont.headingSmall)
                    .foregroundStyle(
                        isSelected ? .white : palette.textPrimary
                    )
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? palette.accent : palette.surfaceElevated
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.clear : palette.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(BPAnimation.selection, value: isSelected)
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
            // User cancelled — no alert needed
        } catch StoreKitService.StoreError.failedVerification {
            purchaseError = "Purchase could not be verified. Please try again."
        } catch {
            purchaseError = "Something went wrong. Please try again."
        }
        isPurchasing = false
    }
}
