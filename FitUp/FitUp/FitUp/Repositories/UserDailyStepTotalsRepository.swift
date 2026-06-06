//
//  UserDailyStepTotalsRepository.swift
//  FitUp
//
//  Upserts HealthKit full-day step totals into `user_daily_step_totals` for leaderboard sourcing.
//  Each sync refreshes a rolling **7** profile-local calendar days (today + prior 6); older dates
//  already in the table remain until optional server retention prunes them.
//  SQL: `supabase/manual_sql/user_daily_step_totals_create_table_rls.sql`
//

import Foundation
import HealthKit
import Supabase

enum UserDailyStepTotalsRepositoryError: Error {
    case supabaseNotConfigured
}

final class UserDailyStepTotalsRepository {
    private static let rollingDayCount = 7

    private var client: SupabaseClient {
        get throws {
            guard let client = SupabaseProvider.client else {
                throw UserDailyStepTotalsRepositoryError.supabaseNotConfigured
            }
            return client
        }
    }

    /// Refreshes the last **7** profile-local calendar days (including today) from HealthKit and upserts one row per day.
    func syncRollingSevenCalendarDays(profile: Profile) async throws -> HealthKitDaySyncCounts {
        var counts = HealthKitDaySyncCounts()
        let tzId = profile.timezone
        let timeZone = (tzId.flatMap { TimeZone(identifier: $0) }) ?? .current
        let tzIdentifier = timeZone.identifier

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = Date()
        guard let todayStart = calendar.dateInterval(of: .day, for: now)?.start else { return counts }

        var rows: [UserDailyStepTotalUpsertRow] = []
        let updatedAt = Self.isoFormatter.string(from: Date())

        for offset in 0 ..< Self.rollingDayCount {
            guard let dayStart = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            let calendarDateStr = PublicDailyActivityRepository.localCalendarDateString(
                for: dayStart,
                timeZoneIdentifier: tzId
            )

            let steps: Int
            do {
                steps = try await HealthKitService.fetchMetricTotal(
                    metricType: .steps,
                    for: dayStart,
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
                    message: "user_daily_step_totals: skipped day (HealthKit read failed)",
                    userId: profile.id,
                    metadata: [
                        "calendar_date": calendarDateStr,
                        "error": error.localizedDescription,
                        "hk_error_code": (error as? HKError).map { "\($0.code.rawValue)" } ?? "n/a",
                    ]
                )
                continue
            }

            counts.ok += 1
            rows.append(
                UserDailyStepTotalUpsertRow(
                    userId: profile.id,
                    calendarDate: calendarDateStr,
                    timezoneIdentifier: tzIdentifier,
                    steps: max(0, steps),
                    updatedAt: updatedAt
                )
            )
        }

        guard !rows.isEmpty else { return counts }

        let c = try client
        try await c
            .from("user_daily_step_totals")
            .upsert(rows, onConflict: "user_id,calendar_date")
            .execute()
        HealthKitDiagnosticsStore.markBackendWriteSuccess()
        return counts
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

private struct UserDailyStepTotalUpsertRow: Encodable, Sendable {
    let userId: UUID
    let calendarDate: String
    let timezoneIdentifier: String
    let steps: Int
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case calendarDate = "calendar_date"
        case timezoneIdentifier = "timezone_identifier"
        case steps
        case updatedAt = "updated_at"
    }
}
