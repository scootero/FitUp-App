//
//  SleepRatioCard.swift
//  FitUp
//
//  Deep / Light / REM — percents and hours come only from `HealthSleepSummary.lastNightSleepRatio`
//  (`SleepRatioBreakdown`: deepPercent, lightPercent, remPercent). Do not use `lastNightStagePercentages` for display.
//

import SwiftUI

struct SleepRatioCard: View {
    let summary: HealthSleepSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sleep Ratio")
                .font(FitUpFont.body(10, weight: .heavy))
                .tracking(2)
                .foregroundStyle(FitUpColors.Text.tertiary)
                .padding(.bottom, 12)

            if let r = summary?.lastNightSleepRatio {
                ratioRow(label: "Deep", percent: r.deepPercent, hours: r.deepHours, color: FitUpColors.HealthSleepStage.deep)
                ratioRow(label: "Light", percent: r.lightPercent, hours: r.lightHours, color: FitUpColors.HealthSleepStage.core)
                ratioRow(label: "REM", percent: r.remPercent, hours: r.remHours, color: FitUpColors.HealthSleepStage.rem)
            } else {
                Text("No sleep data from last night")
                    .font(FitUpFont.body(13, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(.base)
    }

    private func ratioRow(label: String, percent: Double, hours: Double, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label.uppercased())
                .font(FitUpFont.mono(9))
                .foregroundStyle(FitUpColors.Text.tertiary)
                .frame(width: 44, alignment: .leading)
            Spacer(minLength: 8)
            Text(String(format: "%.1f%%", percent))
                .font(FitUpFont.display(14, weight: .bold))
                .foregroundStyle(color)
            Text(durationText(hours: hours))
                .font(FitUpFont.body(11))
                .foregroundStyle(FitUpColors.Text.secondary)
        }
        .padding(.vertical, 4)
    }

    private func durationText(hours: Double) -> String {
        let totalMins = max(0, Int((hours * 60).rounded()))
        let h = totalMins / 60
        let m = totalMins % 60
        if h > 0 && m > 0 { return "\(h) hr \(m) min" }
        if h > 0 { return "\(h) hr" }
        return "\(m) min"
    }
}

#Preview {
    SleepRatioCard(
        summary: HealthSleepSummary(
            averageHoursLastNights: 6.5,
            varianceHours: 1.2,
            stagePercentagesSevenNight: HealthSleepStagePercentages(deep: 20, core: 50, rem: 20, awake: 10),
            lastNightAsleepHours: 7.25,
            nightlyAsleepHoursOldestFirst: [6, 7, 6.5, 8, 7, 7.5, 7.25],
            lastNightStagePercentages: nil,
            lastNightTimeline: [],
            lastNightSleepRatio: SleepRatioBreakdown(
                deepHours: 1.5,
                lightHours: 4,
                remHours: 1.75,
                deepPercent: 20,
                lightPercent: 53,
                remPercent: 27
            )
        )
    )
    .padding()
    .background { BackgroundGradientView() }
}
