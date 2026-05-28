//
//  LegacyStatsFeature.swift
//  FitUp
//
//  Feature flag for pre-arcade stats UI and data loading. Flip to `true` for internal debugging.
//

import Foundation

enum LegacyStatsFeature {
    /// When false, legacy stats UI and fetches are disabled (TestFlight / production default).
    static let isEnabled = false
}
