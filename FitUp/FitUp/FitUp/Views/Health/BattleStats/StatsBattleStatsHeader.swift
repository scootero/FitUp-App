//
//  StatsBattleStatsHeader.swift
//  FitUp
//

import SwiftUI

struct StatsBattleStatsHeader: View {
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Battle Stats")
                .font(.system(size: BattleStatsTheme.Typography.headerTitle, weight: .heavy, design: .rounded))
                .foregroundStyle(FitUpColors.Text.title)

            Text(subtitle)
                .font(.system(size: BattleStatsTheme.Typography.headerSubtitle, weight: .medium, design: .rounded))
                .foregroundStyle(BattleStatsTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    static func defaultSubtitle(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: now)
    }
}
