//
//  LastNightSleepCard.swift
//  FitUp
//
//  Last wake night: time asleep + hypnogram.
//

import SwiftUI

struct LastNightSleepCard: View {
    let summary: HealthSleepSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LAST NIGHT")
                .font(FitUpFont.mono(10))
                .tracking(1)
                .foregroundStyle(FitUpColors.Text.tertiary)
                .padding(.bottom, 8)

            Text(primaryHoursText)
                .font(FitUpFont.display(22, weight: .bold))
                .foregroundStyle(FitUpColors.Text.primary)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
                .padding(.bottom, 12)

            hypnogram
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(.base)
    }

    private var hypnogram: some View {
        let segments = summary?.lastNightTimeline ?? []
        return Group {
            if segments.isEmpty {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 36)
            } else {
                SleepHypnogramView(segments: segments)
                    .frame(height: 36)
            }
        }
    }

    private var primaryHoursText: String {
        guard let h = summary?.lastNightAsleepHours, h > 0 else { return "—" }
        return Self.formatTimeAsleep(hours: h)
    }

    /// Apple Health–style “11 hr 7 min” formatting.
    static func formatTimeAsleep(hours: Double) -> String {
        let totalMins = max(0, Int((hours * 60).rounded()))
        let h = totalMins / 60
        let m = totalMins % 60
        if h > 0 && m > 0 { return "\(h) hr \(m) min" }
        if h > 0 { return "\(h) hr" }
        return "\(m) min"
    }
}

// MARK: - Hypnogram

private struct SleepHypnogramView: View {
    let segments: [HealthSleepTimelineSegment]

    var body: some View {
        GeometryReader { geo in
            let total = segments.reduce(0) { $0 + $1.duration }
            HStack(spacing: 0) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                    let w = total > 0 ? max(1, geo.size.width * CGFloat(seg.duration / total)) : 0
                    Rectangle()
                        .fill(Self.color(for: seg.stage))
                        .frame(width: w)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private static func color(for stage: HealthSleepTimelineStage) -> Color {
        switch stage {
        case .deep:
            return FitUpColors.HealthSleepStage.deep
        case .core:
            return FitUpColors.HealthSleepStage.core
        case .rem:
            return FitUpColors.HealthSleepStage.rem
        case .awake:
            return FitUpColors.HealthSleepStage.awake
        }
    }
}

#Preview {
    LastNightSleepCard(
        summary: HealthSleepSummary(
            averageHoursLastNights: 6.5,
            varianceHours: 1.2,
            stagePercentagesSevenNight: HealthSleepStagePercentages(deep: 20, core: 50, rem: 20, awake: 10),
            lastNightAsleepHours: 7.25,
            nightlyAsleepHoursOldestFirst: [6, 7, 6.5, 8, 7, 7.5, 7.25],
            lastNightStagePercentages: HealthSleepStagePercentages(deep: 22, core: 48, rem: 22, awake: 8),
            lastNightTimeline: []
        )
    )
    .padding()
    .background { BackgroundGradientView() }
}
