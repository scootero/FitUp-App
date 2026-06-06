//
//  HealthKitSyncDiagnostics.swift
//  FitUp
//
//  Phase 1 diagnostics for HKErrorCode 6 / protected health data unavailable.
//

import Foundation
import HealthKit
import SwiftUI
import UIKit

// MARK: - HK error helpers

extension HKError {
    var isProtectedDataUnavailable: Bool {
        code == .errorHealthDataUnavailable
    }
}

extension Error {
    var isHealthKitProtectedDataUnavailable: Bool {
        (self as? HKError)?.isProtectedDataUnavailable == true
    }
}

// MARK: - Environment snapshot

struct HealthKitEnvironmentSnapshot: Sendable {
    let scenePhase: String
    let isProtectedDataAvailable: Bool
    let protectedDataLikely: Bool
    let healthDataAvailable: Bool
    let stepsAuthStatus: String
    let activeEnergyAuthStatus: String

    @MainActor
    static func capture(scenePhase: ScenePhase) -> HealthKitEnvironmentSnapshot {
        let auth = HealthKitService.authorizationSnapshot()
        let protected = UIApplication.shared.isProtectedDataAvailable
        return HealthKitEnvironmentSnapshot(
            scenePhase: scenePhaseLabel(scenePhase),
            isProtectedDataAvailable: protected,
            protectedDataLikely: !protected,
            healthDataAvailable: HKHealthStore.isHealthDataAvailable(),
            stepsAuthStatus: auth["steps_auth_status"] ?? "unknown",
            activeEnergyAuthStatus: auth["active_energy_auth_status"] ?? "unknown"
        )
    }

    @MainActor
    static func captureStored(scenePhaseRaw: String) -> HealthKitEnvironmentSnapshot {
        let auth = HealthKitService.authorizationSnapshot()
        let protected = UIApplication.shared.isProtectedDataAvailable
        return HealthKitEnvironmentSnapshot(
            scenePhase: scenePhaseRaw,
            isProtectedDataAvailable: protected,
            protectedDataLikely: !protected,
            healthDataAvailable: HKHealthStore.isHealthDataAvailable(),
            stepsAuthStatus: auth["steps_auth_status"] ?? "unknown",
            activeEnergyAuthStatus: auth["active_energy_auth_status"] ?? "unknown"
        )
    }

    var metadata: [String: String] {
        [
            "scene_phase": scenePhase,
            "is_protected_data_available": "\(isProtectedDataAvailable)",
            "protected_data_likely": "\(protectedDataLikely)",
            "health_data_available": "\(healthDataAvailable)",
            "steps_auth_status": stepsAuthStatus,
            "active_energy_auth_status": activeEnergyAuthStatus,
            "auth_note": "read_status_approximate",
        ]
    }

