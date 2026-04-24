//
//  MatchFoundCelebrationStore.swift
//  FitUp
//
//  Persists which pending matches already showed the match-found overlay (per profile).
//

import Foundation

enum MatchFoundCelebrationStore {
    private static let defaults = UserDefaults.standard
    private static let maxStoredIds = 100

    private static func storageKey(profileId: UUID) -> String {
        "fitup.matchFoundCelebrationShown.\(profileId.uuidString)"
    }

    static func hasShown(profileId: UUID, matchId: UUID) -> Bool {
        let ids = defaults.stringArray(forKey: storageKey(profileId: profileId)) ?? []
        return ids.contains(matchId.uuidString)
    }

    static func markShown(profileId: UUID, matchId: UUID) {
        var ids = defaults.stringArray(forKey: storageKey(profileId: profileId)) ?? []
        guard !ids.contains(matchId.uuidString) else { return }
        ids.append(matchId.uuidString)
        if ids.count > maxStoredIds {
            ids = Array(ids.suffix(maxStoredIds))
        }
        defaults.set(ids, forKey: storageKey(profileId: profileId))
    }
}
