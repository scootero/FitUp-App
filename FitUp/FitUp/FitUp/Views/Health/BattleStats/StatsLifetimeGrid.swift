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
    let hasResolvedBattleSteps: Bool
    let showsEmptyMatchHint: Bool

    static let empty = StatsLifetimeDisplay(
        totalBattleSteps: nil,
        battlesCompleted: nil,
        daysCompeted: nil,
        extraMilesWalked: nil,
        extraStepsWalked: nil,
        hasResolvedBattleSteps: false,
        showsEmptyMatchHint: false
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
                BattleStatsTheme.sectionHeaderRow(
                    title: "LIFETIME",
                    accent: .cool,
                    showsNoBattleDataBadge: display.showsEmptyMatchHint
                )

                lifetimeCell(
                    label: "TOTAL BATTLE STEPS",
                    value: formattedValue(display.totalBattleSteps),
                    color: BattleStatsTheme.blue
                )

                HStack(spacing: 8) {
                    lifetimeCell(
                        label: "BATTLES COMPLETED",
                        value: formattedValue(display.battlesCompleted),
                        color: BattleStatsTheme.purple
                    )
                    lifetimeCell(
                        label: "DAYS COMPETED",
                        value: formattedValue(display.daysCompeted),
                        color: BattleStatsTheme.orange
                    )
                }

                if display.showsExtraImpact {
                    extraImpactCell
                }

                if display.showsEmptyMatchHint {
                    BattleStatsTheme.completeMatchFirstFooter
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

    private func formattedValue(_ value: Int?) -> String {
        guard let value else { return BattleStatsTheme.unresolvedPlaceholder }
        return value.formatted()
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

    private func lifetimeCellLabel(_ text: String, accentColor: Color) -> some View {
        Text(text)
            .font(.system(size: BattleStatsTheme.Typography.caption, weight: .medium, design: .monospaced))
            .tracking(0.5)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        BattleStatsTheme.gold.opacity(0.95),
                        Color.white.opacity(0.92),
                        accentColor.opacity(0.85),
                    ],
                    startPoint: UnitPoint(x: 0, y: 0.2),
                    endPoint: UnitPoint(x: 0.75, y: 0.85)
                )
            )
            .lineLimit(2)
            .minimumScaleFactor(0.85)
    }

    private func lifetimeCell(
        label: String,
        value: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            lifetimeCellLabel(label, accentColor: color)

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

        let hasResolved = battleSteps != nil
        let finalizedDays = battleSteps?.finalizedBattleDayCount ?? 0
        let matchesPlayed = battleStats.matchesPlayed
        let showsEmptyMatchHint = hasResolved && finalizedDays == 0 && matchesPlayed == 0

        let daysCompeted: Int? = hasResolved ? finalizedDays : nil

        return StatsLifetimeDisplay(
            totalBattleSteps: battleSteps.map(\.allTimeSteps),
            battlesCompleted: hasResolved ? matchesPlayed : nil,
            daysCompeted: daysCompeted,
            extraMilesWalked: extraMiles,
            extraStepsWalked: bonusSteps,
            hasResolvedBattleSteps: hasResolved,
            showsEmptyMatchHint: showsEmptyMatchHint
        )
    }
}
