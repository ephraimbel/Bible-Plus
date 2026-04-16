import SwiftUI

// MARK: - Benefit Model

struct PaywallBenefit: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}

// MARK: - Paywall ViewModel

@MainActor @Observable
final class PaywallViewModel {

    // MARK: - Navigation

    var currentPage: Int = 0
    let totalPages = 1

    // MARK: - Purchase State

    var selectedProductID: String? = StoreKitService.yearlyID
    var isPurchasing = false
    var purchaseError: String? = nil

    // MARK: - Per-Page Entrance Animation Flags

    var page1Appeared = false
    var page2Appeared = false
    var page3Appeared = false

    // MARK: - Presentation Mode

    let isOnboarding: Bool
    private let onboardingViewModel: OnboardingViewModel?

    // MARK: - Personalization

    let firstName: String
    let benefits: [PaywallBenefit]
    let personalizedHeadline: String
    let personalizedSubtitle: String

    // MARK: - Onboarding Init

    init(viewModel: OnboardingViewModel) {
        self.onboardingViewModel = viewModel
        self.isOnboarding = true

        let name = viewModel.firstName.trimmingCharacters(in: .whitespaces)
        self.firstName = name

        let burdens = viewModel.selectedBurdens
        let faithLevel = viewModel.selectedFaithLevel

        self.personalizedHeadline = Self.headline(name: name, faithLevel: faithLevel)
        self.personalizedSubtitle = name.isEmpty
            ? "Your complete spiritual companion"
            : "We built this just for you, \(name)"
        self.benefits = Self.mapBenefits(burdens: burdens, faithLevel: faithLevel)
    }

    // MARK: - Standalone Init

    init(profile: UserProfile? = nil) {
        self.onboardingViewModel = nil
        self.isOnboarding = false

        let name = (profile?.firstName ?? "").trimmingCharacters(in: .whitespaces)
        self.firstName = name

        let burdens: Set<Burden> = Set(profile?.currentBurdens ?? [])
        let faithLevel = profile?.faithLevel

        self.personalizedHeadline = Self.headline(name: name, faithLevel: faithLevel)
        self.personalizedSubtitle = name.isEmpty
            ? "Your complete spiritual companion"
            : "We built this just for you, \(name)"
        self.benefits = Self.mapBenefits(burdens: burdens, faithLevel: faithLevel)
    }

    // MARK: - Navigation Actions

    func advancePage() {
        guard currentPage < totalPages - 1 else { return }
        HapticService.impact(.light)
        withAnimation(BPAnimation.pageTransition) {
            currentPage += 1
        }
        Analytics.track(.paywallPageAdvanced, properties: [
            "from_page": "\(currentPage)",
            "to_page": "\(currentPage + 1)",
        ])
    }

    func dismissPaywall(dismiss: DismissAction) {
        let reason = isOnboarding ? "free_plan" : "maybe_later"
        Analytics.track(.paywallDismissed, properties: [
            "reason": reason,
            "page": "\(currentPage + 1)",
        ])
        if isOnboarding {
            onboardingViewModel?.goNext()
        } else {
            dismiss()
        }
    }

    func purchaseSelected(storeKitService: StoreKitService, dismiss: DismissAction) async {
        guard let productID = selectedProductID else { return }

        // If products haven't loaded, try loading them first
        if storeKitService.subscriptions.isEmpty {
            await storeKitService.loadProducts()
        }

        guard let product = storeKitService.subscriptions.first(where: { $0.productIdentifier == productID })
        else {
            purchaseError = "Unable to connect to the App Store. Please check your connection and try again."
            return
        }

        isPurchasing = true
        Analytics.track(.paywallPurchaseStarted, properties: ["product": productID])

        do {
            _ = try await storeKitService.purchase(product)
            if storeKitService.isPro {
                Analytics.track(.paywallPurchaseCompleted, properties: ["product": productID])
                if isOnboarding {
                    onboardingViewModel?.goNext()
                } else {
                    dismiss()
                }
            }
        } catch is CancellationError {
            Analytics.track(.paywallDismissed, properties: ["reason": "cancelled_purchase"])
        } catch StoreKitService.StoreError.failedVerification {
            purchaseError = "Purchase could not be verified. Please try again."
        } catch {
            purchaseError = "Something went wrong. Please try again."
        }
        isPurchasing = false
    }

    // MARK: - Personalization Logic

    private static func headline(name: String, faithLevel: FaithLevel?) -> String {
        let safeName = name.isEmpty ? nil : name
        switch faithLevel {
        case .justCurious:
            return safeName.map { "\($0), faith on your terms" }
                ?? "Faith on your terms"
        case .growing:
            return safeName.map { "\($0), keep the fire lit" }
                ?? "Keep the fire lit"
        case .deepInTheWord:
            return safeName.map { "\($0), every word, unlocked" }
                ?? "Every word, unlocked"
        case nil:
            return safeName.map { "\($0), made for the way you believe" }
                ?? "Made for the way you believe"
        }
    }

