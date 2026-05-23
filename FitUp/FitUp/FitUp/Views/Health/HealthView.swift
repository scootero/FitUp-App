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

    @StateObject private var viewModel = HealthViewModel()
    @Environment(\.openURL) private var openURL
    @State private var statsMetricExplainer: StatsMetricExplainerKind?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.showHealthAccessBanner {
                    healthAccessBanner
                        .padding(.bottom, 10)
                }

                if let err = viewModel.errorMessage {
                    Text(err)
                        .font(FitUpFont.body(12))
                        .foregroundStyle(FitUpColors.Neon.pink)
                        .padding(.bottom, 10)
                }

                StatsMockShellView(
                    calendarUserId: profile?.id,
                    profileTimeZoneIdentifier: profile?.timezone,
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
                    statsSnapshotSavedAt: viewModel.statsSnapshotSavedAt,
                    battleStats: viewModel.battleStats,
                    weekSteps: viewModel.weekSteps,
                    activeMatchEdges: viewModel.activeMatchEdges,
                    rivalStats: viewModel.rivalStats,
                    isRivalStatsLoading: viewModel.isRivalStatsLoading,
                    hasLoadedRivalStats: viewModel.hasLoadedRivalStats,
                    oneDayHourlySteps: viewModel.oneDayHourlySteps,
                    isOneDayHourlyLoading: viewModel.isOneDayHourlyLoading,
                    stepsToday: viewModel.stepsTodayValue,
                    activeExplainer: $statsMetricExplainer
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
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .overlay {
            if let explainer = statsMetricExplainer {
                StatsMetricExplainerOverlay(
                    kind: explainer,
                    onDismiss: { statsMetricExplainer = nil }
                )
            }
        }
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
    HealthView(profile: nil)
        .background { BackgroundGradientView() }
}
