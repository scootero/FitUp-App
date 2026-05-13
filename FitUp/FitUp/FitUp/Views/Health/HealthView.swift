//
//  HealthView.swift
//  FitUp
//
//  Slice 12 — `HealthScreen` (FitUp_Final_Mockup.jsx).
//

import SwiftUI
import UIKit

struct HealthView: View {
    let profile: Profile?
    var onOpenMatchDetails: (UUID, String) -> Void

    @StateObject private var viewModel = HealthViewModel()
    @Environment(\.openURL) private var openURL
    @State private var isPastMatchesExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StatsMockShellView(
                    selectedRange: viewModel.statsSelectedRange,
                    effectiveRange: viewModel.statsEffectiveRange,
                    onSelectRange: { range in
                        Task { await viewModel.setStatsRange(range) }
                    },
                    dateChipText: viewModel.statsRangeDateChipText,
                    rangeScopeNote: viewModel.statsRangeScopeNote,
                    previousPeriodPercent: viewModel.statsPreviousPeriodPercent,
                    battleStatsScopeLabel: viewModel.statsBattleStatsScopeLabel,
                    rangeMargins: viewModel.statsRangeMargins,
                    isRangeMarginsLoading: viewModel.isStatsRangeMarginsRefreshing,
                    dailyMargins: viewModel.dailyBattleMargins,
                    dailyMarginDayCount: viewModel.marginChartDayCount,
                    dailyMarginsSavedAt: viewModel.battleMarginsSavedAt,
                    isDailyMarginsRefreshing: viewModel.isBattleMarginsRefreshing,
                    onSelectDailyMarginDayCount: { n in
                        Task { await viewModel.setMarginChartDayCount(n) }
                    },
                    battleStats: viewModel.battleStats,
                    weekSteps: viewModel.weekSteps,
                    activeMatchEdges: viewModel.activeMatchEdges,
                    rivalStats: viewModel.rivalStats,
                    isRivalStatsLoading: viewModel.isRivalStatsLoading,
                    hasLoadedRivalStats: viewModel.hasLoadedRivalStats,
                    oneDayHourlySteps: viewModel.oneDayHourlySteps,
                    isOneDayHourlyLoading: viewModel.isOneDayHourlyLoading
                )
                    .padding(.bottom, 10)

                healthSectionLabel("Your Stats")
                WeekChartCard(
                    statsTab: $viewModel.statsTab,
                    weekSteps: viewModel.weekSteps,
                    weekCalories: viewModel.weekCalories,
                    stepsGoal: viewModel.goals.stepsGoal,
                    caloriesGoal: viewModel.goals.calsGoal,
                    todaySteps: viewModel.stepsTodayValue,
                    todayCalories: viewModel.caloriesTodayValue
                )
                .padding(.bottom, 14)

                WeekComparisonCard(comparison: viewModel.selectedWeekComparison)
                    .padding(.bottom, 14)

                ConsistencyCard(consistency: viewModel.goalConsistency)
                    .padding(.bottom, 14)

                legacyHealthDivider
                    .padding(.bottom, 14)

                header
                    .padding(.bottom, 14)

                if viewModel.showHealthAccessBanner {
                    healthAccessBanner
                        .padding(.bottom, 14)
                }

                BattleReadinessCard(
                    score: viewModel.battleReadinessScore,
                    title: viewModel.battleReadinessLabel,
                    subtitle: viewModel.battleReadinessSubtitle,
                    hrText: viewModel.restingHRDisplay,
                    stepsText: viewModel.stepsTodayDisplay,
                    calsText: viewModel.caloriesTodayDisplay
                )
                .padding(.bottom, 14)

                ComponentBreakdownCard(
                    goals: viewModel.goals,
                    restingHR: viewModel.restingHRValue,
                    stepsToday: viewModel.stepsTodayValue,
                    calsToday: viewModel.caloriesTodayValue
                )
                .padding(.bottom, 14)

                BattleStatsCard(stats: viewModel.battleStats)
                    .padding(.bottom, 14)

                HealthPastMatchesCard(
                    matches: viewModel.completedMatches,
                    isExpanded: isPastMatchesExpanded,
                    isLoading: viewModel.isLoadingCompletedMatches,
                    onToggleExpanded: {
                        isPastMatchesExpanded.toggle()
                        if isPastMatchesExpanded {
                            Task { await viewModel.loadCompletedMatchesIfNeeded() }
                        }
                    },
                    onOpenMatch: { match in
                        onOpenMatchDetails(match.id, match.opponentName)
                    }
                )
                .padding(.bottom, 14)

                if let err = viewModel.errorMessage {
                    Text(err)
                        .font(FitUpFont.body(12))
                        .foregroundStyle(FitUpColors.Neon.pink)
                        .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await viewModel.reload(source: "pull_refresh")
        }
        .task {
            viewModel.start(profile: profile)
        }
        .onAppear {
            if let uid = profile?.id {
                AppLogger.log(
                    category: "healthkit_read",
                    level: .info,
                    message: "Health tab appeared",
                    userId: uid,
                    metadata: ["pipeline": "HealthView.onAppear"]
                )
            }
        }
        .onChange(of: profile?.id) { _, _ in
            viewModel.start(profile: profile)
        }
    }

    private var healthAccessBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Apple Health access is off for FitUp. Enable read access for Steps, Active Energy, and related data in Settings.")
                .font(FitUpFont.body(12))
                .foregroundStyle(FitUpColors.Text.secondary)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                Text("Open Settings")
                    .font(FitUpFont.body(12, weight: .semibold))
                    .foregroundStyle(FitUpColors.Neon.cyan)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(.base)
    }

    private var header: some View {
        HStack {
            Text("Health")
                .font(FitUpFont.display(22, weight: .heavy))
                .fitUpGlobalTitleStyle(weight: .heavy, tracking: 0.3)
            Spacer()
            if viewModel.showSyncedBadge {
                NeonBadge(label: "SYNCED", color: FitUpColors.Neon.green)
            }
        }
        .padding(.top, 10)
    }

    private var legacyHealthDivider: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)

            Text("Legacy Health content below — temporary")
                .font(FitUpFont.body(10, weight: .medium))
                .foregroundStyle(FitUpColors.Text.tertiary)

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }

    private func healthSectionLabel(_ text: String) -> some View {
        HStack {
            Text(text.uppercased())
                .font(FitUpFont.body(11, weight: .heavy))
                .fitUpGlobalTitleStyle(weight: .heavy, tracking: 2)
            Spacer()
        }
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

}

#Preview {
    HealthView(profile: nil, onOpenMatchDetails: { _, _ in })
        .background { BackgroundGradientView() }
}
