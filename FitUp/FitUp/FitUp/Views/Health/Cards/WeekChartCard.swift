//
//  WeekChartCard.swift
//  FitUp
//
//  Slice 12 — 7-day trend + all-time bests (`HealthScreen` “Your Stats”).
//

import SwiftUI

private let weekDayLetters = ["S", "M", "T", "W", "T", "F", "S"]

struct WeekChartCard: View {
    @Binding var statsTab: HealthViewModel.StatsTab
    let weekSteps: [Int]
    let weekCalories: [Int]
    let stepsGoal: Int
    let caloriesGoal: Int
    let todaySteps: Int
    let todayCalories: Int
    let allTimeBests: HealthAllTimeBests
    let winRateText: String
    let winCount: Int
    let matchCount: Int

    @State private var barAnim = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tabToggle
                .padding(.bottom, 16)

            Text("7-DAY TREND")
                .font(FitUpFont.body(10, weight: .heavy))
                .tracking(2)
                .foregroundStyle(FitUpColors.Text.tertiary)
                .padding(.bottom, 8)

            miniBars
                .padding(.bottom, 12)

            HStack {
                HStack(spacing: 0) {
                    Text("Today: ")
                        .font(FitUpFont.body(11))
                        .foregroundStyle(FitUpColors.Text.secondary)
                    Text("\(valueToday)")
                        .font(FitUpFont.body(11, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.primary)
                }
                Spacer()
                HStack(spacing: 0) {
                    Text("Goal: ")
                        .font(FitUpFont.body(11))
                        .foregroundStyle(FitUpColors.Text.secondary)
                    Text("\(valueGoal)")
                        .font(FitUpFont.body(11, weight: .bold))
                        .foregroundStyle(goalColor)
                }
            }
            .padding(.bottom, 6)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [goalColor, goalColor.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: barAnim ? max(0, geo.size.width * CGFloat(min(goalProgress, 1))) : 0)
                        .animation(.easeOut(duration: 0.8), value: barAnim)
                }
            }
            .frame(height: 5)
            .padding(.bottom, 16)

            Text("ALL-TIME BESTS")
                .font(FitUpFont.body(10, weight: .heavy))
                .tracking(2)
                .foregroundStyle(FitUpColors.Text.tertiary)
                .padding(.bottom, 12)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                allTimeCell(
                    title: "BEST SINGLE DAY",
                    value: statsTab == .steps ? allTimeBests.stepsBestDay : allTimeBests.calsBestDay,
                    sub: statsTab == .steps ? allTimeBests.stepsBestDaySub : allTimeBests.calsBestDaySub,
                    accent: false
                )
                allTimeCell(
                    title: "BEST WEEK TOTAL",
                    value: statsTab == .steps ? allTimeBests.stepsBestWeek : allTimeBests.calsBestWeek,
                    sub: statsTab == .steps ? allTimeBests.stepsBestWeekSub : allTimeBests.calsBestWeekSub,
                    accent: false
                )
                allTimeCell(
                    title: "BEST WIN STREAK",
                    value: streakText,
                    sub: "days · best",
                    accent: false
                )
                allTimeCell(
                    title: "BATTLE WIN RATE",
                    value: winRateText,
                    sub: "\(winCount) wins · \(max(0, matchCount - winCount)) losses",
                    accent: true
                )
            }
        }
        .padding(18)
        .glassCard(.base)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                barAnim = true
            }
        }
        .onChange(of: statsTab) { _, _ in
            barAnim = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                barAnim = true
            }
        }
    }

    private var streakText: String {
        if let d = allTimeBests.bestWinStreakDays, d > 0 { return "\(d)" }
        return "—"
    }

    private var currentWeek: [Int] {
        statsTab == .steps ? weekSteps : weekCalories
    }

    private var peak: Double {
        let m = currentWeek.max() ?? 1
        return Double(max(m, 1))
    }

    private var valueToday: Int {
        statsTab == .steps ? todaySteps : todayCalories
    }

    private var valueGoal: Int {
        statsTab == .steps ? stepsGoal : caloriesGoal
    }

    private var goalColor: Color {
        statsTab == .steps ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange
    }

    private var goalProgress: Double {
        guard valueGoal > 0 else { return 0 }
        return Double(valueToday) / Double(valueGoal)
    }

    private var tabToggle: some View {
        HStack(spacing: 0) {
            ForEach(HealthViewModel.StatsTab.allCases) { tab in
                Button {
                    statsTab = tab
                } label: {
                    Text(tab == .steps ? "Steps" : "Calories")
                        .font(FitUpFont.body(13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if statsTab == tab {
                                Capsule().fill(FitUpColors.Neon.cyan)
                            }
                        }
                        .foregroundStyle(statsTab == tab ? Color.black : FitUpColors.Text.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }

    private var miniBars: some View {
        let goal = valueGoal
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<7, id: \.self) { i in
                let value = i < currentWeek.count ? currentWeek[i] : 0
                let pct = peak > 0 ? Double(value) / peak : 0
                let isToday = i == 6
                VStack(spacing: 3) {
                    ZStack(alignment: .bottom) {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(barFill(value: value, isToday: isToday, goal: goal))
                            .frame(maxWidth: .infinity)
                            .frame(height: barAnim ? CGFloat(pct) * 56 : 0)
                            .animation(.easeOut(duration: 0.6).delay(Double(i) * 0.04), value: barAnim)
                            .shadow(color: isToday ? goalColor.opacity(0.35) : .clear, radius: 6, y: 0)
                    }
                    Text(weekDayLetters[i])
                        .font(FitUpFont.body(9))
                        .foregroundStyle(isToday ? FitUpColors.Neon.cyan : FitUpColors.Text.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 56 + 18)
    }

    private func barFill(value: Int, isToday: Bool, goal: Int) -> some ShapeStyle {
        if isToday {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [goalColor, goalColor.opacity(0.5)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
        }
        if value >= goal {
            return AnyShapeStyle(goalColor.opacity(0.28))
        }
        return AnyShapeStyle(goalColor.opacity(0.13))
    }

    private func allTimeCell(title: String, value: String, sub: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FitUpFont.body(9, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(FitUpColors.Text.tertiary)
            Text(value)
                .font(FitUpFont.display(28, weight: .bold))
                .foregroundStyle(accent ? FitUpColors.Neon.green : FitUpColors.Neon.cyan)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(sub)
                .font(FitUpFont.body(11))
                .foregroundStyle(FitUpColors.Text.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard(.base)
    }
}

#Preview {
    WeekChartCard(
        statsTab: .constant(.steps),
        weekSteps: [8200, 12_400, 9100, 13_200, 10_800, 7600, 11_240],
        weekCalories: [410, 680, 490, 720, 580, 340, 520],
        stepsGoal: 12_000,
        caloriesGoal: 650,
        todaySteps: 11_240,
        todayCalories: 520,
        allTimeBests: .empty,
        winRateText: "71%",
        winCount: 7,
        matchCount: 9
    )
    .padding()
    .background { BackgroundGradientView() }
}
