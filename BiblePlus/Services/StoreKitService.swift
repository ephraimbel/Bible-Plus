import StoreKit
import Foundation

@Observable
final class StoreKitService {
    private(set) var subscriptions: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private var transactionListener: Task<Void, Error>?

    static let weeklyID = "io.bibleplus.pro.weekly"
    static let yearlyID = "io.bibleplus.pro.yearly"

    var isPro: Bool { !purchasedProductIDs.isEmpty }

    var weeklyProduct: Product? {
        subscriptions.first { $0.id == Self.weeklyID }
    }

    var yearlyProduct: Product? {
        subscriptions.first { $0.id == Self.yearlyID }
    }

    init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    func loadProducts() async {
        do {
            subscriptions = try await Product.products(for: [
                Self.weeklyID,
                Self.yearlyID,
            ]).sorted { $0.price < $1.price }
        } catch {
            // Products may not be configured yet
        }
    }

    @discardableResult
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updatePurchasedProducts()
            return transaction
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await updatePurchasedProducts()
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? self?.checkVerified(result) {
                    await transaction.finish()
                    await self?.updatePurchasedProducts()
                }
            }
        }
    }

    private func updatePurchasedProducts() async {
        var ids: [String] = []
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                ids.append(transaction.productID)
            }
        }
        let newPurchased = Set(ids)
        await MainActor.run {
            purchasedProductIDs = newPurchased
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
