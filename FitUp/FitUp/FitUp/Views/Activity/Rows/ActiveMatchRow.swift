//
//  ActiveMatchRow.swift
//  FitUp
//
//  Slice 10 Activity active row.
//

import SwiftUI

struct ActiveMatchRow: View {
    let match: HomeActiveMatch
    var onTap: () -> Void

    private var currentDay: Int {
        min(max(match.durationDays - match.daysLeft, 1), match.durationDays)
    }

    private var statusLabel: String {
        if match.myScore > match.theirScore { return "WINNING" }
        if match.myScore < match.theirScore { return "LOSING" }
        return "TIED"
    }

    private var accentColor: Color {
        if match.myScore > match.theirScore { return FitUpColors.Neon.cyan }
        if match.myScore < match.theirScore { return FitUpColors.Neon.orange }
        return FitUpColors.Neon.blue
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AvatarView(
                    initials: match.opponent.initials,
                    color: color(from: match.opponent.colorHex),
                    size: 40
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(match.opponent.displayName)
                        .font(FitUpFont.display(13, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.primary)
                        .lineLimit(1)

                    Text("\(match.sportLabel) · Day \(currentDay)/\(match.durationDays)")
                        .font(FitUpFont.body(11, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)

                    Text("Today \(formattedMetric(match.myToday, metricType: match.metricType)) · Opp \(formattedMetric(match.theirToday, metricType: match.metricType))")
                        .font(FitUpFont.body(10, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(match.myScore) – \(match.theirScore)")
                        .font(FitUpFont.display(16, weight: .black))
                        .foregroundStyle(accentColor)
                    NeonBadge(label: statusLabel, color: accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassCard(match.myScore >= match.theirScore ? .win : .lose)
        }
        .buttonStyle(.plain)
    }

    private func formattedMetric(_ value: Int, metricType: String) -> String {
        if metricType == "active_calories" {
            return "\(value)"
        }
        if value >= 1_000 {
            let scaled = Double(value) / 1_000
            return String(format: "%.1fk", scaled)
        }
        return "\(value)"
    }

    private func color(from hex: String) -> Color {
        guard let value = UInt32(hex, radix: 16) else {
            return FitUpColors.Neon.blue
        }
        return Color(rgb: value)
    }
}
