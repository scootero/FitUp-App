//
//  DevMode.swift
//  FitUp
//
//  Central switch for internal beta (TestFlight) vs production.
//  Controlled by FITUP_TESTFLIGHT_BYPASS in Config/BetaFlags.xcconfig → Info.plist.
//

import Foundation

enum DevMode {
    static let userDefaultsKey = "devMode"
    private static let infoPlistKey = "FITUP_TESTFLIGHT_BYPASS"

    /// Build was archived with `FITUP_TESTFLIGHT_BYPASS = YES` in BetaFlags.xcconfig.
    static var isTestFlightBypassBuild: Bool {
        parseBool(Bundle.main.object(forInfoDictionaryKey: infoPlistKey))
    }

    /// Dev tools UI may appear (Xcode Debug, or TestFlight bypass build).
    static var isAvailable: Bool {
        #if DEBUG
        return true
        #else
        return isTestFlightBypassBuild
        #endif
    }

    /// Paywall bypass and dev-tool content are active.
    static var isActive: Bool {
        guard isAvailable else { return false }
        if isTestFlightBypassBuild {
            return true
        }
        return UserDefaults.standard.bool(forKey: userDefaultsKey)
    }

    /// Persists Dev Mode on for TestFlight bypass builds (idempotent).
    static func bootstrapOnLaunch() {
        guard isTestFlightBypassBuild else { return }
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
    }

    private static func parseBool(_ value: Any?) -> Bool {
        switch value {
        case let flag as Bool:
            return flag
        case let number as NSNumber:
            return number.boolValue
        case let string as String:
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "yes", "true":
                return true
            default:
                return false
            }
        default:
            return false
        }
    }
}
