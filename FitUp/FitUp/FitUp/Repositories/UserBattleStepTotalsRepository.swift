//
//  UserBattleStepTotalsRepository.swift
//  FitUp
//
//  Cumulative Battle Steps — materialized per battle calendar day (`user_battle_step_totals`).
//  SQL: `supabase/manual_sql/user_battle_step_totals_create_table_rpcs.sql`
//

import Foundation
import HealthKit
import Supabase

enum UserBattleStepTotalsRepositoryError: Error {
    case supabaseNotConfigured
}

struct CumulativeBattleStepsSnapshot: Sendable {
    let finalizedTotal: Int
    let finalizedBattleDayCount: Int
    let averageFinalizedBattleDaySteps: Int
    let isTodayBattleDay: Bool
    let isTodayFinalized: Bool
}

final class UserBattleStepTotalsRepository {
    private static let rollingDayCount = 7

    private var client: SupabaseClient {
        get throws {
            guard let client = SupabaseProvider.client else {
                throw UserBattleStepTotalsRepositoryError.supabaseNotConfigured
            }
            return client
        }
    }

    func fetchCumulativeBattleSteps() async -> CumulativeBattleStepsSnapshot? {
        guard let client = SupabaseProvider.client else { return nil }
        do {
            let response: PostgrestResponse<CumulativeBattleStepsRPCResult> = try await client
                .rpc("get_cumulative_battle_steps")
                .execute()
            let row = response.value
            return CumulativeBattleStepsSnapshot(
                finalizedTotal: max(0, row.finalizedTotalInt),
                finalizedBattleDayCount: max(0, row.finalizedBattleDayCountInt),
                averageFinalizedBattleDaySteps: max(0, row.averageFinalizedBattleDayStepsInt),
                isTodayBattleDay: row.is_today_battle_day,
                isTodayFinalized: row.is_today_finalized
            )
        } catch {
            if error is CancellationError { return nil }
            AppLogger.log(
                category: "healthkit_sync",
                level: .warning,
                message: "get_cumulative_battle_steps rpc failed",
                metadata: ["error": error.localizedDescription]
            )
            return nil
        }
    }

    /// Absolute HealthKit steps for battle days in the rolling 7-day window (provisional rows only).
    func syncProvisionalBattleDays(
        profile: Profile,
        battleDateKeys: Set<String>
    ) async -> HealthKitDaySyncCounts {
        var counts = HealthKitDaySyncCounts()
        guard !battleDateKeys.isEmpty else { return counts }

        let tzId = profile.timezone
        let timeZone = (tzId.flatMap { TimeZone(identifier: $0) }) ?? .current

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = Date()
        guard let todayStart = calendar.dateInterval(of: .day, for: now)?.start else { return counts }

        var eligibleKeys: [String] = []
        for offset in 0 ..< Self.rollingDayCount {
            guard let dayStart = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            let key = PublicDailyActivityRepository.localCalendarDateString(
                for: dayStart,
                timeZoneIdentifier: tzId
            )
            if battleDateKeys.contains(key) {
                eligibleKeys.append(key)
            }
        }
        guard !eligibleKeys.isEmpty else { return counts }

        do {
            let c = try client
            for key in eligibleKeys {
                guard
                    let dayDate = dateFromCalendarDateKey(key, timeZone: timeZone)
                else { continue }

                let steps: Int
                do {
                    steps = try await HealthKitService.fetchMetricTotal(
                        metricType: .steps,
                        for: dayDate,
                        timeZone: timeZone
                    )
                } catch {
                    counts.skipped += 1
                    if HealthKitService.hkErrorRawCode(error) == 6 {
                        counts.skippedHK6 += 1
                    }
                    let logLevel: LogLevel = HealthKitSyncSessionContext.hasActiveSession ? .debug : .warning
                    AppLogger.log(
                        category: "healthkit_sync",
                        level: logLevel,
                        message: "user_battle_step_totals: skipped day (HealthKit read failed)",
                        userId: profile.id,
                        metadata: [
                            "battle_date": key,
                            "error": error.localizedDescription,
                            "hk_error_code": (error as? HKError).map { "\($0.code.rawValue)" } ?? "n/a",
                        ]
                    )
                    continue
                }

                let params = ProvisionalBattleStepRPCParams(
                    p_battle_date: key,
                    p_steps: max(0, steps)
                )
                try await c
                    .rpc("upsert_provisional_user_battle_step", params: params)
                    .execute()
                counts.ok += 1
                HealthKitDiagnosticsStore.markBackendWriteSuccess()
            }
        } catch {
            AppLogger.log(
                category: "healthkit_sync",
                level: .warning,
                message: "user_battle_step_totals provisional sync failed",
                userId: profile.id,
                metadata: ["error": error.localizedDescription]
            )
        }
        return counts
    }

    private func dateFromCalendarDateKey(_ key: String, timeZone: TimeZone) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let d = Int(parts[2])
        else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: y, month: m, day: d))
    }
}

private struct ProvisionalBattleStepRPCParams: Sendable {
    let p_battle_date: String
    let p_steps: Int
}

extension ProvisionalBattleStepRPCParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_battle_date, forKey: .p_battle_date)
        try c.encode(p_steps, forKey: .p_steps)
    }

    enum CodingKeys: String, CodingKey {
        case p_battle_date
        case p_steps
    }
}

private struct CumulativeBattleStepsRPCResult: Decodable, Sendable {
    let finalized_total: Int64
    let finalized_battle_day_count: Int64?
    let average_finalized_battle_day_steps: Int64?
    let is_today_battle_day: Bool
    let is_today_finalized: Bool

    var finalizedTotalInt: Int {
        if finalized_total > Int64(Int.max) { return Int.max }
        return Int(finalized_total)
    }

    var finalizedBattleDayCountInt: Int {
        guard let finalized_battle_day_count else { return 0 }
        if finalized_battle_day_count > Int64(Int.max) { return Int.max }
        return Int(finalized_battle_day_count)
    }

    var averageFinalizedBattleDayStepsInt: Int {
        guard let average_finalized_battle_day_steps else { return 0 }
        if average_finalized_battle_day_steps > Int64(Int.max) { return Int.max }
        return Int(average_finalized_battle_day_steps)
    }
}
