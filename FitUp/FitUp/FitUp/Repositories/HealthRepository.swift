//
//  HealthRepository.swift
//  FitUp
//
//  Slice 12 — All-time bests from Supabase (`all_time_bests` public read RLS).
//

import Combine
import Foundation
import Supabase

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
