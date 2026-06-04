//
//  StatsBattleStepsCard.swift
//  FitUp
//

import SwiftUI

struct StatsBattleStepsCard: View {
    let display: StatsBattleStepsDisplay?

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
                BattleStatsTheme.sectionTitle("BATTLE STEPS")

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                    ],
                    spacing: 8
                ) {
                    subCard(
                        title: "TODAY'S BATTLE STEPS",
                        value: isTodayBattleDay ? todaySteps : nil,
                        subtitle: isTodayBattleDay
                            ? "Live steps on a battle day"
                            : "No steps battle today",
                        valueTint: BattleStatsTheme.green
                    )
                    subCard(
                        title: "ALL-TIME BATTLE STEPS",
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
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1)
                .foregroundStyle(BattleStatsTheme.textPrimary)
                .frame(maxWidth: .infinity)

            if let value {
                Text(value.formatted())
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .foregroundStyle(Self.avgBattleDayTint)
                    .shadow(color: Self.avgBattleDayTint.opacity(0.45), radius: 10)
                    .frame(maxWidth: .infinity)
            } else {
                Text(BattleStatsTheme.unresolvedPlaceholder)
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .foregroundStyle(Self.avgBattleDayTint)
                    .frame(maxWidth: .infinity)
            }

            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(BattleStatsTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: Self.subCardCornerRadius, style: .continuous)
                .fill(Self.avgBattleDayTint.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Self.subCardCornerRadius, style: .continuous)
                .strokeBorder(Self.avgBattleDayTint.opacity(0.28), lineWidth: 1)
        }
    }

    private func subCard(
        title: String,
        value: Int?,
        subtitle: String,
        valueTint: Color
    ) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(BattleStatsTheme.textPrimary.opacity(0.92))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)

            if let value {
                StatsAnimatedStepCount(value: value, tint: valueTint, centered: true)
            } else {
                Text(BattleStatsTheme.unresolvedPlaceholder)
                    .font(.system(size: 26, weight: .black, design: .monospaced))
                    .foregroundStyle(valueTint)
                    .frame(maxWidth: .infinity)
            }

            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(BattleStatsTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, minHeight: Self.subCardMinHeight, alignment: .center)
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: Self.subCardCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.04))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Self.subCardCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
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
            .font(.system(size: 26, weight: .black, design: .monospaced))
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
