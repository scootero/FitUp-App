//
//  SubscriptionService.swift
//  FitUp
//
//  Slice 13 — centralised RevenueCat entitlement wrapper.
//  Dev Mode (debug-only) short-circuits all premium checks to true.
//

import Combine
import Foundation
import RevenueCat

@MainActor
final class SubscriptionService: ObservableObject {

    static let shared = SubscriptionService()

    // MARK: - Public state

    enum SubscriptionTier {
        case free
        case premium
    }

    @Published private(set) var tier: SubscriptionTier = .free

    /// True if the user has a premium entitlement, OR if Dev Mode is on (debug builds only).
    var isPremium: Bool {
#if DEBUG
        if UserDefaults.standard.bool(forKey: "devMode") { return true }
#endif
        return tier == .premium
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
        return usedSlots < 1
    }

    // MARK: - First match tracking

    /// Called by MatchDetailsViewModel when the current user wins a completed match.
    /// Sets both the first-win and first-completion flags so the paywall and soft-upsell can activate.
    func markFirstMatchWon() {
        UserDefaults.standard.set(true, forKey: "firstMatchWon")
        UserDefaults.standard.set(true, forKey: "hasCompletedFirstMatch")
    }

    /// Called when any match completes (win or loss), so the paywall can be shown on next challenge entry.
    func markFirstMatchCompleted() {
        UserDefaults.standard.set(true, forKey: "hasCompletedFirstMatch")
    }

    // MARK: - RevenueCat

    /// Refreshes the cached entitlement from RevenueCat.
    /// Called on app launch and after any purchase or restore.
    func refreshEntitlement() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            tier = info.entitlements["pro"]?.isActive == true ? .premium : .free
        } catch {
            AppLogger.log(
                category: "paywall",
                level: .warning,
                message: "entitlement refresh failed",
                metadata: ["error": error.localizedDescription]
            )
        }
    }

    /// Fetches the current RevenueCat offering packages.
    /// Returns an empty array if the SDK isn't configured or has no offering.
    func fetchOffering() async -> [RevenueCat.Package] {
        do {
            let offerings = try await Purchases.shared.offerings()
            return offerings.current?.availablePackages ?? []
        } catch {
            AppLogger.log(
                category: "paywall",
                level: .warning,
                message: "offerings fetch failed",
                metadata: ["error": error.localizedDescription]
            )
            return []
        }
    }

    /// Purchases the given RevenueCat package and refreshes the tier.
    func purchase(package: RevenueCat.Package) async throws {
        let result = try await Purchases.shared.purchase(package: package)
        tier = result.customerInfo.entitlements["pro"]?.isActive == true ? .premium : .free
        AppLogger.log(
            category: "paywall",
            level: .info,
            message: "purchase completed",
            metadata: ["package": package.identifier, "tier": tier == .premium ? "premium" : "free"]
        )
    }

    /// Restores previous purchases and refreshes the tier.
    func restorePurchases() async throws {
        let info = try await Purchases.shared.restorePurchases()
        tier = info.entitlements["pro"]?.isActive == true ? .premium : .free
        AppLogger.log(
            category: "paywall",
            level: .info,
            message: "restore completed",
            metadata: ["tier": tier == .premium ? "premium" : "free"]
        )
    }

    // MARK: - Private init (singleton)

    private init() {}
}
