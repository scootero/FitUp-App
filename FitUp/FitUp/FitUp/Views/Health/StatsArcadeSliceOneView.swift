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
    var profileCreatedAt: Date? = nil
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
    @Binding var isAchievementsOverflowExpanded: Bool
    let isLoadingPersonalRecords: Bool
    var onOpenMatchDetails: (UUID, String) -> Void
    var onOpenChallenge: () -> Void = {}
    var onRematchRival: (ChallengePrefillOpponent) -> Void = { _ in }
    var onLoadCompletedMatchesIfNeeded: () -> Void = {}
    var onShowMetricExplainer: (StatsMetricExplainerKind) -> Void = { _ in }
    var onShowCombinedMetricExplainer: ([StatsMetricExplainerKind]) -> Void = { _ in }
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
            collapseAchievementsOnOutsideTap {
                StatsBattleStatsHeader(subtitle: StatsBattleStatsHeader.defaultSubtitle())
                    .padding(.bottom, 4)
            }

            collapseAchievementsOnOutsideTap {
                StatsUserStepsTodayHeroCard(
                    profileId: calendarUserId,
                    profileTimeZoneIdentifier: profileTimeZoneIdentifier,
                    stepsToday: stepsToday,
                    stepsGoal: stepsGoal,
                    domain: userIntradayDomain,
                    isLoading: isUserIntradayLoading,
                    lastUpdatedAt: stepsLastUpdatedAt,
                    onShowMetricExplainer: onShowMetricExplainer,
                    onEditStepsGoal: onEditStepsGoal
                )
            }

            collapseAchievementsOnOutsideTap {
                ActivityCalendarCard(
                    userId: calendarUserId,
                    profileTimeZoneIdentifier: profileTimeZoneIdentifier,
                    profileCreatedAt: profileCreatedAt ?? (calendarUserId != nil ? Date() : nil),
                    onOpenMatchDetails: onOpenMatchDetails
                )
            }

            if summaryPillDisplay.hasAnyResolvedMetric {
                collapseAchievementsOnOutsideTap {
                    StatsSummaryPillRow(
                        summaryPeriod: $summaryPeriod,
                        display: summaryPillDisplay
                    )
                }
            }

            if hasLiveBattles {
                collapseAchievementsOnOutsideTap {
                    StatsLiveBattleSection(
                        matches: activeMatchEdges,
                        selectedMatchId: $selectedLiveBattleMatchId,
                        onOpenMatchDetails: { match in
                            onOpenMatchDetails(match.id, match.opponent.displayName)
                        }
                    )
                }
            }

            collapseAchievementsOnOutsideTap {
                StatsBattleStepsCard(
                    display: battleStepsDisplay,
                    onShowCombinedMetricExplainer: onShowCombinedMetricExplainer
                )
            }

            collapseAchievementsOnOutsideTap {
                StatsLifetimeGrid(
                    display: lifetimeDisplay,
                    onShowCombinedMetricExplainer: onShowCombinedMetricExplainer
                )
            }

            collapseAchievementsOnOutsideTap {
                StatsBattleDayEffectCard(
                    impact: battleImpactMetric,
                    onShowMetricExplainer: onShowMetricExplainer
                )
            }

            collapseAchievementsOnOutsideTap {
                StatsPersonalRecordsCard(
                    records: personalRecords,
                    isLoading: isLoadingPersonalRecords,
                    onShowCombinedMetricExplainer: onShowCombinedMetricExplainer
                )
            }

            StatsAchievementsGrid(
                achievements: achievements,
                isOverflowExpanded: $isAchievementsOverflowExpanded,
                showsEmptyMatchHint: lifetimeDisplay.showsEmptyMatchHint
            )

            collapseAchievementsOnOutsideTap {
                rivalsSection
            }
        }
        .sheet(isPresented: $isAllRivalsSheetPresented) {
            StatsArcadeAllRivalsSheet(rivals: allRivalsSorted)
        }
    }

    private func collapseAchievementsOnOutsideTap<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    guard isAchievementsOverflowExpanded else { return }
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        isAchievementsOverflowExpanded = false
                    }
                }
            )
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
    @Previewable @State var isAchievementsOverflowExpanded = false

    ScrollView {
        StatsArcadeSliceOneView(
            calendarUserId: nil,
            profileTimeZoneIdentifier: nil,
            profileCreatedAt: nil,
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
            isAchievementsOverflowExpanded: $isAchievementsOverflowExpanded,
            isLoadingPersonalRecords: false,
            onOpenMatchDetails: { _, _ in },
            onOpenChallenge: {},
            onRematchRival: { _ in }
        )
        .padding(.horizontal, 16)
    }
    .background { BackgroundGradientView() }
}
