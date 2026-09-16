//
//  PaywallLogger.swift
//  FitUp
//
//  Paywall / StoreKit logging gated by FITUP_PAYWALL_LOGGING in BetaFlags.xcconfig.
//

import Foundation

enum PaywallLogger {
    private static let infoPlistKey = "FITUP_PAYWALL_LOGGING"
    /// Legacy key kept so older archives still honor the flag until rebuild.
    private static let legacyInfoPlistKey = "FITUP_REVENUECAT_LOGGING"
    private static let logCategory = "paywall"

    /// FitUp `AppLogger` + console paywall lines (see BetaFlags.xcconfig).
    static var isEnabled: Bool {
        parseBool(Bundle.main.object(forInfoDictionaryKey: infoPlistKey))
            || parseBool(Bundle.main.object(forInfoDictionaryKey: legacyInfoPlistKey))
    }

    /// StoreKit should sync entitlements (off during TestFlight bypass).
    static var shouldUseStoreKit: Bool {
        !DevMode.isTestFlightBypassBuild
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
