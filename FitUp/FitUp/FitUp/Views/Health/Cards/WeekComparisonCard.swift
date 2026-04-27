//
//  WeekComparisonCard.swift
//  FitUp
//
//  This week vs last week (same elapsed window).
//

import SwiftUI

struct WeekComparisonCard: View {
    let comparison: HealthWeekComparison?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("THIS WEEK VS LAST WEEK")
                .font(FitUpFont.body(10, weight: .heavy))
                .tracking(2)
                .foregroundStyle(FitUpColors.Text.tertiary)
                .padding(.bottom, 10)

            if let comparison {
                Text(comparison.headline)
                    .font(FitUpFont.body(12))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .padding(.bottom, 12)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(comparison.currentValueText)
                        .font(FitUpFont.display(26, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.primary)
                    Text(comparison.metricUnitLabel)
                        .font(FitUpFont.body(12, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }
                .padding(.bottom, 10)

                comparisonBar(
                    title: "This Week",
                    valueText: comparison.currentValueText,
                    widthFraction: comparison.currentBarFraction,
                    color: FitUpColors.Neon.cyan
                )
                .padding(.bottom, 8)

                comparisonBar(
                    title: "Last Week",
                    valueText: comparison.previousValueText,
                    widthFraction: comparison.previousBarFraction,
                    color: FitUpColors.Text.secondary
                )
            } else {
                Text("Week comparison unavailable.")
                    .font(FitUpFont.body(12))
                    .foregroundStyle(FitUpColors.Text.secondary)
            }
        }
        .padding(18)
        .glassCard(.base)
    }

    private func comparisonBar(
        title: String,
        valueText: String,
        widthFraction: Double,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(FitUpFont.body(11, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.secondary)
                Spacer()
                Text(valueText)
                    .font(FitUpFont.mono(11, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color.opacity(0.7))
                        .frame(width: geo.size.width * CGFloat(min(max(widthFraction, 0.06), 1)))
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    WeekComparisonCard(
        comparison: HealthWeekComparison(
            metricType: .steps,
            currentTotal: 24_800,
            previousTotal: 21_600
        )
    )
    .padding()
    .background { BackgroundGradientView() }
}
