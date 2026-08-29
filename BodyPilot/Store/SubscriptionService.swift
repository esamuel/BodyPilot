import Foundation
import Observation
import StoreKit

/// StoreKit 2 subscription skeleton per PRD 14. Product IDs are defined in
/// App Store Connect; until they exist the paywall shows a graceful empty state.
@MainActor
@Observable
final class SubscriptionService {
    static let productIDs = [
        "com.bodypilot.pro.monthly",
        "com.bodypilot.pro.yearly",
    ]

    private(set) var products: [Product] = []
    private(set) var hasPro = false
    private(set) var isLoading = false

    func load() async {
        isLoading = true
        defer { isLoading = false }
        products = (try? await Product.products(for: Self.productIDs)) ?? []
        await refreshEntitlement()
    }

    func purchase(_ product: Product) async {
        guard let result = try? await product.purchase() else { return }
        if case .success(let verification) = result,
           case .verified(let transaction) = verification {
            await transaction.finish()
            await refreshEntitlement()
        }
    }

    func refreshEntitlement() async {
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               Self.productIDs.contains(transaction.productID) {
                hasPro = true
                return
            }
        }
        hasPro = false
    }
}