    private static func mapBenefits(burdens: Set<Burden>, faithLevel: FaithLevel?) -> [PaywallBenefit] {
        let burdenMap: [Burden: PaywallBenefit] = [
            .anxiety: PaywallBenefit(
                icon: "wind",
                title: "Peace When You Need It",
                subtitle: "AI-guided prayers and calming soundscapes for anxious moments"
            ),
            .grief: PaywallBenefit(
                icon: "heart.circle",
                title: "Comfort in Loss",
                subtitle: "Curated Scripture and prayers for seasons of grief"
            ),
            .doubt: PaywallBenefit(
                icon: "questionmark.bubble",
                title: "Answers to Hard Questions",
                subtitle: "Ask the AI companion anything about faith and Scripture"
            ),
            .loneliness: PaywallBenefit(
                icon: "person.2",
                title: "Never Walk Alone",
                subtitle: "A faithful companion available 24/7 for prayer and conversation"
            ),
            .anger: PaywallBenefit(
                icon: "leaf",
                title: "Finding Calm",
                subtitle: "Daily devotionals and guided breathing with Scripture"
            ),
            .temptation: PaywallBenefit(
                icon: "shield.checkered",
                title: "Strength for the Battle",
                subtitle: "Accountability-focused reading plans and daily reminders"
            ),
            .health: PaywallBenefit(
                icon: "cross.vial",
                title: "Healing & Hope",
                subtitle: "Prayers and verses for physical and emotional restoration"
            ),
            .financial: PaywallBenefit(
                icon: "hands.sparkles",
                title: "Provision & Trust",
                subtitle: "Plans and prayers focused on God's faithfulness in provision"
            ),
            .relationship: PaywallBenefit(
                icon: "heart.text.clipboard",
                title: "Restoring Relationships",
                subtitle: "Guided prayers and wisdom for relational healing"
            ),
            .purpose: PaywallBenefit(
                icon: "compass.drawing",
                title: "Discovering Your Calling",
                subtitle: "Reading plans and AI conversations to find direction"
            ),
        ]

        // Map user's burdens to benefits (up to 3), excluding .none
        var result: [PaywallBenefit] = burdens
            .filter { $0 != .none }
            .compactMap { burdenMap[$0] }
            .prefix(3)
            .map { $0 }

        // If we don't have enough, fill with generics
        let generics: [PaywallBenefit] = [
            PaywallBenefit(
                icon: "bubble.left.and.text.bubble.right",
                title: "Unlimited AI Companion",
                subtitle: "Ask anything about Scripture, pray together, get daily guidance"
            ),
            PaywallBenefit(
                icon: "book.pages",
                title: "All 9 Reading Plans",
                subtitle: "Guided journeys through Scripture tailored to your season"
            ),
            PaywallBenefit(
                icon: "music.note.list",
                title: "30+ Soundscapes & 184 Backgrounds",
                subtitle: "Create your perfect sanctuary for prayer and reflection"
            ),
            PaywallBenefit(
                icon: "sparkles",
                title: "1500+ Daily Content Pieces",
                subtitle: "Fresh prayers, verses, and devotionals every single day"
            ),
        ]

        for generic in generics where result.count < 4 {
            if !result.contains(where: { $0.title == generic.title }) {
                result.append(generic)
            }
        }

        return Array(result.prefix(4))
    }

    // MARK: - Price Helpers

    func yearlyPriceLabel(_ storeKit: StoreKitService) -> String {
        storeKit.yearlyProduct?.localizedPriceString ?? "$49.99"
    }

    func weeklyPriceLabel(_ storeKit: StoreKitService) -> String {
        storeKit.weeklyProduct?.localizedPriceString ?? "$4.99"
    }

    func yearlyWeeklyBreakdown(_ storeKit: StoreKitService) -> String {
        if let product = storeKit.yearlyProduct {
            let weeklyPrice = product.price / 52
            if let formatter = product.priceFormatter {
                return formatter.string(from: weeklyPrice as NSNumber) ?? "$0.96"
            }
            return String(format: "$%.2f", (weeklyPrice as NSDecimalNumber).doubleValue)
        }
        return "$0.96"
    }

    func savingsPercent(_ storeKit: StoreKitService) -> Int {
        guard let yearly = storeKit.yearlyProduct,
              let weekly = storeKit.weeklyProduct,
              weekly.price > 0, yearly.price > 0 else {
            return 81
        }
        let weeklyAnnual = (weekly.price as NSDecimalNumber).doubleValue * 52.0
        let yearlyPrice = (yearly.price as NSDecimalNumber).doubleValue
        guard weeklyAnnual > yearlyPrice else { return 81 }
        let result = Int((weeklyAnnual - yearlyPrice) / weeklyAnnual * 100)
        return result > 0 ? result : 81
    }
}
