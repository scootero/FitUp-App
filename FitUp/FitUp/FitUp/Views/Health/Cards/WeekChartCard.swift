//
//  WeekChartCard.swift
//  FitUp
//
//  Slice 12 — 7-day trend + all-time bests (`HealthScreen` “Your Stats”).
//

import SwiftUI

struct WeekChartCard: View {
    @Binding var statsTab: HealthViewModel.StatsTab
    let weekSteps: [Int]
    let weekCalories: [Int]
    let stepsGoal: Int
    let caloriesGoal: Int
    let todaySteps: Int
    let todayCalories: Int

    @State private var barAnim = false
    @State private var selectedDayIndex = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tabToggle
                .padding(.bottom, 16)

            Text("7-DAY TREND")
                .font(FitUpFont.body(10, weight: .heavy))
                .fitUpHealthSectionTitleStyle(weight: .heavy, tracking: 2)
                .padding(.bottom, 8)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(selectedDayLabel.uppercased())
                    .font(FitUpFont.body(10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(FitUpColors.HealthOnLight.tertiary)
                Text(selectedDayValueLabel)
                    .font(FitUpFont.display(22, weight: .bold))
                    .foregroundStyle(goalColor)
            }
            .padding(.bottom, 10)

            miniBars
                .padding(.bottom, 12)

            HStack {
                HStack(spacing: 0) {
                    Text("Today: ")
                        .font(FitUpFont.body(11))
                        .foregroundStyle(FitUpColors.HealthOnLight.secondary)
                    Text("\(valueToday)")
                        .font(FitUpFont.body(11, weight: .bold))
                        .foregroundStyle(FitUpColors.HealthOnLight.primary)
                }
                Spacer()
                HStack(spacing: 0) {
                    Text("Goal: ")
                        .font(FitUpFont.body(11))
                        .foregroundStyle(FitUpColors.HealthOnLight.secondary)
                    Text("\(valueGoal)")
                        .font(FitUpFont.body(11, weight: .bold))
                        .foregroundStyle(goalColor)
                }
            }
            .padding(.bottom, 6)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.black.opacity(0.08))
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
            .padding(.bottom, 4)
        }
        .padding(18)
        .healthGamifiedCard(.weekChart)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                barAnim = true
            }
            selectedDayIndex = min(max(selectedDayIndex, 0), 6)
        }
        .onChange(of: statsTab) { _, _ in
            barAnim = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                barAnim = true
            }
            selectedDayIndex = 6
        }
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

    private var safeSelectedDayIndex: Int {
        min(max(selectedDayIndex, 0), max(0, currentWeek.count - 1))
    }

    private var selectedDayValue: Int {
        guard !currentWeek.isEmpty else { return 0 }
        return currentWeek[safeSelectedDayIndex]
    }

    private var selectedDayValueLabel: String {
        statsTab == .steps
            ? "\(selectedDayValue.formatted()) steps"
            : "\(selectedDayValue.formatted()) cal"
    }

    private var bestDayIndex: Int? {
        guard let maxValue = currentWeek.max(), maxValue > 0 else { return nil }
        return currentWeek.lastIndex(of: maxValue)
    }

    private var selectedDayLabel: String {
        guard currentWeek.count == 7 else { return "Selected Day" }
        let labels = weekdayLabels
        guard safeSelectedDayIndex < labels.count else { return "Selected Day" }
        return labels[safeSelectedDayIndex]
    }

    private var weekdayLabels: [String] {
        var calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.dateFormat = "EEE"
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -(6 - offset), to: today) else { return nil }
            return formatter.string(from: day).uppercased()
        }
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
                        .foregroundStyle(statsTab == tab ? Color.black : FitUpColors.HealthOnLight.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.black.opacity(0.06))
        .clipShape(Capsule())
    }

    private var miniBars: some View {
        let goal = valueGoal
        let labels = weekdayLabels
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<7, id: \.self) { i in
                let value = i < currentWeek.count ? currentWeek[i] : 0
                let pct = peak > 0 ? Double(value) / peak : 0
                let isToday = i == 6
                let isBest = bestDayIndex == i
                let isSelected = safeSelectedDayIndex == i
                VStack(spacing: 3) {
                    ZStack(alignment: .bottom) {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(barFill(value: value, isToday: isToday, goal: goal, isBest: isBest, isSelected: isSelected))
                            .frame(maxWidth: .infinity)
                            .frame(height: barAnim ? CGFloat(pct) * 56 : 0)
                            .animation(.easeOut(duration: 0.6).delay(Double(i) * 0.04), value: barAnim)
                            .shadow(color: (isToday || isBest || isSelected) ? goalColor.opacity(0.35) : .clear, radius: 6, y: 0)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(isSelected ? goalColor.opacity(0.7) : .clear, lineWidth: 1)
                    }
                    Text(i < labels.count ? labels[i] : "—")
                        .font(FitUpFont.body(9))
                        .foregroundStyle(
                            isSelected
                                ? goalColor
                                : (isToday ? FitUpColors.Neon.cyan : FitUpColors.HealthOnLight.tertiary)
                        )
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedDayIndex = i
                }
            }
        }
        .frame(height: 56 + 18)
        .onChange(of: currentWeek) { _, _ in
            selectedDayIndex = min(max(selectedDayIndex, 0), 6)
        }
    }

    private func barFill(
        value: Int,
        isToday: Bool,
        goal: Int,
        isBest: Bool,
        isSelected: Bool
    ) -> some ShapeStyle {
        if isToday {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [goalColor, goalColor.opacity(0.5)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
        }
        if isBest {
            return AnyShapeStyle(goalColor.opacity(0.4))
        }
        if isSelected {
            return AnyShapeStyle(goalColor.opacity(0.34))
        }
        if value >= goal {
            return AnyShapeStyle(goalColor.opacity(0.28))
        }
        return AnyShapeStyle(goalColor.opacity(0.13))
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
        todayCalories: 520
    )
    .padding()
    .background { BackgroundGradientView() }
}
