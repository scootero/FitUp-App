//
//  PaywallLogger.swift
//  FitUp
//
//  RevenueCat / paywall logging gated by FITUP_REVENUECAT_LOGGING in BetaFlags.xcconfig.
//

import Foundation
import RevenueCat

enum PaywallLogger {
    private static let infoPlistKey = "FITUP_REVENUECAT_LOGGING"
    private static let logCategory = "paywall"

    /// FitUp `AppLogger` + console paywall lines (see BetaFlags.xcconfig).
    static var isEnabled: Bool {
        parseBool(Bundle.main.object(forInfoDictionaryKey: infoPlistKey))
    }

    /// RevenueCat SDK should configure and sync entitlements (off during TestFlight bypass).
    static var shouldUseRevenueCat: Bool {
        !DevMode.isTestFlightBypassBuild
    }

    /// Call before `Purchases.configure`.
    static func applySDKLogLevel() {
        Purchases.logLevel = isEnabled ? .debug : .error
    }

    static func log(
        level: LogLevel = .info,
        message: String,
        userId: UUID? = nil,
        metadata: [String: String]? = nil
    ) {
        guard isEnabled else { return }
        AppLogger.log(
            category: logCategory,
            level: level,
            message: message,
            userId: userId,
            metadata: metadata
        )
    }

    static func debug(_ message: String, userId: UUID? = nil, metadata: [String: String]? = nil) {
        log(level: .debug, message: message, userId: userId, metadata: metadata)
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
