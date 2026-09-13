//
//  FitUpAppLinks.swift
//  FitUp
//
//  Canonical public URLs / support contacts for Profile, paywall, and invites.
//

import Foundation

enum FitUpAppLinks {
    static let privacyPolicyURL = "https://scootero.github.io/FitUp-App/privacy/"
    static let termsOfUseURL = "https://scootero.github.io/FitUp-App/terms/"
    /// Replace with the live App Store product URL once the listing is live.
    static let appStoreURL = "https://apps.apple.com/app/fitup"
    static let supportEmail = "oliverscott14@gmail.com"
    static let supportMailtoURL = "mailto:oliverscott14@gmail.com"

    static var inviteFriendShareText: String {
        "Battle me on FitUp — download the app and let's compete: \(appStoreURL)"
    }
}

/// Launch feature gates (App Store readiness).
enum AppLaunchFlags {
    /// Hide in-app DMs until messaging backend + UGC report/block are ready for review.
    static let messagingEnabled = false
}
