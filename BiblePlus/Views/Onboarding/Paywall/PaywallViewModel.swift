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

    // MARK: - Purchase State

    // Weekly is the featured plan: it carries the 3-day free trial, so it's
    // pre-selected to surface the trial CTA the moment the paywall opens.
    var selectedProductID: String? = StoreKitService.weeklyID
    var isPurchasing = false
    var purchaseError: String? = nil

    // MARK: - Presentation Mode

    let isOnboarding: Bool
    private let onboardingViewModel: OnboardingViewModel?

    // MARK: - Personalization

    let firstName: String
    let benefits: [PaywallBenefit]
    let personalizedHeadline: String
    let personalizedSubtitle: String

    /// Raw profile data passed through for downstream matching (testimonials,
    /// social proof). Captured once at init so the paywall view layer doesn't
    /// need to re-query the ModelContext.
    let userBurdens: Set<Burden>
    let userSeasons: Set<LifeSeason>
    let userFaithLevel: FaithLevel?
    let userTranslation: BibleTranslation
    let userPrayerTimes: Set<PrayerTimeSlot>

    /// Short lines echoed under the subtitle to show the user that the plan
    /// reflects their actual answers. "Prayers for anxiety", "Verses in NIV",
    /// "Moments at 6:30 AM" — specific, not generic. Research pegs this kind
    /// of echoed-quiz-input personalization at +15% lift.
    let matchedFeatureLines: [String]

    // MARK: - Onboarding Init

    init(viewModel: OnboardingViewModel) {
        self.onboardingViewModel = viewModel
        self.isOnboarding = true

        let name = viewModel.firstName.trimmingCharacters(in: .whitespaces)
        self.firstName = name

        let burdens = viewModel.selectedBurdens
        let faithLevel = viewModel.selectedFaithLevel
        let seasons = viewModel.selectedLifeSeasons
        let translation = viewModel.selectedTranslation
        let prayerTimes = viewModel.selectedPrayerTimes

        self.personalizedHeadline = Self.headline(name: name, burdens: burdens, faithLevel: faithLevel)
        self.personalizedSubtitle = Self.subtitle(name: name, burdens: burdens)
        self.benefits = Self.mapBenefits(burdens: burdens, faithLevel: faithLevel)
        self.userBurdens = burdens
        self.userSeasons = seasons
        self.userFaithLevel = faithLevel
        self.userTranslation = translation
        self.userPrayerTimes = prayerTimes
        self.matchedFeatureLines = Self.featureLines(
            burdens: burdens,
            translation: translation,
            prayerTimes: prayerTimes
        )
    }

    // MARK: - Standalone Init

    init(profile: UserProfile? = nil) {
        self.onboardingViewModel = nil
        self.isOnboarding = false

        let name = (profile?.firstName ?? "").trimmingCharacters(in: .whitespaces)
        self.firstName = name

        let burdens: Set<Burden> = Set(profile?.currentBurdens ?? [])
        let seasons: Set<LifeSeason> = Set(profile?.lifeSeasons ?? [])
        let faithLevel = profile?.faithLevel
        let translation = profile?.preferredTranslation ?? .kjv
        let prayerTimes: Set<PrayerTimeSlot> = Set(profile?.prayerTimes ?? [])

        self.personalizedHeadline = Self.headline(name: name, burdens: burdens, faithLevel: faithLevel)
        self.personalizedSubtitle = Self.subtitle(name: name, burdens: burdens)
        self.benefits = Self.mapBenefits(burdens: burdens, faithLevel: faithLevel)
        self.userBurdens = burdens
        self.userSeasons = seasons
        self.userFaithLevel = faithLevel
        self.userTranslation = translation
        self.userPrayerTimes = prayerTimes
        self.matchedFeatureLines = Self.featureLines(
            burdens: burdens,
            translation: translation,
            prayerTimes: prayerTimes
        )
    }

    // MARK: - Purchase

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

    /// Burden-first headline. If the user picked a specific burden, speak to
    /// it — that's the strongest signal of what they're looking for. Falls
    /// back to faith-level framing if they picked .none or skipped burdens.
    private static func headline(name: String, burdens: Set<Burden>, faithLevel: FaithLevel?) -> String {
        let safeName = name.isEmpty ? nil : name

        // Prefer a real burden over .none; deterministic order for ties.
        let primary = burdens
            .filter { $0 != .none }
            .sorted { $0.rawValue < $1.rawValue }
            .first

        if let primary {
            let tail = burdenHeadlineTail(primary)
            return safeName.map { "\($0), \(tail)" }
                ?? (tail.prefix(1).uppercased() + tail.dropFirst())
        }

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

    private static func burdenHeadlineTail(_ burden: Burden) -> String {
        switch burden {
        case .anxiety: return "peace for the anxious moments"
        case .grief: return "a companion through the valley"
        case .doubt: return "honest answers when you wrestle"
        case .loneliness: return "a friend who's always here"
        case .anger: return "calm for the storms inside"
        case .temptation: return "strength when it's hardest"
        case .health: return "hope for the healing road"
        case .financial: return "peace in uncertain seasons"
        case .relationship: return "wisdom for the ones you love"
        case .purpose: return "clarity for what's next"
        case .none: return "made for the way you believe"
        }
    }

    /// Secondary line under the headline — speaks directly to the user and
    /// reinforces that this was built *from* their answers, not sold *at* them.
    private static func subtitle(name: String, burdens: Set<Burden>) -> String {
        if name.isEmpty {
            return "Your complete spiritual companion"
        }
        if burdens.filter({ $0 != .none }).isEmpty {
            return "We built this just for you, \(name)"
        }
        return "Built from what you shared, \(name)"
    }

    /// Three specific, concrete lines echoing the user's collected profile.
    /// Each starts with a ✓ and speaks to a burden / translation / prayer time
    /// they actually picked — no generic feature list here.
    private static func featureLines(
        burdens: Set<Burden>,
        translation: BibleTranslation,
        prayerTimes: Set<PrayerTimeSlot>
    ) -> [String] {
        var lines: [String] = []

        if let primary = burdens.filter({ $0 != .none }).sorted(by: { $0.rawValue < $1.rawValue }).first {
            lines.append("Prayers matched to \(primary.displayName.lowercased())")
        } else {
            lines.append("Daily prayers matched to you")
        }

        lines.append("Every verse in \(translation.abbreviation)")

        if let firstTime = prayerTimes.sorted(by: { $0.rawValue < $1.rawValue }).first {
            lines.append("Gentle moments at \(firstTime.displayName)")
        } else {
            lines.append("Gentle moments when you need them")
        }

        return lines
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
                icon: "headphones",
                title: "Audio Bible in 9 Voices",
                subtitle: "Listen to any chapter, narrated in a voice you love"
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

    /// Annualized equivalent of the weekly price. Used as an anchor on the
    /// weekly card so the user can see at a glance what committing to weekly
    /// billing really costs over a year — makes the yearly plan feel rational
    /// without requiring the user to do the math.
    func weeklyAnnualEquivalent(_ storeKit: StoreKitService) -> String {
        if let product = storeKit.weeklyProduct {
            let annual = product.price * 52
            if let formatter = product.priceFormatter {
                return formatter.string(from: annual as NSNumber) ?? "$259.48"
            }
            return String(format: "$%.2f", (annual as NSDecimalNumber).doubleValue)
        }
        return "$259.48"
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
