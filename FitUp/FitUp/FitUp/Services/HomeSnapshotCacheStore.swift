//
//  HomeSnapshotCacheStore.swift
//  FitUp
//
//  Local cache for Home hero/top-circle active match snapshot.
//

import Foundation

struct CachedHomeSnapshot: Codable {
    let schemaVersion: Int
    let profileId: UUID
    let localDate: String
    let profileTimeZoneIdentifier: String?
    let savedAt: Date
    let heroMetric: String
    let activeMatches: [CachedHomeActiveMatch]
}

struct CachedHomeActiveMatch: Codable {
    let id: UUID
    let state: String
    let metricType: String
    let durationDays: Int
    let sportLabel: String
    let seriesLabel: String
    let daysLeft: Int
    let finalDayCutoffAt: Date?
    let finalDayScoreEndsAt: Date?
    let myToday: Int
    let theirToday: Int
    let myScore: Int
    let theirScore: Int
    let opponent: CachedHomeOpponent
    let opponentTodayUpdatedAt: Date?
    let dayPips: [CachedHomeDayPip]
}

struct CachedHomeOpponent: Codable {
    let id: UUID
    let displayName: String
    let initials: String
    let colorHex: String
}

struct CachedHomeDayPip: Codable {
    let dayNumber: Int
    let state: String
}

final class HomeSnapshotCacheStore {
    private let defaults: UserDefaults
    private let keyPrefix = "home.hero.snapshot.v2"
    private let schemaVersion = 2

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadTodaySnapshot(
        profileId: UUID,
        profileTimeZoneIdentifier: String?,
        now: Date = Date()
    ) -> CachedHomeSnapshot? {
        let localDate = localDateString(now: now, profileTimeZoneIdentifier: profileTimeZoneIdentifier)
        let key = cacheKey(profileId: profileId, localDate: localDate)
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let snapshot = try? JSONDecoder().decode(CachedHomeSnapshot.self, from: data) else {
            defaults.removeObject(forKey: key)
            return nil
        }
        guard snapshot.schemaVersion == schemaVersion,
              snapshot.profileId == profileId,
              snapshot.localDate == localDate
        else {
            defaults.removeObject(forKey: key)
            return nil
        }
        return snapshot
    }

    func saveTodaySnapshot(_ snapshot: CachedHomeSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let key = cacheKey(profileId: snapshot.profileId, localDate: snapshot.localDate)
        defaults.set(data, forKey: key)
    }

    func makeSnapshot(
        profileId: UUID,
        profileTimeZoneIdentifier: String?,
        heroMetric: HomeBattleHeroCard.HeroMetric,
        activeMatches: [HomeActiveMatch],
        now: Date = Date()
    ) -> CachedHomeSnapshot {
        CachedHomeSnapshot(
            schemaVersion: schemaVersion,
            profileId: profileId,
            localDate: localDateString(now: now, profileTimeZoneIdentifier: profileTimeZoneIdentifier),
            profileTimeZoneIdentifier: profileTimeZoneIdentifier,
            savedAt: now,
            heroMetric: heroMetric.rawValue,
            activeMatches: activeMatches.map(CachedHomeActiveMatch.init(from:))
        )
    }

    func toDomain(_ snapshot: CachedHomeSnapshot) -> [HomeActiveMatch] {
        snapshot.activeMatches.map(\.asDomain)
    }

    func heroMetric(from snapshot: CachedHomeSnapshot) -> HomeBattleHeroCard.HeroMetric {
        _ = snapshot
        return .steps
    }

