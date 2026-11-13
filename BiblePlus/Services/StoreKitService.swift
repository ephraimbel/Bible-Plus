import StoreKit
import Foundation
import RevenueCat

@Observable
final class StoreKitService {
    private(set) var productsLoaded = false
    private(set) var productsLoadError = false

    static let monthlyID = "io.bibleplus.pro.monthly"
    static let yearlyID = "io.bibleplus.pro.yearly"

    // RevenueCat packages for purchasing
    private var packages: [Package] = []

    // Expose StoreProduct wrappers that have .displayPrice, .price, .priceFormatStyle
    private(set) var subscriptions: [RevenueCat.StoreProduct] = []

    var isPro: Bool { _isPro }
    // DEBUG unlocks Pro for development. Release starts LOCKED and only flips
    // to true once updateEntitlements()/listenForEntitlementChanges() confirms
    // a live entitlement — so a free user never gets a Pro window on launch.
    #if DEBUG
    private var _isPro: Bool = true
    #else
    private var _isPro: Bool = false
    #endif

    var monthlyProduct: RevenueCat.StoreProduct? {
        subscriptions.first { $0.productIdentifier == Self.monthlyID }
    }

    var yearlyProduct: RevenueCat.StoreProduct? {
        subscriptions.first { $0.productIdentifier == Self.yearlyID }
    }

    init() {
        Task {
            await loadProducts()
            #if DEBUG
            // Skip entitlement checks — _isPro defaults to true in DEBUG
            #else
            await updateEntitlements()
            await listenForEntitlementChanges()
            #endif
        }
    }

    func loadProducts() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let current = offerings.current else {
                productsLoadError = true
                return
            }
            packages = current.availablePackages
            subscriptions = packages
                .map(\.storeProduct)
                .sorted { $0.price < $1.price }
            productsLoaded = true
            productsLoadError = false
            await refreshTrialEligibility()
        } catch {
            productsLoadError = true
            #if DEBUG
            print("[RevenueCat] Failed to load offerings: \(error)")
            #endif
        }
    }

    var purchaseError: String? = nil

    @discardableResult
    func purchase(_ product: RevenueCat.StoreProduct) async throws -> Bool {
        purchaseError = nil
        do {
            let (_, customerInfo, _) = try await Purchases.shared.purchase(product: product)
            let entitlement = customerInfo.entitlements["bibleplus Pro"]
            let active = entitlement?.isActive == true
            let isTrial = entitlement?.periodType == .trial
            let productId = product.productIdentifier
            let price = product.price
            let currency = product.currencyCode ?? "USD"
            await MainActor.run {
                _isPro = active
                guard active else { return }
                if isTrial {
                    TikTokAnalyticsService.shared.trackTrialStarted()
                } else {
                    TikTokAnalyticsService.shared.trackPurchase(
                        productId: productId,
                        revenue: price,
                        currency: currency
                    )
                }
            }
            return active
        } catch {
            let nsError = error as NSError
            // RevenueCat error code 1 = user cancelled — not a real error
            if nsError.domain == "RevenueCat.ErrorCode", nsError.code == 1 {
                return false
            }
            await MainActor.run { purchaseError = error.localizedDescription }
            #if DEBUG
            print("[RevenueCat] Purchase failed: \(error)")
            #endif
            throw error
        }
    }

    enum RestoreOutcome: Equatable {
        case restored
        case nothingToRestore
        case failed(String)

        /// User-facing message for the result alert (nil on success).
        var message: String? {
            switch self {
            case .restored: nil
            case .nothingToRestore: "No active Bible+ Pro subscription was found for this Apple ID."
            case .failed(let reason): "Couldn't restore purchases. \(reason)"
            }
        }
    }

    /// Restores purchases and reports the outcome so the UI can always give
    /// feedback (App Review taps Restore on every paywall).
    @discardableResult
    func restorePurchases() async -> RestoreOutcome {
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            let active = customerInfo.entitlements["bibleplus Pro"]?.isActive == true
            await MainActor.run { _isPro = active }
            return active ? .restored : .nothingToRestore
        } catch {
            #if DEBUG
            print("[RevenueCat] Restore failed: \(error)")
            #endif
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Introductory offer eligibility

    /// Whether this Apple ID can still get the yearly plan's free trial.
    /// Defaults to false until confirmed, so we never advertise a trial the
    /// user won't receive (Guideline 3.1.2 / 2.3.1).
    private(set) var isEligibleForYearlyTrial: Bool = false

    /// Free-trial length of the yearly plan as configured in App Store
    /// Connect, e.g. "7-day". Nil when the product has no intro offer.
    var yearlyTrialLengthLabel: String? {
        guard let period = yearlyProduct?.introductoryDiscount?.subscriptionPeriod,
              yearlyProduct?.introductoryDiscount?.paymentMode == .freeTrial else { return nil }
        switch period.unit {
        case .day: return "\(period.value)-day"
        case .week: return period.value == 1 ? "7-day" : "\(period.value)-week"
        case .month: return "\(period.value)-month"
        case .year: return "\(period.value)-year"
        @unknown default: return nil
        }
    }

    /// True only when the yearly plan has a free trial AND this user is
    /// eligible for it. Gate every "free trial" word in the UI on this.
    var showsYearlyTrial: Bool { isEligibleForYearlyTrial && yearlyTrialLengthLabel != nil }

    private func refreshTrialEligibility() async {
        guard let product = yearlyProduct else { return }
        let status = await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: product)
        // `.unknown` is rare with StoreKit 2; treat it as eligible so new users
        // aren't hidden the trial, but never show it to a known-ineligible user.
        let eligible = status != .ineligible && status != .noIntroOfferExists
        await MainActor.run { isEligibleForYearlyTrial = eligible }
    }

    /// Listen for real-time entitlement changes (renewal, expiry, upgrade, etc.)
    private func listenForEntitlementChanges() async {
        for await customerInfo in Purchases.shared.customerInfoStream {
            let active = customerInfo.entitlements["bibleplus Pro"]?.isActive == true
            await MainActor.run { _isPro = active }
        }
    }

    private func updateEntitlements() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            let active = customerInfo.entitlements["bibleplus Pro"]?.isActive == true
            await MainActor.run { _isPro = active }
        } catch {
            #if DEBUG
            print("[RevenueCat] Failed to get customer info: \(error)")
            #endif
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
