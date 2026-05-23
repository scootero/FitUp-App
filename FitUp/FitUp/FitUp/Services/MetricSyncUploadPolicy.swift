//
//  MetricSyncUploadPolicy.swift
//  FitUp
//
//  Throttles HealthKit observer → full metric sync (debounce + step delta + unchanged skip).
//  Separate from IntradayStepTickUploadPolicy (intraday chart ticks only).
//

import Foundation

enum MetricSyncUploadPolicy {
    /// Minimum wall-clock gap between successful full metric syncs when triggered by HK observer.
    static let minObserverIntervalSeconds: TimeInterval = 300
    /// After the first successful sync of the day, require at least this many additional steps before the next observer sync.
    static let minStepDeltaAfterFirstSync: Int = 100

    private static let syncKeyPrefix = "fitup.metricSync.v1."
    private static let dailyTotalsKeyPrefix = "fitup.dailyTotals.v1."

    enum ObserverDecision: Equatable, Sendable {
        case proceed
        case skipUnchanged
        case skipDebounce(remainingSeconds: TimeInterval)
        case skipInsufficientStepIncrease(delta: Int, lastSynced: Int)
    }

    /// Gate HK observer wakes before running a full `performSync`.
    static func observerDecision(
        now: Date,
        stepsTotal: Int?,
        caloriesTotal: Int?,
        profileId: UUID,
        calendarDateStr: String
    ) -> ObserverDecision {
        let base = syncBaseKey(profileId: profileId, calendarDateStr: calendarDateStr)
        let lastSteps = UserDefaults.standard.object(forKey: base + ".steps") as? Int
        let lastCalories = UserDefaults.standard.object(forKey: base + ".calories") as? Int
        let lastAtInterval = UserDefaults.standard.object(forKey: base + ".at") as? Double
        let lastAt = lastAtInterval.map { Date(timeIntervalSince1970: $0) }

        let steps = stepsTotal ?? lastSteps
        let calories = caloriesTotal ?? lastCalories

        if let lastSteps, let steps, lastSteps == steps,
           lastCalories == calories {
            return .skipUnchanged
        }

        if let lastAt {
            let elapsed = now.timeIntervalSince(lastAt)
            if elapsed < minObserverIntervalSeconds {
                return .skipDebounce(remainingSeconds: minObserverIntervalSeconds - elapsed)
            }
        }

        if let lastSteps, let steps, steps > lastSteps {
            let delta = steps - lastSteps
            if delta < minStepDeltaAfterFirstSync, lastCalories == calories {
                return .skipInsufficientStepIncrease(delta: delta, lastSynced: lastSteps)
            }
        }

        return .proceed
    }

    /// Call after a successful full metric sync completes.
    static func markSyncCompleted(
        profileId: UUID,
        calendarDateStr: String,
        stepsTotal: Int?,
        caloriesTotal: Int?,
        at: Date
    ) {
        let base = syncBaseKey(profileId: profileId, calendarDateStr: calendarDateStr)
        if let stepsTotal {
            UserDefaults.standard.set(stepsTotal, forKey: base + ".steps")
        }
        if let caloriesTotal {
            UserDefaults.standard.set(caloriesTotal, forKey: base + ".calories")
        }
        UserDefaults.standard.set(at.timeIntervalSince1970, forKey: base + ".at")
    }

    /// Rolling 7-day `user_daily_step_totals` refresh: foreground/manual always; observer at most once per local day.
    static func shouldSyncRollingDailyTotals(
        trigger: MetricSyncTrigger,
        profileId: UUID,
        calendarDateStr: String
    ) -> Bool {
        switch trigger {
        case .foreground, .manual:
            return true
        case .observer:
            let key = dailyTotalsBaseKey(profileId: profileId, calendarDateStr: calendarDateStr)
            return UserDefaults.standard.string(forKey: key) != calendarDateStr
        }
    }

    static func markRollingDailyTotalsSynced(
        profileId: UUID,
        calendarDateStr: String
    ) {
        let key = dailyTotalsBaseKey(profileId: profileId, calendarDateStr: calendarDateStr)
        UserDefaults.standard.set(calendarDateStr, forKey: key)
    }

    private static func syncBaseKey(profileId: UUID, calendarDateStr: String) -> String {
        syncKeyPrefix + profileId.uuidString + "." + calendarDateStr
    }

    private static func dailyTotalsBaseKey(profileId: UUID, calendarDateStr: String) -> String {
        dailyTotalsKeyPrefix + profileId.uuidString + "." + calendarDateStr
    }
}
