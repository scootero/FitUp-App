//
//  SubscriptionConfig.swift
//  FitUp
//
//  Fixed Product IDs and free-tier constants for FitUp Pro (native StoreKit 2).
//

import Foundation

enum SubscriptionConfig {
    /// Must match App Store Connect Product IDs exactly.
    static let monthlyProductID = "fitup_pro_monthly"
    static let annualProductID = "fitup_pro_annual"

    static let allProductIDs: Set<String> = [monthlyProductID, annualProductID]

    /// Free users may have this many open match slots (searching + pending + active).
    static let freeOpenMatchSlots = 1

    static let displayName = "FitUp Pro"

    static let monthlyPriceFallback = "$4.99/month"
    static let annualPriceFallback = "$29.99/year"
}

enum SubscriptionPlan: String, Sendable {
    case monthly
    case annual

    var productID: String {
        switch self {
        case .monthly: return SubscriptionConfig.monthlyProductID
        case .annual: return SubscriptionConfig.annualProductID
        }
    }
}
