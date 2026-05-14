//
//  IntradayStepTickUploadPolicy.swift
//  FitUp
//
//  Slice 4 — Rules for throttling `append_user_intraday_step_tick` (debounce + step delta).
//

import Foundation

/// UserDefaults-backed gate for intraday step tick uploads (per profile + writer-local calendar day).
enum IntradayStepTickUploadPolicy {
    /// Minimum wall-clock gap between **successful** uploads for the same calendar day.
    static let minUploadIntervalSeconds: TimeInterval = 300
    /// After the first successful upload of the day, require at least this many **additional** steps before the next upload (monotonic increase only).
    static let minStepDeltaAfterFirstUpload: Int = 100

    private static let keyPrefix = "fitup.intradayTick.v1."

    enum Decision: Equatable, Sendable {
        case upload
        case skipNoSteps
        case skipUnchanged
        case skipDebounce(remainingSeconds: TimeInterval)
        case skipInsufficientIncrease(delta: Int, lastUploaded: Int)
    }

    static func decision(
        now: Date,
        stepsTotal: Int,
        profileId: UUID,
        calendarDateStr: String
    ) -> Decision {
        guard stepsTotal >= 0 else { return .skipNoSteps }

        let base = Self.baseKey(profileId: profileId, calendarDateStr: calendarDateStr)
        let lastSteps = UserDefaults.standard.object(forKey: base + ".steps") as? Int
        let lastAtInterval = UserDefaults.standard.object(forKey: base + ".at") as? Double
        let lastAt = lastAtInterval.map { Date(timeIntervalSince1970: $0) }

        if let lastSteps, lastSteps == stepsTotal {
            return .skipUnchanged
        }

        if let lastAt {
            let elapsed = now.timeIntervalSince(lastAt)
            if elapsed < minUploadIntervalSeconds {
                return .skipDebounce(remainingSeconds: minUploadIntervalSeconds - elapsed)
            }
        }

        if let lastSteps, stepsTotal > lastSteps {
            let delta = stepsTotal - lastSteps
            if delta < minStepDeltaAfterFirstUpload {
                return .skipInsufficientIncrease(delta: delta, lastUploaded: lastSteps)
            }
        }

        return .upload
    }

    /// Call only after a successful `append_user_intraday_step_tick`.
    static func markUploaded(profileId: UUID, calendarDateStr: String, steps: Int, at: Date) {
        let base = Self.baseKey(profileId: profileId, calendarDateStr: calendarDateStr)
        UserDefaults.standard.set(steps, forKey: base + ".steps")
        UserDefaults.standard.set(at.timeIntervalSince1970, forKey: base + ".at")
    }

    private static func baseKey(profileId: UUID, calendarDateStr: String) -> String {
        keyPrefix + profileId.uuidString + "." + calendarDateStr
    }
}
