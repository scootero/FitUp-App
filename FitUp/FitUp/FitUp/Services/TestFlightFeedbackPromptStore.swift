//
//  TestFlightFeedbackPromptStore.swift
//  FitUp
//
//  Device-level local gating for the timed TestFlight feedback prompt.
//

import Foundation

enum TestFlightFeedbackPromptStore {
    /// Length of each feedback prompt period.
    static let periodLength: TimeInterval = 36 * 3600

    /// Minimum cold starts before the prompt may appear.
    static let minimumLaunchCount = 2

    /// Brief delay after the app is idle before presenting the prompt.
    static let presentationDelay: TimeInterval = 1.5

    private static let defaults = UserDefaults.standard
    private static let firstOpenKey = "fitup.feedbackPrompt.firstOpenAt"
    private static let launchCountKey = "fitup.feedbackPrompt.launchCount"
    private static let hasSubmittedFeedbackKey = "fitup.feedbackPrompt.hasSubmittedFeedback"
    private static let lastPresentedPeriodKey = "fitup.feedbackPrompt.lastPresentedPeriod"

    private static var didRecordSessionStartThisProcess = false

    static var hasSubmittedFeedback: Bool {
        defaults.bool(forKey: hasSubmittedFeedbackKey)
    }

    /// Call once per cold start (before onboarding gate) to anchor install age and launch count.
    static func recordSessionStartIfNeeded() {
        guard !didRecordSessionStartThisProcess else { return }
        didRecordSessionStartThisProcess = true

        if defaults.object(forKey: firstOpenKey) == nil {
            defaults.set(Date().timeIntervalSince1970, forKey: firstOpenKey)
        }
        let count = defaults.integer(forKey: launchCountKey)
        defaults.set(count + 1, forKey: launchCountKey)
    }

    /// Recurring every 36h period at the next local noon after each threshold.
    static func shouldPresent(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard DevMode.isAvailable else { return false }
        guard !hasSubmittedFeedback else { return false }
        guard defaults.integer(forKey: launchCountKey) >= minimumLaunchCount else { return false }
        guard let firstOpen = firstOpenDate else { return false }

        let period = currentPeriodIndex(firstOpen: firstOpen, now: now)
        guard period >= 1 else { return false }

        let lastPresentedPeriod = defaults.integer(forKey: lastPresentedPeriodKey)
        guard period > lastPresentedPeriod else { return false }

        let eligibleAt = eligiblePresentationDate(firstOpen: firstOpen, period: period, calendar: calendar)
        return now >= eligibleAt
    }

    static func markPromptPresentedForCurrentPeriod(now: Date = .now) {
        guard let firstOpen = firstOpenDate else { return }
        let period = currentPeriodIndex(firstOpen: firstOpen, now: now)
        guard period >= 1 else { return }
        defaults.set(period, forKey: lastPresentedPeriodKey)
    }

    static func markFeedbackSubmitted() {
        defaults.set(true, forKey: hasSubmittedFeedbackKey)
        AppLogger.log(
            category: "product",
            level: .info,
            message: "testflight_feedback_prompt_submitted",
            metadata: [:]
        )
    }

    // MARK: - Period math

    private static var firstOpenDate: Date? {
        let interval = defaults.double(forKey: firstOpenKey)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    /// Period 0 = still inside the first 36h window; period 1+ = eligible cadence buckets.
    static func currentPeriodIndex(firstOpen: Date, now: Date) -> Int {
        let elapsed = now.timeIntervalSince(firstOpen)
        guard elapsed >= periodLength else { return 0 }
        return Int(floor(elapsed / periodLength))
    }

    /// Next local noon on or after `firstOpen + period * 36h`.
    static func eligiblePresentationDate(
        firstOpen: Date,
        period: Int,
        calendar: Calendar = .current
    ) -> Date {
        let threshold = firstOpen.addingTimeInterval(TimeInterval(period) * periodLength)
        return nextNoon(onOrAfter: threshold, calendar: calendar)
    }

    static func nextNoon(onOrAfter date: Date, calendar: Calendar) -> Date {
        var noonComponents = calendar.dateComponents([.year, .month, .day], from: date)
        noonComponents.hour = 12
        noonComponents.minute = 0
        noonComponents.second = 0

        if let noonToday = calendar.date(from: noonComponents) {
            if noonToday >= date {
                return noonToday
            }
            if let tomorrowNoon = calendar.date(byAdding: .day, value: 1, to: noonToday) {
                return tomorrowNoon
            }
        }

        return date
    }

    #if DEBUG
    static func resetForTesting() {
        defaults.removeObject(forKey: firstOpenKey)
        defaults.removeObject(forKey: launchCountKey)
        defaults.removeObject(forKey: hasSubmittedFeedbackKey)
        defaults.removeObject(forKey: lastPresentedPeriodKey)
        didRecordSessionStartThisProcess = false
    }
    #endif
}