    private static func scenePhaseLabel(_ phase: ScenePhase) -> String {
        switch phase {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - Day sync counters

struct HealthKitDaySyncCounts: Sendable {
    var ok: Int = 0
    var skipped: Int = 0
    var skippedHK6: Int = 0
}

struct MatchDaySyncResult: Sendable {
    let writes: [MatchDaySyncWrite]
    let writesSkippedNil: Int
}

// MARK: - Sync session accumulator

final class HealthKitSyncSession: @unchecked Sendable {
    var hkError6Count = 0
    var hkQueryCount = 0
    var hkQueryFailCount = 0

    var stepsReadOk = false
    var caloriesReadOk = false
    var intradayTickOutcome = "not_attempted"
    var publicDailyAttempted = false
    var publicDailyWritten = false
    var matchWrites = 0
    var historicalConfirmed = 0
    var historicalSkipped = 0
    var dailyTotalsDaysOk = 0
    var dailyTotalsDaysSkipped = 0
    var dailyTotalsDaysSkippedHK6 = 0
    var battleDaysOk = 0
    var battleDaysSkipped = 0
    var battleDaysSkippedHK6 = 0
    var baselinesAttempted = false
    var snapshotWrites = 0
    var writesSkippedNil = 0
    var nilPreventedPublicDaily = 0
    var nilPreventedBaselines = 0
    var observerPreReadQueryCount = 0

    func recordQueryStart() {
        hkQueryCount += 1
    }

    func recordQueryFailure(_ error: Error) {
        hkQueryFailCount += 1
        if HealthKitService.hkErrorRawCode(error) == 6 {
            hkError6Count += 1
        }
    }

    func recordQuerySuccess(quantityIdentifier: HKQuantityTypeIdentifier) {
        HealthKitDiagnosticsStore.markHKReadSuccess(quantityIdentifier: quantityIdentifier)
    }

    var summaryMetadata: [String: String] {
        [
            "hk_error_6_count": "\(hkError6Count)",
            "steps_read_ok": "\(stepsReadOk)",
            "calories_read_ok": "\(caloriesReadOk)",
            "writes_skipped_nil": "\(writesSkippedNil)",
            "battle_days_skipped": "\(battleDaysSkipped)",
            "daily_days_skipped": "\(dailyTotalsDaysSkipped)",
            "intraday_tick": intradayTickOutcome,
            "snapshot_writes": "\(snapshotWrites)",
            "historical_confirmed": "\(historicalConfirmed)",
            "historical_skipped": "\(historicalSkipped)",
            "public_daily_written": "\(publicDailyWritten)",
            "hk_query_count": "\(hkQueryCount)",
            "hk_query_fail_count": "\(hkQueryFailCount)",
            "daily_totals_days_ok": "\(dailyTotalsDaysOk)",
            "daily_totals_days_skipped_hk6": "\(dailyTotalsDaysSkippedHK6)",
            "battle_days_ok": "\(battleDaysOk)",
            "battle_days_skipped_hk6": "\(battleDaysSkippedHK6)",
            "baselines_attempted": "\(baselinesAttempted)",
            "nil_prevented_public_daily": "\(nilPreventedPublicDaily)",
            "nil_prevented_baselines": "\(nilPreventedBaselines)",
            "observer_pre_read_query_count": "\(observerPreReadQueryCount)",
        ]
    }
}

// MARK: - Session context (shared across sync + HealthKitService)

enum HealthKitSyncSessionContext {
    private static let lock = NSLock()
    private static var activeSession: HealthKitSyncSession?

    static var hasActiveSession: Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeSession != nil
    }

    static func begin() -> HealthKitSyncSession {
        let session = HealthKitSyncSession()
        lock.lock()
        activeSession = session
        lock.unlock()
        return session
    }

    static func end() {
        lock.lock()
        activeSession = nil
        lock.unlock()
    }

    static func withActiveSession(_ body: (HealthKitSyncSession) -> Void) {
        lock.lock()
        let session = activeSession
        lock.unlock()
        guard let session else { return }
        body(session)
    }
}

// MARK: - Persisted timestamps + UI source

enum HealthKitDiagnosticsStore {
    private static let prefix = "fitup.hkDiagnostics.v1."
    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    private static var homeHeroStepsSourceKey: String { prefix + "home_hero_steps_source" }

    static var homeHeroStepsSource: String {
        get { UserDefaults.standard.string(forKey: homeHeroStepsSourceKey) ?? "unknown" }
        set { UserDefaults.standard.set(newValue, forKey: homeHeroStepsSourceKey) }
    }

    static func markHKReadSuccess(quantityIdentifier: HKQuantityTypeIdentifier) {
        let now = Date()
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: prefix + "last_hk_read_at")
        if quantityIdentifier == .stepCount {
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: prefix + "last_hk_steps_read_at")
        }
    }

    static func markBackendWriteSuccess() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: prefix + "last_backend_write_at")
    }

    static var lastSuccessfulHKReadAt: String {
        formattedTimestamp(key: prefix + "last_hk_read_at")
    }

    static var lastSuccessfulHKStepsReadAt: String {
        formattedTimestamp(key: prefix + "last_hk_steps_read_at")
    }

    static var lastSuccessfulBackendWriteAt: String {
        formattedTimestamp(key: prefix + "last_backend_write_at")
    }

    static var timestampMetadata: [String: String] {
        [
            "last_successful_hk_read_at": lastSuccessfulHKReadAt,
            "last_successful_hk_steps_read_at": lastSuccessfulHKStepsReadAt,
            "last_successful_backend_write_at": lastSuccessfulBackendWriteAt,
            "home_hero_steps_source": homeHeroStepsSource,
        ]
    }

    private static func formattedTimestamp(key: String) -> String {
        guard let interval = UserDefaults.standard.object(forKey: key) as? Double else {
            return "never"
        }
        return iso8601.string(from: Date(timeIntervalSince1970: interval))
    }
}
