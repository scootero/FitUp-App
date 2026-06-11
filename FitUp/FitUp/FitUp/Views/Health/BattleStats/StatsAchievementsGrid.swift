//
//  StatsAchievementsGrid.swift
//  FitUp
//

import SwiftUI

struct StatsAchievementsGrid: View {
    let achievements: [StatsAchievementItem]
    @Binding var isOverflowExpanded: Bool
    var showsEmptyMatchHint: Bool = false

    private var featuredAchievements: [StatsAchievementItem] {
        StatsAchievementCatalog.featuredItems(from: achievements)
    }

    private var overflowAchievements: [StatsAchievementItem] {
        StatsAchievementCatalog.overflowItems(from: achievements)
    }

    private var unlockedCount: Int {
        achievements.filter(\.isUnlocked).count
    }

    private var overflowUnlockedCount: Int {
        overflowAchievements.filter(\.isUnlocked).count
    }

    var body: some View {
        if !achievements.isEmpty {
            BattleStatsTheme.battleStatsCard(accent: .warm) {
                VStack(alignment: .leading, spacing: 12) {
                    BattleStatsTheme.sectionHeaderRow(
                        title: "ACHIEVEMENTS",
                        accent: .warm,
                        showsNoBattleDataBadge: showsEmptyMatchHint,
                        reservesInfoButtonSpace: false
                    ) {
                        Text("\(unlockedCount) / \(achievements.count)")
                            .battleStatsStyle(.label, size: BattleStatsTheme.Typography.caption, accent: .warm)
                    }

                    achievementGrid(featuredAchievements)

                    if !overflowAchievements.isEmpty {
                        overflowExpandBar

                        if isOverflowExpanded {
                            achievementGrid(overflowAchievements)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    if showsEmptyMatchHint {
                        BattleStatsTheme.completeMatchFirstFooter
                    }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: BattleStatsTheme.cardCornerRadius, style: .continuous))
            .onTapGesture {
                guard !overflowAchievements.isEmpty else { return }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    isOverflowExpanded.toggle()
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Achievements, \(unlockedCount) of \(achievements.count) unlocked")
            .accessibilityHint(overflowAchievements.isEmpty ? "" : "Double tap to \(isOverflowExpanded ? "hide" : "show") more achievements")
        }
    }

    private var overflowExpandBar: some View {
        HStack(spacing: 6) {
            Image(systemName: isOverflowExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 11, weight: .bold))
            Text(overflowExpandBarTitle)
                .font(.system(size: BattleStatsTheme.Typography.captionSmall, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(BattleStatsTheme.achievementTitleGradient(unlocked: overflowUnlockedCount > 0))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(BattleStatsTheme.gold.opacity(isOverflowExpanded ? 0.12 : 0.06))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(BattleStatsTheme.gold.opacity(0.18), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private var overflowExpandBarTitle: String {
        if isOverflowExpanded {
            return "Show less"
        }
        if overflowUnlockedCount > 0 {
            return "\(overflowAchievements.count) more · \(overflowUnlockedCount) unlocked"
        }
        return "\(overflowAchievements.count) more"
    }

    private func achievementGrid(_ items: [StatsAchievementItem]) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ],
            spacing: 8
        ) {
            ForEach(items) { item in
                achievementCell(item)
            }
        }
    }

    private func achievementCell(_ item: StatsAchievementItem) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 4) {
                Text(item.kind.icon)
                    .font(.system(size: 29))
                    .grayscale(item.isUnlocked ? 0 : 1)
                    .opacity(item.isUnlocked ? 1 : 0.45)

                Text(item.kind.title)
                    .font(.system(size: BattleStatsTheme.Typography.captionSmall, weight: .medium, design: .monospaced))
                    .foregroundStyle(BattleStatsTheme.achievementTitleGradient(unlocked: item.isUnlocked))
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
