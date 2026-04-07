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
    /// True when Friends tab has no past opponents to show.
    @Published private(set) var friendsHasNoOpponents = false

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
            friendsHasNoOpponents = false
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let weekStart = LeaderboardRepository.weekStartUTC()
        weekRangeLabel = Self.formatWeekRangeLabel(weekStart: weekStart)

        do {
            if tab == .friends {
                let opponents = try await repository.fetchOpponentProfileIds(currentUserId: profile.id)
                friendsHasNoOpponents = opponents.isEmpty
                if opponents.isEmpty {
                    podiumRows = []
                    listRows = []
                    return
                }

                var entries = try await repository.fetchGlobalLeaderboard(weekStart: weekStart)
                let allowed = opponents.union([profile.id])
                entries = entries.filter { allowed.contains($0.userId) }
                if !entries.contains(where: { $0.userId == profile.id }) {
                    entries.append(
                        LeaderboardEntryRecord(
                            userId: profile.id,
                            points: 0,
                            wins: 0,
                            losses: 0,
                            streak: 0,
                            rank: nil
                        )
                    )
                }
                entries.sort { $0.points > $1.points }
                let shaped = try await mapToDisplayRows(
                    entries: entries,
                    currentUserId: profile.id,
                    friendsMode: true
                )
                splitPodiumAndList(shaped)
            } else {
                friendsHasNoOpponents = false
                var entries = try await repository.fetchGlobalLeaderboard(weekStart: weekStart)
                if !entries.contains(where: { $0.userId == profile.id }) {
                    entries.append(
                        LeaderboardEntryRecord(
                            userId: profile.id,
                            points: 0,
                            wins: 0,
                            losses: 0,
                            streak: 0,
                            rank: nil
                        )
                    )
                }
                entries.sort { Self.compareGlobal(a: $0, b: $1) }
                let shaped = try await mapToDisplayRows(
                    entries: entries,
                    currentUserId: profile.id,
                    friendsMode: false
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
        entries: [LeaderboardEntryRecord],
        currentUserId: UUID,
        friendsMode: Bool
    ) async throws -> [LeaderboardDisplayRow] {
        let ids = entries.map(\.userId)
        var profiles = try await repository.fetchProfiles(userIds: ids)

        if profiles[currentUserId] == nil {
            profiles[currentUserId] = LeaderboardProfileSummary(
                id: currentUserId,
                displayName: cachedProfile?.displayName ?? "You",
                initials: cachedProfile?.initials ?? "YO"
            )
        }

        var rows: [LeaderboardDisplayRow] = []
        for (index, entry) in entries.enumerated() {
            let rank = friendsMode ? (index + 1) : (entry.rank ?? (index + 1))
            let summary = profiles[entry.userId]
            let displayName = summary?.displayName ?? "Player"
            let initials = summary?.initials ?? Self.initials(from: displayName)
            let hex = ProfileAccentColor.hex(for: entry.userId)
            rows.append(
                LeaderboardDisplayRow(
                    id: entry.userId,
                    displayRank: rank,
                    points: entry.points,
                    wins: entry.wins,
                    losses: entry.losses,
                    streak: entry.streak,
                    displayName: displayName,
                    initials: initials,
                    colorHex: hex,
                    isCurrentUser: entry.userId == currentUserId
                )
            )
        }
        return rows
    }

    private static func compareGlobal(a: LeaderboardEntryRecord, b: LeaderboardEntryRecord) -> Bool {
        switch (a.rank, b.rank) {
        case let (ra?, rb?):
            if ra != rb { return ra < rb }
            return a.points > b.points
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return a.points > b.points
        }
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
