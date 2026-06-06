//
//  StatsAchievementsGrid.swift
//  FitUp
//

import SwiftUI

struct StatsAchievementsGrid: View {
    let achievements: [StatsAchievementItem]

    private var unlockedCount: Int {
        achievements.filter(\.isUnlocked).count
    }

    var body: some View {
        if !achievements.isEmpty {
            BattleStatsTheme.battleStatsCard(accent: .warm) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        BattleStatsTheme.sectionLabel("ACHIEVEMENTS", accent: .warm)
                        Spacer()
                        Text("\(unlockedCount) / \(achievements.count)")
                            .battleStatsStyle(.label, size: BattleStatsTheme.Typography.caption, accent: .warm)
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                        ],
                        spacing: 8
                    ) {
                        ForEach(achievements) { item in
                            achievementCell(item)
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Achievements, \(unlockedCount) of \(achievements.count) unlocked")
        }
    }

    private func achievementCell(_ item: StatsAchievementItem) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 4) {
                Text(item.kind.icon)
                    .font(.system(size: 29))
                    .grayscale(item.isUnlocked ? 0 : 1)
                    .opacity(item.isUnlocked ? 1 : 0.45)

                Group {
                    if item.isUnlocked {
                        Text(item.kind.title)
                            .font(.system(size: BattleStatsTheme.Typography.captionSmall, weight: .medium, design: .monospaced))
                            .foregroundStyle(BattleStatsTheme.gold)
                    } else {
                        Text(item.kind.title)
                            .font(.system(size: BattleStatsTheme.Typography.captionSmall, weight: .medium, design: .monospaced))
                            .battleStatsStyle(.label, size: BattleStatsTheme.Typography.captionSmall, accent: .warm)
                    }
                }
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(item.isUnlocked ? BattleStatsTheme.gold.opacity(0.08) : Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        item.isUnlocked ? BattleStatsTheme.gold.opacity(0.25) : BattleStatsTheme.cardBorder,
                        lineWidth: 1
                    )
            }

            if let multiplier = item.multiplier, multiplier > 1 {
                Text("x\(multiplier)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(BattleStatsTheme.textPrimary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(BattleStatsTheme.gold.opacity(0.85))
                    .clipShape(Capsule())
                    .offset(x: 4, y: -4)
            }
        }
        .accessibilityLabel("\(item.kind.title), \(item.isUnlocked ? "unlocked" : "locked")")
    }
}
