//
//  StatsArcadeSliceOneView.swift
//  FitUp
//
//  Battle Stats page — composes BattleStats section components.
//

import SwiftUI

struct StatsArcadeSliceOneView: View {
    let calendarUserId: UUID?
    let profileTimeZoneIdentifier: String?
    let battleStats: HealthBattleStats
    let rivalStats: [HomeRivalStat]
    let completedMatches: [ActivityCompletedMatch]
    let isLoadingCompletedMatches: Bool
    let activeMatchEdges: [HomeActiveMatch]
    let stepsToday: Int
    let stepsGoal: Int
    let userIntradayDomain: StatsUserIntradayDomain?
    let isUserIntradayLoading: Bool
    let stepsLastUpdatedAt: Date?
    let battleStepsDisplay: StatsBattleStepsDisplay?
    let battleImpactMetric: StatsBattleImpactMetric?
    let personalRecords: StatsPersonalRecords?
    let achievements: [StatsAchievementItem]
    let isLoadingPersonalRecords: Bool
    var onOpenMatchDetails: (UUID, String) -> Void
    var onOpenChallenge: () -> Void = {}
    var onRematchRival: (ChallengePrefillOpponent) -> Void = { _ in }
    var onLoadCompletedMatchesIfNeeded: () -> Void = {}
    var onShowMetricExplainer: (StatsMetricExplainerKind) -> Void = { _ in }
    var onEditStepsGoal: () -> Void = {}

    @State private var isAllRivalsSheetPresented = false
    @State private var selectedLiveBattleMatchId: UUID?
    @State private var summaryPeriod: StatsSummaryPeriod = .allTime

    private var featuredRivalSlots: [StatsRivalSlot] {
        StatsRivalSelection.pick(from: rivalStats)
    }

    private var allRivalsSorted: [HomeRivalStat] {
        rivalStats.sorted { lhs, rhs in
            if lhs.completedMatchCount != rhs.completedMatchCount {
                return lhs.completedMatchCount > rhs.completedMatchCount
            }
            return (lhs.lastPlayedOn ?? .distantPast) > (rhs.lastPlayedOn ?? .distantPast)
        }
    }

    private var lifetimeDisplay: StatsLifetimeDisplay {
        StatsLifetimeDisplay.make(
            battleSteps: battleStepsDisplay,
            battleStats: battleStats,
            impact: battleImpactMetric
        )
    }

    private var hasLiveBattles: Bool {
        !StatsLiveBattleSelection.sortedEligibleStepMatches(from: activeMatchEdges).isEmpty
    }

    private var hasResolvedBattleStats: Bool {
        battleStats.matchesPlayed > 0
            || battleStepsDisplay != nil
            || !rivalStats.isEmpty
    }

    private var summaryPillDisplay: StatsSummaryPillDisplay {
        StatsSummaryPillBuilder.build(
            period: summaryPeriod,
            battleStats: battleStats,
            rivalStats: rivalStats,
            completedMatches: completedMatches,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier,
            hasResolvedBattleStats: hasResolvedBattleStats || battleStepsDisplay != nil
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BattleStatsTheme.sectionSpacing) {
            StatsBattleStatsHeader(subtitle: StatsBattleStatsHeader.defaultSubtitle())
                .padding(.bottom, 4)

            StatsUserStepsTodayHeroCard(
                stepsToday: stepsToday,
                stepsGoal: stepsGoal,
                domain: userIntradayDomain,
                isLoading: isUserIntradayLoading,
                lastUpdatedAt: stepsLastUpdatedAt,
                onShowMetricExplainer: onShowMetricExplainer,
                onEditStepsGoal: onEditStepsGoal
            )

            StatsSummaryPillRow(
                summaryPeriod: $summaryPeriod,
                display: summaryPillDisplay
            )

            if hasLiveBattles {
                StatsLiveBattleSection(
                    matches: activeMatchEdges,
                    selectedMatchId: $selectedLiveBattleMatchId,
                    onOpenMatchDetails: { match in
                        onOpenMatchDetails(match.id, match.opponent.displayName)
                    }
                )
            }

            StatsBattleStepsCard(
                display: battleStepsDisplay,
                onShowMetricExplainer: onShowMetricExplainer
            )

            StatsLifetimeGrid(
                display: lifetimeDisplay,
                onShowMetricExplainer: onShowMetricExplainer
            )

            StatsBattleDayEffectCard(
                impact: battleImpactMetric,
                onShowMetricExplainer: onShowMetricExplainer
            )

            StatsPersonalRecordsCard(
                records: personalRecords,
                isLoading: isLoadingPersonalRecords,
                onShowMetricExplainer: onShowMetricExplainer
            )

            StatsAchievementsGrid(achievements: achievements)

            rivalsSection

            ActivityCalendarCard(
                userId: calendarUserId,
                profileTimeZoneIdentifier: profileTimeZoneIdentifier,
                onOpenMatchDetails: onOpenMatchDetails
            )
        }
        .sheet(isPresented: $isAllRivalsSheetPresented) {
            StatsArcadeAllRivalsSheet(rivals: allRivalsSorted)
        }
    }

    @ViewBuilder
    private var rivalsSection: some View {
        if !featuredRivalSlots.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    BattleStatsTheme.sectionTitle("YOUR RIVALS", accent: .cool)
                    Spacer()
                    Button("View all →") {
                        isAllRivalsSheetPresented = true
                    }
                    .font(.system(size: BattleStatsTheme.Typography.captionSmall, weight: .semibold))
                    .foregroundStyle(BattleStatsTheme.green)
                    .buttonStyle(.plain)
                }

                ForEach(featuredRivalSlots) { slot in
                    StatsCompactRivalCard(
                        category: slot.category,
                        rival: slot.rival,
                        completedMatches: completedMatches,
                        isLoadingCompletedMatches: isLoadingCompletedMatches,
                        onRematch: {
                            onRematchRival(slot.rival.challengePrefillOpponent())
                        },
                        onOpenMatchDetails: onOpenMatchDetails,
                        onLoadCompletedMatchesIfNeeded: onLoadCompletedMatchesIfNeeded
                    )
                }
            }
        }

        StatsChallengeSomeoneCard(onChallenge: onOpenChallenge)
    }
}

#Preview {
    ScrollView {
        StatsArcadeSliceOneView(
            calendarUserId: nil,
            profileTimeZoneIdentifier: nil,
            battleStats: .empty,
            rivalStats: [],
            completedMatches: [],
            isLoadingCompletedMatches: false,
            activeMatchEdges: [],
            stepsToday: 8_432,
            stepsGoal: 12_000,
            userIntradayDomain: nil,
            isUserIntradayLoading: false,
            stepsLastUpdatedAt: Date().addingTimeInterval(-180),
            battleStepsDisplay: StatsBattleStepsDisplay(
                todaySteps: 8420,
                allTimeSteps: 1_204_500,
                isTodayBattleDay: true,
                finalizedBattleDayCount: 12,
                averageFinalizedBattleDaySteps: 9_850
            ),
            battleImpactMetric: nil,
            personalRecords: nil,
            achievements: StatsAchievementCatalog.allItems(),
            isLoadingPersonalRecords: false,
            onOpenMatchDetails: { _, _ in },
            onOpenChallenge: {},
            onRematchRival: { _ in }
        )
        .padding(.horizontal, 16)
    }
    .background { BackgroundGradientView() }
}
