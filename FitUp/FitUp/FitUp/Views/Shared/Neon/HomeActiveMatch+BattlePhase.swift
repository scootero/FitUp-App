//
//  HomeActiveMatch+BattlePhase.swift
//  FitUp
//
//  Match phase helpers: pending finalization, match score vs today's step score.
//

import SwiftUI

extension HomeActiveMatch {
    var isStepsBattleForHomeUX: Bool {
        metricType != "active_calories"
    }

    var matchScoreMargin: Int {
        myScore - theirScore
    }

    var matchScoreText: String {
        BattlePhaseCopy.matchScoreLine(myScore: myScore, theirScore: theirScore)
    }

    /// True when the last competition calendar day has ended (profile TZ at load) but at least one day is not finalized.
    var isPendingFinalization: Bool {
        guard hasUnfinalizedDay else { return false }
        guard let endKey = battleEndDateKey else { return false }
        return endKey < profileTodayKey
    }

    var matchStatusLabel: String {
        let margin = matchScoreMargin
        if margin > 0 { return BattlePhaseCopy.matchWinning }
        if margin < 0 { return BattlePhaseCopy.matchLosing }
        return BattlePhaseCopy.matchTied
    }

    var matchStatusColor: Color {
        let margin = matchScoreMargin
        if margin > 0 { return FitUpColors.Neon.green }
        if margin < 0 { return FitUpColors.Neon.orange }
        return FitUpColors.Text.secondary
    }
}
