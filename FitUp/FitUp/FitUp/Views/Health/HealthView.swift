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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
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
                    sleepText: viewModel.sleepHoursDisplay,
                    hrText: viewModel.restingHRDisplay,
                    stepsText: viewModel.stepsTodayDisplay,
                    calsText: viewModel.caloriesTodayDisplay
                )
                .padding(.bottom, 14)

                ComponentBreakdownCard(
                    goals: viewModel.goals,
                    sleepHours: viewModel.sleepLastNightHours,
                    restingHR: viewModel.restingHRValue,
                    stepsToday: viewModel.stepsTodayValue,
                    calsToday: viewModel.caloriesTodayValue
                )
                .padding(.bottom, 14)

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

                BattleStatsCard(stats: viewModel.battleStats)
                    .padding(.bottom, 14)

                healthSectionLabel("Sleep Quality")
                HStack(alignment: .top, spacing: 10) {
                    LastNightSleepCard(summary: viewModel.sleepSummary)
                    SleepRatioCard(summary: viewModel.sleepSummary)
                }
                .padding(.bottom, 10)
                SevenNightSleepAverageCard(summary: viewModel.sleepSummary)
                    .padding(.bottom, 14)

                CompetitionEdgeTodaySection(matches: viewModel.activeMatchEdges)
                    .padding(.bottom, 20)

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
