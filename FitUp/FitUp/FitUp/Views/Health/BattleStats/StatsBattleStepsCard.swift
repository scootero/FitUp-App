//
//  StatsBattleStepsCard.swift
//  FitUp
//

import SwiftUI

struct StatsBattleStepsCard: View {
    let display: StatsBattleStepsDisplay?
    var onShowCombinedMetricExplainer: ([StatsMetricExplainerKind]) -> Void = { _ in }

    private static let subCardMinHeight: CGFloat = 124
    private static let subCardCornerRadius: CGFloat = 16
    private static let subCardTitleMinHeight: CGFloat = 34
    private static let avgBattleDayTint = BattleStatsTheme.gold
    private static let subCardLabelSize = BattleStatsTheme.Typography.caption * 0.9
    private static let subCardSubtitleSize = BattleStatsTheme.Typography.caption * 0.9
    private static let metricValueSize: CGFloat = 24

    private static let explainerKinds: [StatsMetricExplainerKind] = [
        .allTimeBattleSteps,
        .avgBattleDay,
    ]

    var body: some View {
        let allTimeSteps = display?.allTimeSteps ?? 0
        let hasResolvedDisplay = display != nil
        let finalizedDays = display?.finalizedBattleDayCount ?? 0
        let avgSteps = display?.averageFinalizedBattleDaySteps
        let showsEmptyMatchHint = hasResolvedDisplay && finalizedDays == 0

        BattleStatsTheme.battleStatsCard(accent: .warm) {
            VStack(alignment: .leading, spacing: 12) {
                BattleStatsTheme.sectionHeaderRow(
                    title: "BATTLE STEPS",
                    accent: .warm,
                    showsNoBattleDataBadge: showsEmptyMatchHint
                )

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                    ],
                    spacing: 8
                ) {
                    subCard(
                        title: "ALL-TIME BATTLE STEPS",
                        value: hasResolvedDisplay ? allTimeSteps : nil,
                        subtitleLines: ["Total on", "battle days"],
                        valueTint: BattleStatsTheme.blue
                    )
                    subCard(
                        title: "AVERAGE BATTLE DAY STEPS",
                        value: hasResolvedDisplay ? (avgSteps ?? 0) : nil,
                        subtitleLines: ["Per completed", "battle day"],
                        valueTint: Self.avgBattleDayTint
                    )
                }

                if showsEmptyMatchHint {
                    BattleStatsTheme.completeMatchFirstFooter
                }
            }
        }
        .statsCardCombinedMetricInfoCorner(
            kinds: Self.explainerKinds,
            accent: .warm,
            onShow: onShowCombinedMetricExplainer
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Battle steps")
    }

    private func subCard(
        title: String,
        value: Int?,
        subtitleLines: [String],
        valueTint: Color
    ) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: Self.subCardLabelSize, weight: .heavy))
                .tracking(0.5)
                .battleStatsStyle(.primary, size: Self.subCardLabelSize, weight: .heavy, accent: .warm)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, minHeight: Self.subCardTitleMinHeight, alignment: .top)

            Spacer(minLength: 6)

            if let value {
                StatsAnimatedStepCount(value: value, tint: valueTint, centered: true)
            } else {
                Text(BattleStatsTheme.unresolvedPlaceholder)
                    .font(.system(size: Self.metricValueSize, weight: .bold, design: .monospaced))
                    .foregroundStyle(valueTint)
                    .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 6)

            VStack(spacing: 2) {
                ForEach(subtitleLines, id: \.self) { line in
                    Text(line)
                        .battleStatsStyle(.secondary, size: Self.subCardSubtitleSize, accent: .warm)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, minHeight: Self.subCardMinHeight, alignment: .top)
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: Self.subCardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            valueTint.opacity(0.18),
                            valueTint.opacity(0.05),
                            valueTint.opacity(0.12),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: Self.subCardCornerRadius, style: .continuous)
                .strokeBorder(valueTint.opacity(0.28), lineWidth: 0.5)
        }
    }
}

// MARK: - Animated step count

struct StatsAnimatedStepCount: View {
    let value: Int
    let tint: Color
    var centered: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedValue: Int = 0

    var body: some View {
        Text(displayedValue.formatted())
            .font(.system(size: 24, weight: .bold, design: .monospaced))
            .foregroundStyle(tint)
            .shadow(color: tint.opacity(0.45), radius: 8)
            .contentTransition(.numericText())
            .frame(maxWidth: centered ? .infinity : nil, alignment: centered ? .center : .leading)
            .onAppear {
                displayedValue = value
            }
            .onChange(of: value) { oldValue, newValue in
                if reduceMotion {
                    displayedValue = newValue
                } else if newValue > oldValue {
                    withAnimation(.linear(duration: 0.5)) {
                        displayedValue = newValue
                    }
                } else {
                    displayedValue = newValue
                }
            }
    }
}
