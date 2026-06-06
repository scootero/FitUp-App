//
//  StatsSummaryPillRow.swift
//  FitUp
//

import SwiftUI

struct StatsSummaryPillRow: View {
    @Binding var summaryPeriod: StatsSummaryPeriod
    let display: StatsSummaryPillDisplay

    var body: some View {
        VStack(spacing: 8) {
            summaryPeriodToggle

            HStack(spacing: 6) {
                pill(label: "RECORD", value: display.record, color: BattleStatsTheme.green)
                pill(label: "WIN RATE", value: display.winRate, color: BattleStatsTheme.gold)
                pill(label: "STREAK", value: display.streak, color: streakColor)
                pill(label: "RIVALS", value: display.rivals, color: BattleStatsTheme.blue)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var streakColor: Color {
        display.streak == BattleStatsTheme.unresolvedPlaceholder ? BattleStatsTheme.textLabel : BattleStatsTheme.orange
    }

    private var summaryPeriodToggle: some View {
        HStack(spacing: 4) {
            ForEach(StatsSummaryPeriod.allCases, id: \.self) { period in
                Button {
                    summaryPeriod = period
                } label: {
                    Text(period.pillLabel)
                        .font(.system(size: BattleStatsTheme.Typography.caption, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            BattleStatsTheme.textGradient(
                                summaryPeriod == period ? .primary : .label,
                                accent: .neutral
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(summaryPeriod == period ? Color.white.opacity(0.1) : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(BattleStatsTheme.cardBackground)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(BattleStatsTheme.cardBorder, lineWidth: 1)
        }
        .accessibilityLabel("Summary period")
    }

    private func pill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(label)
                .font(.system(size: BattleStatsTheme.Typography.caption, weight: .medium, design: .monospaced))
                .tracking(0.6)
                .battleStatsStyle(.label, accent: .warm)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.16),
                            color.opacity(0.05),
                            color.opacity(0.1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(color.opacity(0.28), lineWidth: 1)
        }
        .accessibilityLabel("\(label), \(value)")
    }
}
