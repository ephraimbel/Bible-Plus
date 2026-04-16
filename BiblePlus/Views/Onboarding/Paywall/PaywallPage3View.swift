import SwiftUI

struct PaywallPage3View: View {
    @Bindable var vm: PaywallViewModel
    @Environment(StoreKitService.self) private var storeKitService
    @Environment(\.bpPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showContent = false
    @State private var showPlans = false
    @State private var hasAnimated = false

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.3)
    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)
    private let saveGreen = Color(red: 0.2, green: 0.58, blue: 0.25)

    private var isYearlySelected: Bool {
        vm.selectedProductID == StoreKitService.yearlyID
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {

                // MARK: - Phone Mockups
                ZStack {
                    BibleMockupScreen()
                        .scaleEffect(0.50)
                        .rotationEffect(.degrees(-8))
                        .offset(x: -64, y: 6)
                        .zIndex(0)
                    FeedMockupScreen()
                        .scaleEffect(0.50)
                        .rotationEffect(.degrees(8))
                        .offset(x: 64, y: 6)
                        .zIndex(0)
                    ChatMockupScreen()
                        .scaleEffect(0.56)
                        .zIndex(1)
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.9)

                // MARK: - Header + Social Proof
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("Bible")
                            .font(.custom("Baskerville-Bold", size: 18))
                        Image(systemName: "sparkle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(gold)
                            .shadow(color: gold.opacity(0.5), radius: 4)
                        Text("Pro")
                            .font(.custom("Baskerville-Bold", size: 18))
                    }
                    .foregroundStyle(palette.textPrimary)

                    Text("Unlock the full experience")
                        .font(.custom("Georgia", size: 12))
                        .foregroundStyle(palette.textSecondary)

                    // Social proof
                    VStack(spacing: 4) {
                        HStack(spacing: 3) {
                            ForEach(0..<5, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(accentGold)
                            }
                            Text("4.9")
                                .font(.custom("Georgia-Bold", size: 11))
                                .foregroundStyle(palette.textPrimary)
                                .padding(.leading, 2)
                        }

                        Text("Join 700,000+ Christians")
                            .font(.custom("Georgia", size: 11))
                            .foregroundStyle(palette.textMuted)
                    }
                    .padding(.top, 2)
                }
                .padding(.top, 6)
                .opacity(showContent ? 1 : 0)

                // MARK: - Features
                featuresCard
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .opacity(showContent ? 1 : 0)

                // MARK: - Plan Cards
                VStack(spacing: 8) {
                    yearlyCard
                    weeklyCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .opacity(showPlans ? 1 : 0)
                .offset(y: showPlans ? 0 : 10)

                // MARK: - Footer (below fold)
                VStack(spacing: 10) {
                    HStack(spacing: 0) {
                        trustItem(icon: "lock.shield.fill", label: "Secure")
                        trustDot
                        trustItem(icon: "hand.raised.fill", label: "Private")
                        trustDot
                        trustItem(icon: "arrow.uturn.left.circle.fill", label: "Cancel Anytime")
                    }
                    .padding(.top, 14)

                    HStack(spacing: 14) {
                        footerLink("Restore") {
                            Analytics.track(.paywallRestoreTapped)
                            Task { await storeKitService.restorePurchases() }
                        }
                        footerDot
                        footerLink("Terms of Use") {
                            if let url = URL(string: "https://bibleplus.io/terms") { openURL(url) }
                        }
                        footerDot
                        footerLink("Privacy Policy") {
                            if let url = URL(string: "https://bibleplus.io/privacy") { openURL(url) }
                        }
                    }

                    Text("Payment charged to Apple ID at purchase. Auto-renews unless cancelled 24hrs before period end. Manage in Settings.")
                        .font(.system(size: 9))
                        .foregroundStyle(palette.textMuted.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .opacity(showPlans ? 1 : 0)

                Spacer(minLength: 16)
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: isYearlySelected)
        }
        .onAppear {
            if storeKitService.subscriptions.isEmpty {
                Task { await storeKitService.loadProducts() }
            }
            guard !hasAnimated else { return }
            hasAnimated = true

            let spring = Animation.spring(response: 0.6, dampingFraction: 0.82)
            withAnimation(spring.delay(0.1)) { showContent = true }
            withAnimation(spring.delay(0.3)) { showPlans = true }
        }
    }

    // MARK: - Features Card

    private var featuresCard: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
            featureChip(icon: "text.bubble", label: "Unlimited Chat")
            featureChip(icon: "book.closed", label: "8 Translations")
            featureChip(icon: "calendar", label: "9 Reading Plans")
            featureChip(icon: "waveform", label: "30 Soundscapes")
            featureChip(icon: "photo.on.rectangle", label: "239 Backgrounds")
            featureChip(icon: "speaker.wave.2", label: "Audio Bible")
            featureChip(icon: "person.2", label: "8 Biblical Guides")
            featureChip(icon: "paintbrush", label: "42 Sacred Art")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accentGold.opacity(0.1), lineWidth: 0.5)
        )
    }

    private func featureChip(icon: String, label: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(accentGold)
                .frame(width: 20, height: 20)
                .background(Circle().fill(accentGold.opacity(0.08)))
            Text(label)
                .font(.custom("Georgia", size: 11))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Yearly Card

    private var yearlyCard: some View {
        let isSelected = isYearlySelected

        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                vm.selectedProductID = StoreKitService.yearlyID
            }
            HapticService.impact(.medium)
        } label: {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Yearly")
                            .font(.custom("Baskerville", size: 16))
                            .foregroundStyle(isSelected ? palette.textPrimary : palette.textSecondary)

                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(vm.yearlyWeeklyBreakdown(storeKitService))
                                .font(.custom("Baskerville-Bold", size: 28))
                                .foregroundStyle(palette.textPrimary)
                            Text("/ week")
                                .font(.custom("Baskerville", size: 13))
                                .foregroundStyle(palette.textMuted)
                        }

                        HStack(spacing: 6) {
                            Text("\(vm.yearlyPriceLabel(storeKitService)) per year")
                                .font(.custom("Georgia", size: 11))
                                .foregroundStyle(palette.textSecondary)

                            Text("Save \(vm.savingsPercent(storeKitService))%")
                                .font(.custom("Georgia-Bold", size: 11))
                                .foregroundStyle(saveGreen)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                // Trial reveal — slides in when selected
                if isSelected {
                    HStack(spacing: 6) {
                        Image(systemName: "gift")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(accentGold)

                        Text("Includes 3-day free trial")
                            .font(.custom("Georgia-Italic", size: 12))
                            .foregroundStyle(palette.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(accentGold.opacity(0.06))
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .combined(with: .move(edge: .top))
                                .combined(with: .scale(scale: 0.97, anchor: .top)),
                            removal: .opacity
                        )
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                        ? AnyShapeStyle(accentGold.opacity(0.06))
                        : AnyShapeStyle(.ultraThinMaterial)
                    )
                    .opacity(isSelected ? 1 : 0.8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? accentGold.opacity(0.45) : palette.border.opacity(0.1),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(
                color: isSelected ? accentGold.opacity(0.15) : .black.opacity(0.02),
                radius: isSelected ? 10 : 3, y: isSelected ? 5 : 2
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Weekly Card

    private var weeklyCard: some View {
        let isSelected = vm.selectedProductID == StoreKitService.weeklyID

        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                vm.selectedProductID = StoreKitService.weeklyID
            }
            HapticService.impact(.medium)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly")
                        .font(.custom("Baskerville", size: 16))
                        .foregroundStyle(isSelected ? palette.textPrimary : palette.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(vm.weeklyPriceLabel(storeKitService))
                            .font(.custom("Baskerville-Bold", size: 28))
                            .foregroundStyle(palette.textPrimary)
                        Text("/ week")
                            .font(.custom("Baskerville", size: 13))
                            .foregroundStyle(palette.textMuted)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                        ? AnyShapeStyle(accentGold.opacity(0.06))
                        : AnyShapeStyle(.ultraThinMaterial)
                    )
                    .opacity(isSelected ? 1 : 0.6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? accentGold.opacity(0.45) : palette.border.opacity(0.08),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .shadow(
                color: isSelected ? accentGold.opacity(0.15) : .black.opacity(0.02),
                radius: isSelected ? 10 : 3, y: isSelected ? 5 : 2
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Helpers

    private func trustItem(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9)).foregroundStyle(accentGold.opacity(0.7))
            Text(label.uppercased()).font(.custom("Georgia", size: 9)).tracking(1).foregroundStyle(palette.textMuted)
        }
    }

    private var trustDot: some View {
        Circle().fill(palette.border).frame(width: 2.5, height: 2.5).padding(.horizontal, 8)
    }

    private func footerLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.custom("Georgia", size: 11)).foregroundStyle(palette.textMuted)
        }
    }

    private var footerDot: some View {
        Circle().fill(palette.border).frame(width: 2.5, height: 2.5)
    }
}
