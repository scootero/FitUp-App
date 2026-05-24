//
//  ActivityCompletedMatch+NeonDisplay.swift
//  FitUp
//
//  Display-only copy for neon past battle rows.
//

import SwiftUI

extension ActivityCompletedMatch {
    var neonScoreText: String {
        "\(myScore)–\(theirScore)"
    }

    var neonSportLabel: String {
        metricType == "active_calories" ? "CALORIES" : "STEPS"
    }

    var neonOutcomeLabel: String {
        myWon ? "WON" : "LOSS"
    }

    var neonOutcomeColor: Color {
        myWon ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange
    }
}
