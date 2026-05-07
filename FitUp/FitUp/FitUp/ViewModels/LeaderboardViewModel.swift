//
//  LeaderboardViewModel.swift
//  FitUp
//
//  Slice 11 — Leaderboard tab state and data shaping.
//

import Combine
import Foundation

@MainActor
final class LeaderboardViewModel: ObservableObject {
    enum LeaderboardTab: String, CaseIterable {
        case global
        /// Weekly ranks among accepted `friendships` peers (same week as Global).
        case friends

        var title: String {
            switch self {
            case .global: return "Global"
            case .friends: return "Friends"
            }
        }
    }

    @Published var tab: LeaderboardTab = .global {
        didSet {
            Task { await load(profile: cachedProfile) }
        }
    }

    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    @Published private(set) var weekRangeLabel: String = ""
    @Published private(set) var podiumRows: [LeaderboardDisplayRow] = []
    @Published private(set) var listRows: [LeaderboardDisplayRow] = []
    /// True when the Friends tab has no accepted friends to show.
    @Published private(set) var friendsHasNoFriends = false

    /// Set by the view when the current user’s main list row intersects the scroll viewport.
    @Published var isCurrentUserListRowVisible = true

    private let repository = LeaderboardRepository()
    private var cachedProfile: Profile?

    var shouldShowPinnedUserBar: Bool {
        listRows.contains(where: \.isCurrentUser) && !isCurrentUserListRowVisible
    }

    func pinnedUserRow() -> LeaderboardDisplayRow? {
        listRows.first(where: \.isCurrentUser)
    }

    func load(profile: Profile?) async {
        cachedProfile = profile
        guard let profile else {
            podiumRows = []
            listRows = []
            weekRangeLabel = ""
            friendsHasNoFriends = false
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let weekStart = LeaderboardRepository.weekStartUTC()
        weekRangeLabel = Self.formatWeekRangeLabel(weekStart: weekStart)

        do {
            if tab == .friends {
                let friendIds = try await repository.fetchAcceptedFriendProfileIds(currentProfileId: profile.id)
                friendsHasNoFriends = friendIds.isEmpty
                if friendIds.isEmpty {
                    podiumRows = []
                    listRows = []
                    return
                }

                let entries = try await repository.fetchWeeklyStepsLeaderboard(
                    weekStart: weekStart,
                    scope: .friends
                )
                let shaped = mapToDisplayRows(
                    entries: entries,
                    currentUserId: profile.id
                )
                splitPodiumAndList(shaped)
            } else {
                friendsHasNoFriends = false
                let entries = try await repository.fetchWeeklyStepsLeaderboard(
                    weekStart: weekStart,
                    scope: .global
                )
                let shaped = mapToDisplayRows(
                    entries: entries,
                    currentUserId: profile.id
                )
                splitPodiumAndList(shaped)
            }
        } catch {
            errorMessage = "Could not load leaderboard."
            AppLogger.log(
                category: "leaderboard",
                level: .warning,
                message: "leaderboard load failed",
                userId: profile.id,
                metadata: ["error": error.localizedDescription]
            )
            podiumRows = []
            listRows = []
        }
    }

    // MARK: - Private

    private func splitPodiumAndList(_ rows: [LeaderboardDisplayRow]) {
        let podium = Array(rows.prefix(3))
        let rest = Array(rows.dropFirst(3))
        podiumRows = podium
        listRows = rest
    }

    private func mapToDisplayRows(
        entries: [WeeklyStepsLeaderboardRecord],
        currentUserId: UUID
    ) -> [LeaderboardDisplayRow] {
        var rows: [LeaderboardDisplayRow] = entries.map { entry in
            let displayName = entry.displayName
            let initials = entry.initials.isEmpty ? Self.initials(from: displayName) : entry.initials
            let hex = ProfileAccentColor.hex(for: entry.userId)
            return LeaderboardDisplayRow(
                id: entry.userId,
                displayRank: entry.rank,
                totalSteps: entry.totalSteps,
                displayName: displayName,
                initials: initials,
                colorHex: hex,
                isCurrentUser: entry.userId == currentUserId
            )
        }
        rows.sort { $0.displayRank < $1.displayRank }
        return rows
    }

    private static func initials(from displayName: String) -> String {
        let parts = displayName.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            let a = parts[0].first.map(String.init) ?? ""
            let b = parts[1].first.map(String.init) ?? ""
            return (a + b).uppercased()
        }
        let s = String(parts.first ?? "")
        let prefix = s.prefix(2)
        return prefix.uppercased()
    }

    private static func formatWeekRangeLabel(weekStart: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let end = cal.date(byAdding: .day, value: 6, to: weekStart) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM d"
        return "Week of \(formatter.string(from: weekStart)) – \(formatter.string(from: end))"
    }
}
