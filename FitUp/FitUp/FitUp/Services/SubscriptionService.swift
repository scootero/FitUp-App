//
//  SubscriptionService.swift
//  FitUp
//
//  Central StoreKit 2 entitlement + FitOff free/pro access policy.
//  Debug builds may force Free/Pro/System access without disabling StoreKit.
//  Release builds always follow the real StoreKit entitlement.
//

import Combine
import Foundation
import StoreKit

enum SubscriptionActionState: Equatable {
    case idle
    case purchasing
    case purchased
    case pending
    case cancelled
    case restoring
    case restored
    case noActiveSubscription
    case failed(String)

    var message: String? {
        switch self {
        case .idle, .purchasing, .restoring:
            return nil
        case .purchased:
            return "\(SubscriptionConfig.displayName) is active."
        case .pending:
            return "Purchase is pending approval. Pro will unlock when Apple completes it."
        case .cancelled:
            return "Purchase cancelled."
        case .restored:
            return "\(SubscriptionConfig.displayName) was restored."
        case .noActiveSubscription:
            return "No active subscription was found for this Apple ID."
        case .failed(let message):
            return message
        }
    }

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

#if DEBUG
enum DebugSubscriptionMode: String, CaseIterable, Identifiable {
    case pro
    case free
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pro: return "Pro"
        case .free: return "Free"
        case .system: return "System"
        }
    }
}
#endif

@MainActor
final class SubscriptionService: ObservableObject {

    static let shared = SubscriptionService()

    // MARK: - Public state

    enum SubscriptionTier {
        case free
        case premium
    }

    @Published private(set) var tier: SubscriptionTier = .free
    @Published private(set) var productDetails: SubscriptionProductDetails?
    @Published private(set) var actionState: SubscriptionActionState = .idle
    @Published private(set) var isLoadingProducts = false

    #if DEBUG
    @Published var debugMode: DebugSubscriptionMode {
        didSet {
            if persistsDebugModeChanges {
                UserDefaults.standard.set(debugMode.rawValue, forKey: Self.debugModeKey)
            }
        }
    }

    private let persistsDebugModeChanges: Bool
    private static let debugModeKey = "fitup.debug.subscriptionMode"
    #endif

    /// Feature access gate. Release always mirrors StoreKit entitlement.
    var isPremium: Bool {
        #if DEBUG
        switch debugMode {
        case .pro: return true
        case .free: return false
        case .system: return tier == .premium
        }
        #else
        return tier == .premium
        #endif
    }

    /// Raw StoreKit entitlement, ignoring Debug Free/Pro overrides.
    var isSubscribed: Bool {
        tier == .premium
    }

    /// Whether the current user is eligible to have the paywall shown.
    /// Per spec: paywall is never shown before the user completes their first match.
    var canShowPaywall: Bool {
        UserDefaults.standard.bool(forKey: "hasCompletedFirstMatch")
    }

    /// Whether the user can open a new challenge / matchmaking request.
    /// Free tier: limited to 1 open slot (searching + pending + active combined).
    func canCreateMatch(usedSlots: Int) -> Bool {
        if isPremium { return true }
        return usedSlots < SubscriptionConfig.freeOpenMatchSlots
    }

    /// Localized StoreKit price when loaded; nil if the product failed to load.
    var monthlyDisplayPrice: String? {
        productDetails?.monthlyDisplayPrice
    }

    var isBusy: Bool {
        actionState == .purchasing || actionState == .restoring
    }

    // MARK: - First match tracking

    /// Called by MatchDetailsViewModel when the current user wins a completed match.
    func markFirstMatchWon() {
        UserDefaults.standard.set(true, forKey: "firstMatchWon")
        UserDefaults.standard.set(true, forKey: "hasCompletedFirstMatch")
    }

    /// Called when any match completes (win or loss), so the paywall can be shown on next challenge entry.
    func markFirstMatchCompleted() {
        UserDefaults.standard.set(true, forKey: "hasCompletedFirstMatch")
    }

    // MARK: - StoreKit 2

    private let storeClient: SubscriptionStoreClient
    private var transactionListener: Task<Void, Never>?

    init(
        storeClient: SubscriptionStoreClient? = nil,
        listenForTransactions: Bool = true,
        automaticallyRefresh: Bool = false,
        persistsDebugModeChanges: Bool = true
    ) {
        self.storeClient = storeClient ?? LiveSubscriptionStoreClient()

        #if DEBUG
        self.persistsDebugModeChanges = persistsDebugModeChanges
        let savedMode = UserDefaults.standard.string(forKey: Self.debugModeKey)
            .flatMap(DebugSubscriptionMode.init(rawValue:))
        debugMode = savedMode ?? .pro
        #else
        _ = persistsDebugModeChanges
        #endif

        if listenForTransactions {
            transactionListener = Task { [weak self] in
                for await update in Transaction.updates {
                    guard let self else { return }
                    if case .verified(let transaction) = update {
                        await transaction.finish()
                        await self.refreshEntitlement()
                    }
                }
            }
        }

        if automaticallyRefresh {
            Task { await refresh() }
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    /// Loads products and refreshes entitlement from StoreKit.
    func refresh() async {
        await loadProducts()
        await refreshEntitlement()
    }

    /// Refreshes the cached entitlement from `Transaction.currentEntitlements`.
    func refreshEntitlement() async {
        let entitled = await storeClient.hasActiveProEntitlement()
        tier = entitled ? .premium : .free
    }

    /// Fetches StoreKit products by exact Product ID.
    @discardableResult
    func loadProducts() async -> SubscriptionProductDetails? {
        guard !isLoadingProducts else { return productDetails }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let details = try await storeClient.loadProducts()
            productDetails = details
            if details.monthlyDisplayPrice == nil {
                PaywallLogger.log(
                    level: .warning,
                    message: "StoreKit product load returned no matching products"
                )
            }
            return details
        } catch {
            productDetails = nil
            PaywallLogger.log(
                level: .warning,
                message: "StoreKit product load failed",
                metadata: ["error": error.localizedDescription]
            )
            return nil
        }
    }

    /// Purchases the given plan and refreshes entitlement.
    @discardableResult
    func purchase(plan: SubscriptionPlan) async -> SubscriptionActionState {
        guard !isBusy else { return actionState }

        if productDetails == nil {
            await loadProducts()
        }

        actionState = .purchasing
        do {
            switch try await storeClient.purchase(plan) {
            case .purchased:
                await refreshEntitlement()
                actionState = tier == .premium
                    ? .purchased
                    : .failed("The purchase completed, but Pro access could not be verified yet. Try Restore Purchases.")
            case .pending:
                actionState = .pending
            case .cancelled:
                actionState = .cancelled
            }
        } catch {
            actionState = .failed("The purchase couldn’t be completed. Please try again.")
            PaywallLogger.log(
                level: .warning,
                message: "StoreKit purchase failed",
                metadata: ["plan": plan.rawValue, "error": error.localizedDescription]
            )
        }
        return actionState
    }

    /// Restores previous purchases via `AppStore.sync()` and refreshes entitlement.
    @discardableResult
    func restorePurchases() async -> SubscriptionActionState {
        guard !isBusy else { return actionState }

        actionState = .restoring
        do {
            try await storeClient.restorePurchases()
            await refreshEntitlement()
            actionState = tier == .premium ? .restored : .noActiveSubscription
        } catch {
            actionState = .failed("Purchases couldn’t be restored right now. Please try again.")
            PaywallLogger.log(
                level: .warning,
                message: "StoreKit restore failed",
                metadata: ["error": error.localizedDescription]
            )
        }
        return actionState
    }
}
