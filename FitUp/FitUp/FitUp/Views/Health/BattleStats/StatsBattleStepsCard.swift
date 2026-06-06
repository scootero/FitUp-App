//
//  StatsBattleStepsCard.swift
//  FitUp
//

import SwiftUI

struct StatsBattleStepsCard: View {
    let display: StatsBattleStepsDisplay?
    var onShowMetricExplainer: (StatsMetricExplainerKind) -> Void = { _ in }

    private static let subCardMinHeight: CGFloat = 124
    private static let subCardCornerRadius: CGFloat = 16
    private static let avgBattleDayTint = BattleStatsTheme.gold

    var body: some View {
        let todaySteps = display?.todaySteps ?? 0
        let allTimeSteps = display?.allTimeSteps ?? 0
        let isTodayBattleDay = display?.isTodayBattleDay == true
        let hasData = display != nil
        let avgSteps = display?.averageFinalizedBattleDaySteps

        BattleStatsTheme.battleStatsCard {
            VStack(alignment: .leading, spacing: 12) {
                BattleStatsTheme.sectionTitle("BATTLE STEPS", accent: .warm)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                    ],
                    spacing: 8
                ) {
                    subCard(
                        title: "TODAY'S BATTLE STEPS",
                        explainer: .todaysBattleSteps,
                        value: isTodayBattleDay ? todaySteps : nil,
                        subtitle: isTodayBattleDay
                            ? "Live steps on a battle day"
                            : "No steps battle today",
                        valueTint: BattleStatsTheme.green
                    )
                    subCard(
                        title: "ALL-TIME BATTLE STEPS",
                        explainer: .allTimeBattleSteps,
                        value: hasData ? allTimeSteps : nil,
                        subtitle: "Total on battle days",
                        valueTint: BattleStatsTheme.blue
                    )
                }

                avgBattleDayFullWidthCard(
                    value: avgSteps,
                    subtitle: "Per completed battle day"
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Battle steps")
    }

    private func avgBattleDayFullWidthCard(value: Int?, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Text("AVG BATTLE DAY")
                .font(.system(size: BattleStatsTheme.Typography.caption, weight: .heavy, design: .rounded))
                .tracking(1)
                .battleStatsStyle(.primary, size: BattleStatsTheme.Typography.caption, weight: .heavy, accent: .warm)
                .frame(maxWidth: .infinity)

            if let value {
                Text(value.formatted())
                    .font(.system(size: 41, weight: .black, design: .monospaced))
                    .foregroundStyle(Self.avgBattleDayTint)
                    .shadow(color: Self.avgBattleDayTint.opacity(0.45), radius: 10)
                    .frame(maxWidth: .infinity)
            } else {
                Text(BattleStatsTheme.unresolvedPlaceholder)
                    .font(.system(size: 41, weight: .black, design: .monospaced))
                    .foregroundStyle(Self.avgBattleDayTint)
                    .frame(maxWidth: .infinity)
            }

            Text(subtitle)
                .battleStatsStyle(.secondary, size: BattleStatsTheme.Typography.bodySmall, accent: .warm)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: Self.subCardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Self.avgBattleDayTint.opacity(0.2),
                            Self.avgBattleDayTint.opacity(0.06),
                            FitUpColors.Neon.yellow.opacity(0.1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: Self.subCardCornerRadius, style: .continuous)
                .strokeBorder(Self.avgBattleDayTint.opacity(0.28), lineWidth: 1)
        }
        .statsCardMetricInfoCorner(kind: .avgBattleDay, accent: .warm, onShow: onShowMetricExplainer)
    }

    private func subCard(
        title: String,
        explainer: StatsMetricExplainerKind,
        value: Int?,
        subtitle: String,
        valueTint: Color
    ) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: BattleStatsTheme.Typography.caption, weight: .heavy))
                .tracking(0.5)
                .battleStatsStyle(.primary, size: BattleStatsTheme.Typography.caption, weight: .heavy, accent: .warm)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)

            if let value {
                StatsAnimatedStepCount(value: value, tint: valueTint, centered: true)
            } else {
                Text(BattleStatsTheme.unresolvedPlaceholder)
                    .font(.system(size: 31, weight: .black, design: .monospaced))
                    .foregroundStyle(valueTint)
                    .frame(maxWidth: .infinity)
            }

            Text(subtitle)
                .battleStatsStyle(.secondary, size: BattleStatsTheme.Typography.caption, accent: .warm)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, minHeight: Self.subCardMinHeight, alignment: .center)
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
        .statsCardMetricInfoCorner(kind: explainer, accent: .warm, onShow: onShowMetricExplainer)
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
            .font(.system(size: 31, weight: .black, design: .monospaced))
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
