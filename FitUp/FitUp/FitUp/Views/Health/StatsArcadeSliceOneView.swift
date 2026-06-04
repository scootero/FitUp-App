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
    let activeMatchEdges: [HomeActiveMatch]
    let battleStepsDisplay: StatsBattleStepsDisplay?
    let battleImpactMetric: StatsBattleImpactMetric?
    let personalRecords: StatsPersonalRecords?
    let achievements: [StatsAchievementItem]
    let isLoadingPersonalRecords: Bool
    var onOpenMatchDetails: (UUID, String) -> Void
    var onOpenChallenge: () -> Void = {}
    var onRematchRival: (ChallengePrefillOpponent) -> Void = { _ in }

    @State private var isAllRivalsSheetPresented = false
    @State private var selectedLiveBattleMatchId: UUID?

    private var topRivals: [HomeRivalStat] {
        rivalStats.sorted {
            if $0.finalizedDaysCompeted != $1.finalizedDaysCompeted {
                return $0.finalizedDaysCompeted > $1.finalizedDaysCompeted
            }
            return ($0.lastPlayedOn ?? .distantPast) > ($1.lastPlayedOn ?? .distantPast)
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

    var body: some View {
        VStack(alignment: .leading, spacing: BattleStatsTheme.sectionSpacing) {
            StatsBattleStatsHeader(subtitle: StatsBattleStatsHeader.defaultSubtitle())

            StatsSummaryPillRow(
                battleStats: battleStats,
                rivalCount: rivalStats.count,
                hasResolvedBattleStats: hasResolvedBattleStats || battleStepsDisplay != nil
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

            StatsBattleStepsCard(display: battleStepsDisplay)

            StatsLifetimeGrid(display: lifetimeDisplay)

            StatsBattleDayEffectCard(impact: battleImpactMetric)

            StatsPersonalRecordsCard(
                records: personalRecords,
                isLoading: isLoadingPersonalRecords
            )

            StatsAchievementsGrid(achievements: achievements)

            rivalsSection

            ActivityCalendarCard(
                userId: calendarUserId,
                profileTimeZoneIdentifier: profileTimeZoneIdentifier
            )
        }
        .sheet(isPresented: $isAllRivalsSheetPresented) {
            StatsArcadeAllRivalsSheet(rivals: topRivals)
        }
    }

    @ViewBuilder
    private var rivalsSection: some View {
        if !topRivals.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    BattleStatsTheme.sectionTitle("YOUR RIVALS")
                    Spacer()
                    Button("View all →") {
                        isAllRivalsSheetPresented = true
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BattleStatsTheme.green)
                    .buttonStyle(.plain)
                }

                ForEach(Array(topRivals.prefix(3))) { rival in
                    StatsCompactRivalCard(rival: rival, onRematch: {
                        onRematchRival(rival.challengePrefillOpponent())
                    })
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
            activeMatchEdges: [],
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
