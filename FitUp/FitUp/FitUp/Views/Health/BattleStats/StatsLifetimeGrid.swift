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

    var showsExtraImpact: Bool {
        (extraMilesWalked ?? 0) > 0 || (extraStepsWalked ?? 0) > 0
    }
}

struct StatsLifetimeGrid: View {
    let display: StatsLifetimeDisplay
    var onShowCombinedMetricExplainer: ([StatsMetricExplainerKind]) -> Void = { _ in }

    private var explainerKinds: [StatsMetricExplainerKind] {
        var kinds: [StatsMetricExplainerKind] = [
            .allTimeBattleSteps,
            .battlesCompleted,
            .daysCompeted,
        ]
        if display.showsExtraImpact {
            kinds.append(.extraBattleImpact)
        }
        return kinds
    }

    var body: some View {
        BattleStatsTheme.battleStatsCard(accent: .cool) {
            VStack(alignment: .leading, spacing: 12) {
                BattleStatsTheme.sectionTitle("LIFETIME", accent: .cool)
                    .padding(.trailing, 32)

                lifetimeCell(
                    label: "TOTAL BATTLE STEPS",
                    value: display.totalBattleSteps.map { $0.formatted() } ?? BattleStatsTheme.unresolvedPlaceholder,
                    color: BattleStatsTheme.blue
                )

                HStack(spacing: 8) {
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

                if display.showsExtraImpact {
                    extraImpactCell
                }
            }
        }
        .statsCardCombinedMetricInfoCorner(
            kinds: explainerKinds,
            accent: .cool,
            onShow: onShowCombinedMetricExplainer
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Lifetime stats")
    }

    @ViewBuilder
    private var extraImpactCell: some View {
        let showMiles = (display.extraMilesWalked ?? 0) > 0
        let showSteps = (display.extraStepsWalked ?? 0) > 0

        HStack(alignment: .top, spacing: 10) {
            if showMiles {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(display.extraMilesWalked!) mi")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(BattleStatsTheme.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    extraImpactLabel("EXTRA MILES WALKED", accent: .mint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if showMiles && showSteps {
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1)
                    .padding(.vertical, 2)
            }

            if showSteps {
                VStack(alignment: .leading, spacing: 6) {
                    Text(display.extraStepsWalked!.formatted())
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(BattleStatsTheme.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    extraImpactLabel("EXTRA STEPS WALKED", accent: .warm)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BattleStatsTheme.green.opacity(0.14),
                            BattleStatsTheme.gold.opacity(0.1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel("Extra miles and steps walked from battles")
    }

    private func extraImpactLabel(_ text: String, accent: BattleStatsTheme.SectionAccent) -> some View {
        Text(text)
            .font(.system(size: BattleStatsTheme.Typography.caption, weight: .medium, design: .monospaced))
            .tracking(0.5)
            .battleStatsStyle(.label, accent: accent)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
    }

    private func lifetimeCell(
        label: String,
        value: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.system(size: BattleStatsTheme.Typography.caption, weight: .medium, design: .monospaced))
                    .tracking(0.5)
                    .battleStatsStyle(.label, accent: .cool)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.18),
                            color.opacity(0.05),
                            color.opacity(0.12),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
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
