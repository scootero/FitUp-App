//
//  StatsRivalSelection.swift
//  FitUp
//
//  Picks three featured rival slots from full rival stats (match-based counts).
//  Each category is chosen independently; the same opponent may appear on multiple cards.
//

import Foundation

enum StatsRivalCategory: String, Sendable {
    case nemesis
    case punchingBag
    case mostBattled

    var label: String {
        switch self {
        case .nemesis: return "😤 NEMESIS"
        case .punchingBag: return "💪 PUNCHING BAG"
        case .mostBattled: return "⚔️ MOST BATTLED"
        }
    }
}

struct StatsRivalSlot: Equatable, Sendable, Identifiable {
    let category: StatsRivalCategory
    let rival: HomeRivalStat

    var id: String { "\(category.rawValue)-\(rival.opponentProfileId.uuidString)" }
}

enum StatsRivalSelection {
    static func pick(from rivals: [HomeRivalStat]) -> [StatsRivalSlot] {
        guard !rivals.isEmpty else { return [] }

        var slots: [StatsRivalSlot] = []

        if let nemesis = pickMax(from: rivals, score: \.matchLosses) {
            slots.append(StatsRivalSlot(category: .nemesis, rival: nemesis))
        }
        if let punchingBag = pickMax(from: rivals, score: \.matchWins) {
            slots.append(StatsRivalSlot(category: .punchingBag, rival: punchingBag))
        }
        if let mostBattled = pickMax(from: rivals, score: \.completedMatchCount) {
            slots.append(StatsRivalSlot(category: .mostBattled, rival: mostBattled))
        }

        return slots
    }

    private static func pickMax(
        from rivals: [HomeRivalStat],
        score: (HomeRivalStat) -> Int
    ) -> HomeRivalStat? {
        guard !rivals.isEmpty else { return nil }

        return rivals.max { lhs, rhs in
            let lhsScore = score(lhs)
            let rhsScore = score(rhs)
            if lhsScore != rhsScore { return lhsScore < rhsScore }
            return tieBreakCompare(lhs, rhs) == .orderedDescending
        }
    }

    /// Prefer more recent activity, then more battle days, then stable UUID order.
    private static func tieBreakCompare(_ lhs: HomeRivalStat, _ rhs: HomeRivalStat) -> ComparisonResult {
        let lhsDate = lhs.lastPlayedOn ?? .distantPast
        let rhsDate = rhs.lastPlayedOn ?? .distantPast
        if lhsDate != rhsDate {
            return lhsDate > rhsDate ? .orderedAscending : .orderedDescending
        }
        if lhs.finalizedDaysCompeted != rhs.finalizedDaysCompeted {
            return lhs.finalizedDaysCompeted > rhs.finalizedDaysCompeted ? .orderedAscending : .orderedDescending
        }
        if lhs.opponentProfileId.uuidString != rhs.opponentProfileId.uuidString {
            return lhs.opponentProfileId.uuidString < rhs.opponentProfileId.uuidString ? .orderedAscending : .orderedDescending
        }
        return .orderedSame
    }
}

extension HomeRivalStat {
    var completedMatchCount: Int {
        matchWins + matchLosses + matchTies
    }
}
