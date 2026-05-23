//
//  HeroIntroSessionGate.swift
//  FitUp
//
//  Process-lifetime gate: cold-open hero beam intro runs once until app is terminated.
//

import Foundation

@MainActor
enum HeroIntroSessionGate {
    private(set) static var hasPlayedColdOpenIntroThisSession = false

    /// Atomically marks the cold-open intro consumed. Returns `false` if already consumed.
    @discardableResult
    static func tryConsumeColdOpenIntro() -> Bool {
        guard !hasPlayedColdOpenIntroThisSession else { return false }
        hasPlayedColdOpenIntroThisSession = true
        return true
    }

    static func markColdOpenIntroPlayed() {
        hasPlayedColdOpenIntroThisSession = true
    }

    #if DEBUG
    static func resetForTesting() {
        hasPlayedColdOpenIntroThisSession = false
    }
    #endif
}
