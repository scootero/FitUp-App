//
//  ReadinessCalculator.swift
//  FitUp
//
//  Slice 12 — Battle Readiness (fitup-docs-pack §12). Pure function, no side effects.
//

import Foundation
#if DEBUG
import SwiftUI
#endif

struct ReadinessGoals: Equatable {
    var sleepGoalHours: Double
    var stepsGoal: Int
    var calsGoal: Int
    /// Display target for resting HR breakdown row (JSX uses 60 bpm).
    var restingHRTargetBpm: Double

    static let `default` = ReadinessGoals(
        sleepGoalHours: 8.0,
        stepsGoal: 12_000,
        calsGoal: 650,
        restingHRTargetBpm: 60
    )

    static func loadFromUserDefaults() -> ReadinessGoals {
        let d = UserDefaults.standard
        return ReadinessGoals(
            sleepGoalHours: d.object(forKey: "readiness_sleep_goal_hours") as? Double ?? Self.default.sleepGoalHours,
            stepsGoal: d.object(forKey: "readiness_steps_goal") as? Int ?? Self.default.stepsGoal,
            calsGoal: d.object(forKey: "readiness_cals_goal") as? Int ?? Self.default.calsGoal,
            restingHRTargetBpm: d.object(forKey: "readiness_resting_hr_target_bpm") as? Double ?? Self.default.restingHRTargetBpm
        )
    }
}

#if DEBUG
/// Runs in SwiftUI Preview only — validates formula + missing-data redistribution.
enum ReadinessCalculatorSanityTests {
    static func run() {
        let g = ReadinessGoals.default
        let perfect = ReadinessCalculator.compute(
            sleepHrsLastNight: 8,
            restingHR: 40,
            stepsToday: 12_000,
            calsToday: 650,
            goals: g
        )
        assert(perfect == 100)

        let noSleep = ReadinessCalculator.compute(
            sleepHrsLastNight: nil,
            restingHR: 60,
            stepsToday: 6_000,
            calsToday: 325,
            goals: g
        )
        assert(noSleep >= 55 && noSleep <= 57)

        let gStepsOnly = ReadinessGoals(sleepGoalHours: 8, stepsGoal: 12_000, calsGoal: 0, restingHRTargetBpm: 60)
        let onlySteps = ReadinessCalculator.compute(
            sleepHrsLastNight: nil,
            restingHR: nil,
            stepsToday: 12_000,
            calsToday: 0,
            goals: gStepsOnly
        )
        assert(onlySteps == 100)

        let emptyGoals = ReadinessGoals(sleepGoalHours: 8, stepsGoal: 0, calsGoal: 0, restingHRTargetBpm: 60)
        let none = ReadinessCalculator.compute(
            sleepHrsLastNight: nil,
            restingHR: nil,
            stepsToday: 0,
            calsToday: 0,
            goals: emptyGoals
        )
        assert(none == 0)
    }
}
#endif

#if DEBUG
#Preview("ReadinessCalculatorSanityTests") {
    Color.clear
        .frame(width: 1, height: 1)
        .onAppear {
            ReadinessCalculatorSanityTests.run()
        }
}
#endif

enum ReadinessCalculator {
    /// Base weights from spec (redistributed when a factor has no data).
    private static let wSleep: Double = 0.35
    private static let wHR: Double = 0.25
    private static let wSteps: Double = 0.25
    private static let wCals: Double = 0.15

    /// - Parameters:
    ///   - sleepHrsLastNight: Hours asleep for the most recent night (nil if unavailable).
    ///   - restingHR: Most recent resting heart rate in bpm (nil if unavailable).
    static func compute(
        sleepHrsLastNight: Double?,
        restingHR: Double?,
        stepsToday: Int,
        calsToday: Int,
        goals: ReadinessGoals
    ) -> Int {
        var sleepScore: Double?
        if let h = sleepHrsLastNight, goals.sleepGoalHours > 0 {
            sleepScore = min(100, (h / goals.sleepGoalHours) * 100)
        }

        var hrScore: Double?
        if let hr = restingHR {
            // hrScore = clamp((100 − restingHR) / 60 × 100, 0, 100)
            let raw = ((100 - hr) / 60) * 100
            hrScore = min(100, max(0, raw))
        }

        var stepsScore: Double?
        if goals.stepsGoal > 0 {
            stepsScore = min(100, (Double(stepsToday) / Double(goals.stepsGoal)) * 100)
        }

        var calsScore: Double?
        if goals.calsGoal > 0 {
            calsScore = min(100, (Double(calsToday) / Double(goals.calsGoal)) * 100)
        }

        var weightSleep = sleepScore != nil ? wSleep : 0
        var weightHR = hrScore != nil ? wHR : 0
        var weightSteps = stepsScore != nil ? wSteps : 0
        var weightCals = calsScore != nil ? wCals : 0
        let sumW = weightSleep + weightHR + weightSteps + weightCals
        guard sumW > 0 else { return 0 }

        // Redistribute missing factors proportionally among remaining weights.
        if sumW < 1 - 1e-9 {
            let scale = 1 / sumW
            weightSleep *= scale
            weightHR *= scale
            weightSteps *= scale
            weightCals *= scale
        }

        let total =
            (sleepScore ?? 0) * weightSleep +
            (hrScore ?? 0) * weightHR +
            (stepsScore ?? 0) * weightSteps +
            (calsScore ?? 0) * weightCals

        let rounded = Int((total).rounded())
        return min(100, max(0, rounded))
    }

    static func label(for score: Int) -> String {
        if score >= 75 { return "Strong Readiness" }
        if score >= 50 { return "Moderate Readiness" }
        return "Low Readiness"
    }

    static func subtitle(for score: Int) -> String {
        if score >= 75 { return "You're well-primed for battle today." }
        return "Some factors could be improved."
    }
}
