//
//  StatsCompactRivalCard.swift
//  FitUp
//

import SwiftUI

extension StatsRivalCategory {
    var accent: Color {
        switch self {
        case .nemesis: return BattleStatsTheme.red
        case .punchingBag: return BattleStatsTheme.green
        case .mostBattled: return BattleStatsTheme.blue
        }
    }
}

struct StatsCompactRivalCard: View {
    let category: StatsRivalCategory
    let rival: HomeRivalStat
    let completedMatches: [ActivityCompletedMatch]
    let isLoadingCompletedMatches: Bool
    var onRematch: () -> Void
    var onOpenMatchDetails: (UUID, String) -> Void
    var onLoadCompletedMatchesIfNeeded: () -> Void = {}

    @State private var isPastMatchesExpanded = false

    private var pastMatchesWithRival: [ActivityCompletedMatch] {
        completedMatches.filter { $0.opponentProfileId == rival.opponentProfileId }
    }

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

    private var avgStepsText: String {
        guard let value = rival.avgViewerStepsPerBattleDay else {
            return BattleStatsTheme.unresolvedPlaceholder
        }
        return Int(max(0, value.rounded())).formatted()
    }

    private var winRateText: String {
        "\(rival.winPercentage)%"
    }

    private var avgMarginText: String {
        switch category {
        case .nemesis:
            guard let value = rival.avgMarginOnOpponentWinDays else {
                return BattleStatsTheme.unresolvedPlaceholder
            }
            return formattedAbsoluteMargin(value)
        case .punchingBag:
            guard let value = rival.avgMarginOnViewerWinDays else {
                return BattleStatsTheme.unresolvedPlaceholder
            }
            return formattedSignedMargin(value)
        case .mostBattled:
            return formattedSignedMargin(rival.avgFinalizedDailyMargin)
        }
    }

    private var avgMarginColor: Color {
        switch category {
        case .nemesis: return BattleStatsTheme.red
        case .punchingBag: return BattleStatsTheme.green
        case .mostBattled:
            guard let value = rival.avgFinalizedDailyMargin else { return BattleStatsTheme.gold }
            return value >= 0 ? BattleStatsTheme.green : BattleStatsTheme.red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                BattleStatsTheme.rivalTagTitle(category.label, color: category.accent)
                Spacer()
                Text("\(rival.completedMatchCount) battles")
                    .font(.system(size: BattleStatsTheme.Typography.captionSmall, weight: .medium, design: .monospaced))
                    .battleStatsStyle(.label, size: BattleStatsTheme.Typography.captionSmall, accent: .cool)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(category.accent.opacity(0.12))

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(ProfileAccentColor.color(for: rival.opponentProfileId).opacity(0.22))
                        Text(String(rival.opponentInitials.prefix(2)).uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(ProfileAccentColor.color(for: rival.opponentProfileId))
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(rival.opponentDisplayName)
                            .font(.system(size: 19, weight: .bold))
                            .battleStatsStyle(.primary, size: 19, weight: .bold, accent: .cool)
                            .lineLimit(1)
                        if let lastBattleText {
                            Text(lastBattleText)
                                .battleStatsStyle(.secondary, size: BattleStatsTheme.Typography.bodySmall, accent: .cool)
                        }
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text(recordText)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(rival.matchWins >= rival.matchLosses ? BattleStatsTheme.green : BattleStatsTheme.red)
                        Text("W-L")
                            .font(.system(size: BattleStatsTheme.Typography.caption, weight: .medium, design: .monospaced))
                            .battleStatsStyle(.label, accent: .cool)
                    }
                }

                HStack(spacing: 6) {
                    metricTile(
                        value: avgStepsText,
                        label: "AVG STEPS\nBATTLE DAYS",
                        color: BattleStatsTheme.blue,
                        explainer: .avgStepsBattleDays
                    )
                    metricTile(
                        value: winRateText,
                        label: "YOUR WIN %",
                        color: rival.matchWins >= rival.matchLosses ? BattleStatsTheme.green : BattleStatsTheme.red,
                        explainer: .yourWinRate
                    )
                    metricTile(
                        value: avgMarginText,
                        label: "AVG MARGIN",
                        color: avgMarginColor,
                        explainer: .avgMargin
                    )
                }

                Button(action: onRematch) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                        Text("REMATCH \(rival.opponentDisplayName.split(separator: " ").first.map(String.init)?.uppercased() ?? "RIVAL")")
                            .font(.system(size: 17, weight: .heavy))
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

                PastMatchesExpandableList(
                    title: "Past matches",
                    matches: pastMatchesWithRival,
                    isExpanded: isPastMatchesExpanded,
                    isLoading: isLoadingCompletedMatches,
                    style: .embedded,
                    accent: category.accent,
                    emptyMessage: "No past matches with \(rival.opponentDisplayName) yet.",
                    onToggle: {
                        let willExpand = !isPastMatchesExpanded
                        isPastMatchesExpanded = willExpand
                        if willExpand {
                            onLoadCompletedMatchesIfNeeded()
                        }
                    },
                    onOpenMatch: { match in
                        onOpenMatchDetails(match.id, match.opponentName)
                    }
                )
            }
            .padding(14)
        }
        .background(BattleStatsTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(category.accent.opacity(0.25), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(rival.opponentDisplayName), record \(recordText)")
    }

    private func metricTile(
        value: String,
        label: String,
        color: Color,
        explainer: StatsRivalMetricExplainer
    ) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                StatsMetricInfoButton(explainer: explainer)
            }
            Text(label)
                .font(.system(size: BattleStatsTheme.Typography.captionSmall, weight: .medium, design: .monospaced))
                .battleStatsStyle(.label, size: BattleStatsTheme.Typography.captionSmall, accent: .cool)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func formattedSignedMargin(_ value: Double?) -> String {
        guard let value else { return BattleStatsTheme.unresolvedPlaceholder }
        let steps = Int(value.rounded())
        let prefix = steps >= 0 ? "+" : ""
        return "\(prefix)\(abs(steps).formatted())"
    }

    private func formattedAbsoluteMargin(_ value: Double) -> String {
        abs(Int(value.rounded())).formatted()
    }
}
