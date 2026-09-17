//
//  SubscriptionConfig.swift
//  FitUp
//
//  Fixed Product ID and free-tier constants for FitOff Pro (native StoreKit 2).
//

import Foundation

enum SubscriptionConfig {
    /// Must match the App Store Connect Product ID exactly.
    static let monthlyProductID = "com.ScottOliver.FitUp.Monthly"

    static let allProductIDs: Set<String> = [monthlyProductID]

    /// Free users may have this many open match slots (searching + pending + active).
    static let freeOpenMatchSlots = 1

    static let displayName = "FitOff Pro"

    /// Customer-facing benefit. Must stay aligned with the App Store subscription description.
    static let benefitDescription = "Unlimited simultaneous matches."

    /// Debug / docs only — never present this as a live App Store price.
    static let monthlyPriceFallback = "$2.99/month"

    static let unavailablePriceLabel = "Unavailable"
}

enum SubscriptionPlan: String, Sendable {
    case monthly

    var productID: String {
        SubscriptionConfig.monthlyProductID
    }
}
