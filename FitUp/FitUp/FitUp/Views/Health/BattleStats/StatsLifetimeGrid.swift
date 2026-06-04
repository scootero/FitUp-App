//
//  StatsLifetimeGrid.swift
//  FitUp
//

import SwiftUI

struct StatsLifetimeDisplay: Equatable, Sendable {
    let totalBattleSteps: Int?
    let battlesCompleted: Int?
    let daysCompeted: Int?
    let extraMilesWalked: Int?
    let extraStepsWalked: Int?

    static let empty = StatsLifetimeDisplay(
        totalBattleSteps: nil,
        battlesCompleted: nil,
        daysCompeted: nil,
        extraMilesWalked: nil,
        extraStepsWalked: nil
    )
}

struct StatsLifetimeGrid: View {
    let display: StatsLifetimeDisplay

    var body: some View {
        BattleStatsTheme.battleStatsCard {
            VStack(alignment: .leading, spacing: 12) {
                BattleStatsTheme.sectionTitle("LIFETIME")

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                    ],
                    spacing: 8
                ) {
                    lifetimeCell(
                        label: "TOTAL BATTLE STEPS",
                        value: display.totalBattleSteps.map { $0.formatted() } ?? BattleStatsTheme.unresolvedPlaceholder,
                        color: BattleStatsTheme.blue
                    )
                    lifetimeCell(
                        label: "BATTLES COMPLETED",
                        value: display.battlesCompleted.map { "\($0)" } ?? BattleStatsTheme.unresolvedPlaceholder,
                        color: BattleStatsTheme.purple
                    )
                    lifetimeCell(
                        label: "DAYS COMPETED",
                        value: display.daysCompeted.map { "\($0)" } ?? BattleStatsTheme.unresolvedPlaceholder,
                        color: BattleStatsTheme.orange
                    )
                }

                extraImpactCell
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Lifetime stats")
    }

    private var extraImpactCell: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(display.extraMilesWalked.map { "\($0) mi" } ?? BattleStatsTheme.unresolvedPlaceholder)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(BattleStatsTheme.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("EXTRA MILES WALKED")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(BattleStatsTheme.textLabel)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(display.extraStepsWalked.map { $0.formatted() } ?? BattleStatsTheme.unresolvedPlaceholder)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(BattleStatsTheme.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("EXTRA STEPS WALKED")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(BattleStatsTheme.textLabel)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel("Extra miles and steps walked from battles")
    }

    private func lifetimeCell(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(BattleStatsTheme.textLabel)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel("\(label), \(value)")
    }
}

extension StatsLifetimeDisplay {
    static func make(
        battleSteps: StatsBattleStepsDisplay?,
        battleStats: HealthBattleStats,
        impact: StatsBattleImpactMetric?
    ) -> StatsLifetimeDisplay {
        let bonusSteps: Int? = {
            guard let impact, impact.hasEnoughSample, impact.deltaSteps > 0,
                  let days = battleSteps?.finalizedBattleDayCount, days > 0
            else { return nil }
            return impact.deltaSteps * days
        }()

        let extraMiles: Int? = bonusSteps.map { Int((Double($0) / 2000.0).rounded()) }

        let daysCompeted: Int? = {
            guard let count = battleSteps?.finalizedBattleDayCount, count > 0 else { return nil }
            return count
        }()

        return StatsLifetimeDisplay(
            totalBattleSteps: battleSteps.map(\.allTimeSteps),
            battlesCompleted: battleSteps != nil ? battleStats.matchesPlayed : nil,
            daysCompeted: daysCompeted,
            extraMilesWalked: extraMiles,
            extraStepsWalked: bonusSteps
        )
    }
}
