//
//  HealthRepository.swift
//  FitUp
//
//  Slice 12 — All-time bests from Supabase (`all_time_bests` public read RLS).
//

import Combine
import Foundation
import Supabase

/// Raw all-time bests from HealthKit (best single day + best rolling 7-day window).
struct HealthKitAllTimeBests: Equatable {
    var stepsBestDay: Int?
    var stepsBestWeek: Int?
    var calsBestDay: Int?
    var calsBestWeek: Int?

    static let empty = HealthKitAllTimeBests(
        stepsBestDay: nil,
        stepsBestWeek: nil,
        calsBestDay: nil,
        calsBestWeek: nil
    )
}

struct HealthAllTimeBests: Equatable {
    var stepsBestDay: String
    var stepsBestDaySub: String
    var stepsBestWeek: String
    var stepsBestWeekSub: String
    var calsBestDay: String
    var calsBestDaySub: String
    var calsBestWeek: String
    var calsBestWeekSub: String
    var bestWinStreakDays: Int?

    static let empty = HealthAllTimeBests(
        stepsBestDay: "—",
        stepsBestDaySub: "No data",
        stepsBestWeek: "—",
        stepsBestWeekSub: "No data",
        calsBestDay: "—",
        calsBestDaySub: "No data",
        calsBestWeek: "—",
        calsBestWeekSub: "No data",
        bestWinStreakDays: nil
    )

    /// Prefer Apple Health for steps/calorie records; keep win streak from Supabase.
    static func merged(healthKit: HealthKitAllTimeBests, remote: HealthAllTimeBests) -> HealthAllTimeBests {
        let stepsDay = Self.formatStepsPair(healthKit.stepsBestDay, sub: "steps · best day")
            ?? (remote.stepsBestDay, remote.stepsBestDaySub)
        let stepsWeek = Self.formatStepsPair(healthKit.stepsBestWeek, sub: "steps · best week")
            ?? (remote.stepsBestWeek, remote.stepsBestWeekSub)
        let calsDay = Self.formatCalsPair(healthKit.calsBestDay, sub: "cal · best day")
            ?? (remote.calsBestDay, remote.calsBestDaySub)
        let calsWeek = Self.formatCalsPair(healthKit.calsBestWeek, sub: "cal · best week")
            ?? (remote.calsBestWeek, remote.calsBestWeekSub)
        return HealthAllTimeBests(
            stepsBestDay: stepsDay.0,
            stepsBestDaySub: stepsDay.1,
            stepsBestWeek: stepsWeek.0,
            stepsBestWeekSub: stepsWeek.1,
            calsBestDay: calsDay.0,
            calsBestDaySub: calsDay.1,
            calsBestWeek: calsWeek.0,
            calsBestWeekSub: calsWeek.1,
            bestWinStreakDays: remote.bestWinStreakDays
        )
    }

    private static func formatStepsPair(_ v: Int?, sub: String) -> (String, String)? {
        guard let v, v > 0 else { return nil }
        let s: String
        if v >= 1000 {
            s = String(format: "%.1fk", Double(v) / 1000)
        } else {
            s = "\(v)"
        }
        return (s, sub)
    }

    private static func formatCalsPair(_ v: Int?, sub: String) -> (String, String)? {
        guard let v, v > 0 else { return nil }
        let s: String
        if v >= 1000 {
            s = String(format: "%.1fk", Double(v) / 1000)
        } else {
            s = "\(v)"
        }
        return (s, sub)
    }
}

final class HealthRepository {
    func fetchAllTimeBests(userId: UUID) async -> HealthAllTimeBests {
        guard let client = SupabaseProvider.client else { return .empty }

        do {
            let response = try await client
                .from("all_time_bests")
                .select("steps_best_day, steps_best_week, cals_best_day, cals_best_week, best_win_streak_days")
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()

            guard let row = jsonRows(from: response.data).first else {
                return .empty
            }

            let sd = double(from: row["steps_best_day"])
            let sw = double(from: row["steps_best_week"])
            let cd = double(from: row["cals_best_day"])
            let cw = double(from: row["cals_best_week"])
            let streak = int(from: row["best_win_streak_days"])

            return HealthAllTimeBests(
                stepsBestDay: formatSteps(sd),
                stepsBestDaySub: "steps · best day",
                stepsBestWeek: formatSteps(sw),
                stepsBestWeekSub: "steps · best week",
                calsBestDay: formatCals(cd),
                calsBestDaySub: "cal · best day",
                calsBestWeek: formatCals(cw),
                calsBestWeekSub: "cal · best week",
                bestWinStreakDays: streak
            )
        } catch {
            AppLogger.log(
                category: "network",
                level: .warning,
                message: "all_time_bests load failed",
                metadata: ["error": error.localizedDescription]
            )
            return .empty
        }
    }

    private func formatSteps(_ v: Double?) -> String {
        guard let v, v > 0 else { return "—" }
        if v >= 1000 {
            return String(format: "%.1fk", v / 1000)
        }
        return "\(Int(v.rounded()))"
    }

    private func formatCals(_ v: Double?) -> String {
        guard let v, v > 0 else { return "—" }
        if v >= 1000 {
            return String(format: "%.1fk", v / 1000)
        }
        return "\(Int(v.rounded()))"
    }

    private func int(from value: Any?) -> Int? {
        switch value {
        case let n as Int:
            return n
        case let n as Double:
            return Int(n)
        case let s as String:
            return Int(s)
        default:
            return nil
        }
    }

    private func double(from value: Any?) -> Double? {
        switch value {
        case let n as Double:
            return n
        case let n as Int:
            return Double(n)
        case let s as String:
            return Double(s)
        default:
            return nil
        }
    }

    private func jsonRows(from data: Data) -> [[String: Any]] {
        (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }
}