    func localDateString(now: Date = Date(), profileTimeZoneIdentifier: String?) -> String {
        var calendar = Calendar(identifier: .gregorian)
        if let profileTimeZoneIdentifier,
           let tz = TimeZone(identifier: profileTimeZoneIdentifier) {
            calendar.timeZone = tz
        } else {
            calendar.timeZone = .current
        }
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    func makeCompactSummary(
        activeMatches: [HomeActiveMatch],
        heroMetric: HomeBattleHeroCard.HeroMetric
    ) -> String {
        let matchesForMetric = activeMatches.filter { normalizedMetric(for: $0.metricType) == heroMetric }
        guard !matchesForMetric.isEmpty else {
            return "matches=0 metric=\(heroMetric.rawValue)"
        }
        let myTop = matchesForMetric.map(\.myToday).max() ?? 0
        let topOpponentMatch = matchesForMetric.max(by: { $0.theirToday < $1.theirToday })
        let topOpponent = topOpponentMatch?.theirToday ?? 0
        let opponentName = topOpponentMatch?.opponent.displayName ?? "none"
        let ids = matchesForMetric
            .map { String($0.id.uuidString.prefix(6)).uppercased() }
            .sorted()
            .prefix(3)
            .joined(separator: ",")
        return "matches=\(matchesForMetric.count) metric=\(heroMetric.rawValue) my=\(myTop) topOpponent=\(topOpponent) opponent=\(opponentName) ids=\(ids)"
    }

    private func cacheKey(profileId: UUID, localDate: String) -> String {
        "\(keyPrefix).\(profileId.uuidString).\(localDate)"
    }

    private func normalizedMetric(for metricType: String) -> HomeBattleHeroCard.HeroMetric {
        metricType == "active_calories" ? .calories : .steps
    }
}

private extension CachedHomeActiveMatch {
    nonisolated init(from match: HomeActiveMatch) {
        self.init(
            id: match.id,
            state: "active",
            metricType: match.metricType,
            durationDays: match.durationDays,
            sportLabel: match.sportLabel,
            seriesLabel: match.seriesLabel,
            daysLeft: match.daysLeft,
            finalDayCutoffAt: match.finalDayCutoffAt,
            finalDayScoreEndsAt: match.finalDayScoreEndsAt,
            myToday: match.myToday,
            theirToday: match.theirToday,
            myScore: match.myScore,
            theirScore: match.theirScore,
            opponent: CachedHomeOpponent(
                id: match.opponent.id,
                displayName: match.opponent.displayName,
                initials: match.opponent.initials,
                colorHex: match.opponent.colorHex
            ),
            opponentTodayUpdatedAt: match.opponentTodayUpdatedAt,
            dayPips: match.dayPips.map {
                CachedHomeDayPip(dayNumber: $0.dayNumber, state: CachedHomeDayPip.string(from: $0.state))
            }
        )
    }

    nonisolated var asDomain: HomeActiveMatch {
        HomeActiveMatch(
            id: id,
            metricType: metricType,
            durationDays: durationDays,
            sportLabel: sportLabel,
            seriesLabel: seriesLabel,
            daysLeft: daysLeft,
            finalDayCutoffAt: finalDayCutoffAt,
            finalDayScoreEndsAt: finalDayScoreEndsAt,
            myToday: myToday,
            theirToday: theirToday,
            myScore: myScore,
            theirScore: theirScore,
            isWinning: myToday >= theirToday,
            opponent: HomeOpponent(
                id: opponent.id,
                displayName: opponent.displayName,
                initials: opponent.initials,
                colorHex: opponent.colorHex
            ),
            opponentTodayUpdatedAt: opponentTodayUpdatedAt,
            dayPips: dayPips.map {
                HomeDayPip(dayNumber: $0.dayNumber, state: CachedHomeDayPip.state(from: $0.state))
            }
        )
    }
}

private extension CachedHomeDayPip {
    nonisolated static func string(from state: HomeDayPipState) -> String {
        switch state {
        case .future: return "future"
        case .won: return "won"
        case .lost: return "lost"
        case .today: return "today"
        case .voided: return "voided"
        }
    }

    nonisolated static func state(from value: String) -> HomeDayPipState {
        switch value {
        case "won": return .won
        case "lost": return .lost
        case "today": return .today
        case "voided": return .voided
        default: return .future
        }
    }
}
