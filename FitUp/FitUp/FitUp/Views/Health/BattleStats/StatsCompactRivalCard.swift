//
//  StatsCompactRivalCard.swift
//  FitUp
//

import SwiftUI

enum StatsRivalTag: String {
    case nemesis
    case punchingBag
    case rival

    var label: String {
        switch self {
        case .nemesis: return "😤 NEMESIS"
        case .punchingBag: return "💪 PUNCHING BAG"
        case .rival: return "⚔️ RIVAL"
        }
    }

    var accent: Color {
        switch self {
        case .nemesis: return BattleStatsTheme.red
        case .punchingBag: return BattleStatsTheme.green
        case .rival: return BattleStatsTheme.blue
        }
    }

    static func derive(from rival: HomeRivalStat) -> StatsRivalTag {
        let total = rival.matchWins + rival.matchLosses
        guard total > 0 else { return .rival }
        if rival.winPercentage < 40, rival.matchLosses > rival.matchWins { return .nemesis }
        if rival.winPercentage >= 60, rival.matchWins > rival.matchLosses { return .punchingBag }
        return .rival
    }
}

struct StatsCompactRivalCard: View {
    let rival: HomeRivalStat
    var onRematch: () -> Void

    private var tag: StatsRivalTag { StatsRivalTag.derive(from: rival) }

    private var recordText: String {
        if rival.matchTies > 0 {
            return "\(rival.matchWins)-\(rival.matchLosses)-\(rival.matchTies)"
        }
        return "\(rival.matchWins)-\(rival.matchLosses)"
    }

    private var lastBattleText: String? {
        guard let date = rival.lastPlayedOn else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Last battle: \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                BattleStatsTheme.rivalTagTitle(tag.label, color: tag.accent)
                Spacer()
                Text("\(rival.finalizedDaysCompeted) battle days")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(BattleStatsTheme.textLabel)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(tag.accent.opacity(0.12))

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(ProfileAccentColor.color(for: rival.opponentProfileId).opacity(0.22))
                        Text(String(rival.opponentInitials.prefix(2)).uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ProfileAccentColor.color(for: rival.opponentProfileId))
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(rival.opponentDisplayName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(BattleStatsTheme.textPrimary)
                            .lineLimit(1)
                        if let lastBattleText {
                            Text(lastBattleText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(BattleStatsTheme.textSecondary)
                        }
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text(recordText)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(rival.matchWins >= rival.matchLosses ? BattleStatsTheme.green : BattleStatsTheme.red)
                        Text("W-L")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(BattleStatsTheme.textLabel)
                    }
                }

                HStack(spacing: 6) {
                    statPill(
                        value: formattedMargin(rival.avgFinalizedDailyMargin),
                        label: "AVG MARGIN",
                        color: BattleStatsTheme.gold
                    )
                    statPill(
                        value: "\(rival.winPercentage)%",
                        label: "WIN RATE",
                        color: rival.matchWins >= rival.matchLosses ? BattleStatsTheme.green : BattleStatsTheme.red
                    )
                    if let best = rival.avgMarginOnViewerWinDays {
                        statPill(
                            value: formattedMargin(best),
                            label: "AVG WIN",
                            color: BattleStatsTheme.blue
                        )
                    }
                }

                Button(action: onRematch) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                        Text("REMATCH \(rival.opponentDisplayName.split(separator: " ").first.map(String.init)?.uppercased() ?? "RIVAL")")
                            .font(.system(size: 14, weight: .heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(Color.black.opacity(0.88))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color(rgb: 0x00A85A), BattleStatsTheme.green],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
        }
        .background(BattleStatsTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tag.accent.opacity(0.25), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(rival.opponentDisplayName), record \(recordText)")
    }

    private func statPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(BattleStatsTheme.textLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func formattedMargin(_ value: Double?) -> String {
        guard let value else { return BattleStatsTheme.unresolvedPlaceholder }
        let steps = Int(value.rounded())
        let prefix = steps >= 0 ? "+" : ""
        return "\(prefix)\(abs(steps).formatted())"
    }
}
