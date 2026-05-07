//
//  ProfileViewModel.swift
//  FitUp
//
//  Slice 14 — Profile screen data: stats, log viewer filters and fetch, JSON export.
//

import Combine
import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {

    // MARK: - Nested types

    struct ProfileStats: Equatable {
        let matchCount: Int
        let winCount: Int
        let streak: Int
    }

    enum LogTimeRange: String, CaseIterable, Identifiable {
        case tenMin     = "10m"
        case oneHour    = "1h"
        case twelveHours = "12h"
        case oneDay     = "24h"
        case threeDays  = "3d"

        var id: String { rawValue }

        var interval: TimeInterval {
            switch self {
            case .tenMin:      return 10 * 60
            case .oneHour:     return 60 * 60
            case .twelveHours: return 12 * 60 * 60
            case .oneDay:      return 24 * 60 * 60
            case .threeDays:   return 3 * 24 * 60 * 60
            }
        }
    }

    enum LogLevelFilter: String, CaseIterable, Identifiable {
        case all       = "All"
        case errorsOnly = "Errors"
        var id: String { rawValue }
    }

    // MARK: - Published state

    @Published private(set) var stats = ProfileStats(matchCount: 0, winCount: 0, streak: 0)
    @Published private(set) var logs: [AppLogEntry] = []
    @Published private(set) var isLoadingStats = false
    @Published private(set) var isLoadingLogs = false
    @Published var logTimeFilter: LogTimeRange = .oneHour
    @Published var logLevelFilter: LogLevelFilter = .all

    // MARK: - Dependencies

    private let activityRepository = ActivityRepository()
    private let profileRepository = ProfileRepository()

    // MARK: - Load stats

    func load(profile: Profile?) async {
        guard let userId = profile?.id else { return }
        isLoadingStats = true
        defer { isLoadingStats = false }

        let completed = await activityRepository.loadCompletedMatches(currentUserId: userId)
        let currentStreak = Self.currentWinStreak(from: completed)

        stats = ProfileStats(
            matchCount: completed.count,
            winCount: completed.filter(\.myWon).count,
            streak: currentStreak
        )
    }

    // MARK: - Fetch logs

    func fetchLogs(profile: Profile?) async {
        guard let userId = profile?.id else {
            logs = []
            return
        }
        isLoadingLogs = true
        defer { isLoadingLogs = false }

        let since = Date().addingTimeInterval(-logTimeFilter.interval)
        let levelFilter: String? = logLevelFilter == .errorsOnly ? "error" : nil
        logs = await profileRepository.fetchLogs(userId: userId, since: since, levelFilter: levelFilter)
    }

    // MARK: - Export

    /// Returns all currently-displayed logs serialised as pretty-printed JSON.
    func exportJSON() -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(logs)) ?? Data()
    }

    private static func currentWinStreak(from matches: [ActivityCompletedMatch]) -> Int {
        var streak = 0
        for match in matches {
            if match.myWon {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }
}
