//
//  StatsBattleDayEffectCard.swift
//  FitUp
//

import SwiftUI

struct StatsBattleDayEffectCard: View {
    let impact: StatsBattleImpactMetric?
    var onShowMetricExplainer: (StatsMetricExplainerKind) -> Void = { _ in }

    private var shouldShow: Bool {
        guard let impact else { return false }
        return impact.battleDaySampleCount >= 1 && impact.deltaSteps > 0
    }

    var body: some View {
        if shouldShow, let impact {
            BattleStatsTheme.battleStatsCard(accent: .mint) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            BattleStatsTheme.sectionLabel("BATTLE DAY EFFECT", accent: .mint)
                            Text("Competition makes you walk more")
                                .font(.system(size: 19, weight: .bold))
                                .battleStatsStyle(.primary, size: 19, weight: .bold, accent: .mint)
                        }
                        Spacer(minLength: 8)
                        if impact.hasEnoughSample, impact.boostPercent > 0 {
                            VStack(spacing: 2) {
                                Text("+\(impact.boostPercent)%")
                                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(BattleStatsTheme.green)
                                Text("UPLIFT")
                                    .font(.system(size: BattleStatsTheme.Typography.captionSmall, weight: .medium, design: .monospaced))
                                    .battleStatsStyle(.label, size: BattleStatsTheme.Typography.captionSmall, accent: .mint)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(BattleStatsTheme.green.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(BattleStatsTheme.green.opacity(0.3), lineWidth: 1)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        averageTile(
                            title: "Normal days",
                            value: impact.hasEnoughSample
                                ? impact.normalDayAverageSteps.formatted()
                                : BattleStatsTheme.unresolvedPlaceholder,
                            tint: BattleStatsTheme.blue.opacity(0.6),
                            emphasized: false
                        )
                        averageTile(
                            title: "Battle days",
                            value: impact.hasEnoughSample
                                ? impact.battleDayAverageSteps.formatted()
                                : BattleStatsTheme.unresolvedPlaceholder,
                            tint: BattleStatsTheme.green,
                            emphasized: true
                        )
                    }

                    if impact.hasEnoughSample {
                        HStack(spacing: 16) {
                            legendDot(color: BattleStatsTheme.green, text: "Battle days · avg \(impact.battleDayAverageSteps.formatted())")
                            legendDot(color: BattleStatsTheme.blue.opacity(0.6), text: "Normal days · avg \(impact.normalDayAverageSteps.formatted())")
                        }
                    } else {
                        needsDataPill
                    }
                }
            }
            .statsCardMetricInfoCorner(kind: .battleDayEffect, accent: .mint, onShow: onShowMetricExplainer)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Battle day effect")
        }
    }

    private var needsDataPill: some View {
        Text("NEEDS MORE DATA")
            .font(.system(size: BattleStatsTheme.Typography.captionSmall, weight: .bold))
            .battleStatsStyle(.secondary, size: BattleStatsTheme.Typography.captionSmall, weight: .bold, accent: .mint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
    }

    private func averageTile(title: String, value: String, tint: Color, emphasized: Bool) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .battleStatsStyle(.secondary, size: BattleStatsTheme.Typography.caption, weight: .semibold, accent: .mint)
            Group {
                if emphasized {
                    Text(value)
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundStyle(tint)
                } else {
                    Text(value)
                        .battleStatsStyle(.primary, size: 24, weight: .black, design: .monospaced, accent: .mint)
                }
            }
            Text("avg steps")
                .battleStatsStyle(.label, accent: .mint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(emphasized ? 0.22 : 0.12),
                            tint.opacity(emphasized ? 0.08 : 0.04),
                            tint.opacity(0.14),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(tint.opacity(emphasized ? 0.4 : 0.2), lineWidth: 1)
        }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .battleStatsStyle(.secondary, size: BattleStatsTheme.Typography.caption, accent: .mint)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
    }
}
