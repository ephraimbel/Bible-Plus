import StoreKit
import Foundation
import RevenueCat

@Observable
final class StoreKitService {
    private(set) var productsLoaded = false
    private(set) var productsLoadError = false

    static let weeklyID = "io.bibleplus.pro.weekly"
    static let yearlyID = "io.bibleplus.pro.yearly"

    // RevenueCat packages for purchasing
    private var packages: [Package] = []

    // Expose StoreProduct wrappers that have .displayPrice, .price, .priceFormatStyle
    private(set) var subscriptions: [RevenueCat.StoreProduct] = []

    var isPro: Bool { _isPro }
    #if DEBUG
    // Debug builds default to Pro so simulator/dev sessions aren't blocked by
    // rate limits, paywall sheets, or feature gates. Production builds start
    // false and update via RevenueCat entitlement checks (see init).
    private var _isPro: Bool = true
    #else
    private var _isPro: Bool = false
    #endif

    var weeklyProduct: RevenueCat.StoreProduct? {
        subscriptions.first { $0.productIdentifier == Self.weeklyID }
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
            let active = customerInfo.entitlements["bibleplus Pro"]?.isActive == true
            await MainActor.run { _isPro = active }
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

    func restorePurchases() async {
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            let active = customerInfo.entitlements["bibleplus Pro"]?.isActive == true
            await MainActor.run { _isPro = active }
        } catch {
            #if DEBUG
            print("[RevenueCat] Restore failed: \(error)")
            #endif
        }
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
