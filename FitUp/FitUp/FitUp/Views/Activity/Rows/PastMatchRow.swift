//
//  PastMatchRow.swift
//  FitUp
//
//  Slice 10 Activity completed row.
//

import SwiftUI

struct PastMatchRow: View {
    let match: ActivityCompletedMatch
    var onTap: () -> Void
    /// Light pastel panels + dark ink (Health tab); default preserves dark glass elsewhere.
    var healthLightChrome: Bool = false

    var body: some View {
        Button(action: onTap) {
            Group {
                if healthLightChrome {
                    rowInner
                        .healthGamifiedCard(match.myWon ? .matchRowWin : .matchRowLose)
                } else {
                    rowInner
                        .glassCard(match.myWon ? .win : .lose)
                        .opacity(0.84)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var rowInner: some View {
        HStack(spacing: 12) {
            AvatarView(
                initials: match.opponentInitials,
                color: color(from: match.opponentColorHex),
                size: 38
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(match.opponentName)
                    .font(FitUpFont.display(13, weight: .bold))
                    .foregroundStyle(healthLightChrome ? FitUpColors.HealthOnLight.primary : FitUpColors.Text.primary)
                    .lineLimit(1)
                Text("\(sportLabel(for: match.metricType)) · \(match.rangeLabel)")
                    .font(FitUpFont.body(11, weight: .medium))
                    .foregroundStyle(healthLightChrome ? FitUpColors.HealthOnLight.secondary : FitUpColors.Text.secondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(match.myScore) – \(match.theirScore)")
                    .font(FitUpFont.display(16, weight: .black))
                    .foregroundStyle(match.myWon ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange)
                NeonBadge(
                    label: match.myWon ? "WIN" : "LOSS",
                    color: match.myWon ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func sportLabel(for metricType: String) -> String {
        metricType == "active_calories" ? "Calories" : "Steps"
    }

    private func color(from hex: String) -> Color {
        guard let value = UInt32(hex, radix: 16) else {
            return FitUpColors.Neon.blue
        }
        return Color(rgb: value)
    }
}
