//
//  SevenNightSleepOverviewCard.swift
//  FitUp
//
//  7-night average + daily sleep hours as bars.
//

import SwiftUI

struct SevenNightSleepOverviewCard: View {
    let summary: HealthSleepSummary?

    @State private var barAnim = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("7-NIGHT AVG")
                .font(FitUpFont.mono(10))
                .tracking(1)
                .foregroundStyle(FitUpColors.Text.tertiary)
                .padding(.bottom, 8)

            Text(avgText)
                .font(FitUpFont.display(22, weight: .bold))
                .foregroundStyle(FitUpColors.Text.primary)
                .padding(.bottom, 4)

            Text("±\(varianceText)h variance")
                .font(FitUpFont.body(11))
                .foregroundStyle(FitUpColors.Text.tertiary)
                .padding(.bottom, 12)

            sleepBars
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(.base)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                barAnim = true
            }
        }
    }

    private var hours: [Double] {
        summary?.nightlyAsleepHoursOldestFirst ?? []
    }

    private var peakHours: Double {
        let m = hours.max() ?? 0
        return max(m, 0.25)
    }

    private var avgText: String {
        guard let s = summary else { return "—" }
        return String(format: "%.1f hrs", s.averageHoursLastNights)
    }

    private var varianceText: String {
        guard let s = summary else { return "—" }
        return String(format: "%.1f", s.varianceHours)
    }

    private var sleepBars: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<7, id: \.self) { i in
                let h = i < hours.count ? hours[i] : 0
                let pct = peakHours > 0 ? min(h / peakHours, 1) : 0
                let isToday = i == 6
                VStack(spacing: 3) {
                    ZStack(alignment: .bottom) {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(barFill(hours: h, isToday: isToday))
                            .frame(maxWidth: .infinity)
                            .frame(height: barAnim ? CGFloat(pct) * 56 : 0)
                            .animation(.easeOut(duration: 0.55).delay(Double(i) * 0.04), value: barAnim)
                            .shadow(color: isToday ? FitUpColors.Neon.cyan.opacity(0.3) : .clear, radius: 5, y: 0)
                    }
                    Text(weekdayLetter(offset: i))
                        .font(FitUpFont.body(9))
                        .foregroundStyle(isToday ? FitUpColors.Neon.cyan : FitUpColors.Text.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 56 + 18)
    }

    /// Matches 7-day chart: index 0 = oldest, 6 = today.
    private func weekdayLetter(offset: Int) -> String {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        guard let day = cal.date(byAdding: .day, value: -(6 - offset), to: todayStart) else { return "—" }
        let w = cal.component(.weekday, from: day)
        let letters = ["S", "M", "T", "W", "T", "F", "S"]
        return letters[(w - 1) % 7]
    }

    private func barFill(hours: Double, isToday: Bool) -> some ShapeStyle {
        if isToday {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.cyan.opacity(0.45)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
        }
        if hours > 0 {
            return AnyShapeStyle(FitUpColors.Neon.cyan.opacity(0.22))
        }
        return AnyShapeStyle(Color.white.opacity(0.07))
    }
}

#Preview {
    SevenNightSleepOverviewCard(
        summary: HealthSleepSummary(
            averageHoursLastNights: 7.2,
            varianceHours: 1.1,
            stagePercentagesSevenNight: HealthSleepStagePercentages(deep: 18, core: 52, rem: 22, awake: 8),
            lastNightAsleepHours: 7.5,
            nightlyAsleepHoursOldestFirst: [6, 7.2, 6.8, 8, 7, 7.1, 7.5],
            lastNightStagePercentages: nil,
            lastNightTimeline: []
        )
    )
    .padding()
    .background { BackgroundGradientView() }
}
