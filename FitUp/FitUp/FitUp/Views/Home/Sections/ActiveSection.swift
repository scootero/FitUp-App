//
//  ActiveSection.swift
//  FitUp
//
//  Slice 3 active match cards section.
//

import SwiftUI

struct ActiveSection: View {
    let matches: [HomeActiveMatch]
    var onOpenMatch: (HomeActiveMatch) -> Void

    var body: some View {
        if !matches.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Active Battles", actionTitle: "\(matches.count) live")
                ForEach(matches) { match in
                    battleRow(match)
                }
            }
        }
    }

    private func battleRow(_ match: HomeActiveMatch) -> some View {
        let margin = match.myToday - match.theirToday
        return Button {
            onOpenMatch(match)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top, spacing: 10) {
                    AvatarView(
                        initials: match.opponent.initials,
                        color: ProfileAccentColor.swiftUIColor(hex: match.opponent.colorHex),
                        size: 34
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(match.opponent.displayName)
                                .font(FitUpFont.body(14, weight: .bold))
                                .foregroundStyle(FitUpColors.Text.primary)
                                .lineLimit(1)
                            statusPill(for: margin)
                            Spacer(minLength: 0)
                        }

                        Text(match.seriesLabel)
                            .font(FitUpFont.body(10, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.tertiary)

                        if let freshness = freshnessText(opponentUpdatedAt: match.opponentTodayUpdatedAt) {
                            Text(freshness)
                                .font(FitUpFont.body(10, weight: .medium))
                                .foregroundStyle(FitUpColors.Text.tertiary)
                        }
                    }

                    Spacer(minLength: 10)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formattedMargin(margin))
                            .font(FitUpFont.display(20, weight: .black))
                            .foregroundStyle(marginColor(for: margin))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(match.sportLabel.uppercased())
                            .font(FitUpFont.mono(9, weight: .semibold))
                            .foregroundStyle(FitUpColors.Text.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .homeLiquidGlassCard(.base)
            .overlay(
                RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func statusPill(for margin: Int) -> some View {
        Text(statusText(for: margin))
            .font(FitUpFont.mono(9, weight: .bold))
            .foregroundStyle(marginColor(for: margin))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(marginColor(for: margin).opacity(0.15))
                    .overlay(
                        Capsule()
                            .strokeBorder(marginColor(for: margin).opacity(0.35), lineWidth: 1)
                    )
            )
    }

    private func statusText(for margin: Int) -> String {
        if margin > 0 { return "Ahead today" }
        if margin < 0 { return "Behind today" }
        return "Tied today"
    }

    private func marginColor(for margin: Int) -> Color {
        if margin > 0 { return FitUpColors.Neon.cyan }
        if margin < 0 { return FitUpColors.Neon.orange }
        return FitUpColors.Text.secondary
    }

    private func formattedMargin(_ value: Int) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)\(abs(value).formatted())"
    }

    private func freshnessText(opponentUpdatedAt: Date?) -> String? {
        guard let opponentUpdatedAt else { return nil }
        let elapsedSeconds = max(0, Int(Date().timeIntervalSince(opponentUpdatedAt)))
        let elapsedMinutes = elapsedSeconds / 60
        if elapsedMinutes < 1 { return "Updated just now" }
        if elapsedMinutes < 60 { return "Updated \(elapsedMinutes)m ago" }
        let elapsedHours = max(1, elapsedMinutes / 60)
        if elapsedHours < 24 { return "Updated \(elapsedHours)h ago" }
        return "Updated yesterday"
    }
}
