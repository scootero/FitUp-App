//
//  SubscriptionStoreClient.swift
//  FitUp
//
//  StoreKit 2 boundary for product load, purchase, restore, and entitlements.
//

import StoreKit

struct SubscriptionProductDetails: Equatable, Sendable {
    let monthlyDisplayPrice: String?
    let annualDisplayPrice: String?
}

enum SubscriptionPurchaseOutcome: Equatable, Sendable {
    case purchased
    case pending
    case cancelled
}

enum SubscriptionError: LocalizedError {
    case productUnavailable
    case unverified
    case unknownPurchaseResult

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "\(SubscriptionConfig.displayName) isn’t available right now."
        case .unverified:
            return "Could not verify the App Store purchase."
        case .unknownPurchaseResult:
            return "StoreKit returned an unknown purchase result."
        }
    }
}

@MainActor
protocol SubscriptionStoreClient: AnyObject {
    func loadProducts() async throws -> SubscriptionProductDetails
    func purchase(_ plan: SubscriptionPlan) async throws -> SubscriptionPurchaseOutcome
    func restorePurchases() async throws
    func hasActiveProEntitlement() async -> Bool
}

@MainActor
final class LiveSubscriptionStoreClient: SubscriptionStoreClient {
    private var productsByID: [String: Product] = [:]

    func loadProducts() async throws -> SubscriptionProductDetails {
        let ids = Array(SubscriptionConfig.allProductIDs)
        let products = try await Product.products(for: ids)
        productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })

        let returned = products
            .map { "\($0.id)=\($0.displayPrice)" }
            .sorted()
            .joined(separator: ",")
        PaywallLogger.debug(
            "StoreKit product query",
            metadata: [
                "requested": ids.sorted().joined(separator: ","),
                "returnedCount": "\(products.count)",
                "returned": returned.isEmpty ? "<none>" : returned,
            ]
        )

        return SubscriptionProductDetails(
            monthlyDisplayPrice: productsByID[SubscriptionConfig.monthlyProductID]?.displayPrice,
            annualDisplayPrice: productsByID[SubscriptionConfig.annualProductID]?.displayPrice
        )
    }

    func purchase(_ plan: SubscriptionPlan) async throws -> SubscriptionPurchaseOutcome {
        guard let product = productsByID[plan.productID] else {
            throw SubscriptionError.productUnavailable
        }

        switch try await product.purchase() {
        case .success(let verification):
            let transaction = try verified(verification)
            await transaction.finish()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            throw SubscriptionError.unknownPurchaseResult
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
    }

    func hasActiveProEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verified(result) else { continue }
            if SubscriptionConfig.allProductIDs.contains(transaction.productID) {
                return true
            }
        }
        return false
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.unverified
        case .verified(let safe):
            return safe
        }
    }
}
