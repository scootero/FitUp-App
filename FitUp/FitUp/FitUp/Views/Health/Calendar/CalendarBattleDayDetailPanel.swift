//
//  CalendarBattleDayDetailPanel.swift
//  FitUp
//
//  Battle day breakdown: avatars, vertical step bars, head-to-head, emblem strip.
//

import SwiftUI

struct CalendarBattleDayDetailPanel: View {
    let detail: CalendarDayBattleDetail
    let match: CalendarDayBattleMatchDetail?
    let matchIndex: Int
    let matchCount: Int
    let onSelectMatchIndex: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let match {
                battleBody(match: match)
            } else {
                Text(detail.summaryLine)
                    .font(FitUpFont.body(12))
                    .foregroundStyle(FitUpColors.Text.secondary)
            }

            if matchCount > 1 {
                matchPager
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(detail.displayTitle)
                .font(FitUpFont.display(18, weight: .bold))
                .foregroundStyle(FitUpColors.Text.primary)
            Text(detail.summaryLine)
                .font(FitUpFont.body(12))
                .foregroundStyle(FitUpColors.Text.secondary)
        }
    }

    private func battleBody(match: CalendarDayBattleMatchDetail) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            stackedAvatars(match: match)
                .padding(.bottom, 16)

            HStack(alignment: .bottom, spacing: 0) {
                verticalStepBars(match: match)
                    .frame(minWidth: 80, alignment: .leading)

                Spacer(minLength: 24)

                headToHeadColumn(match: match)
            }
        }
    }

    private func stackedAvatars(match: CalendarDayBattleMatchDetail) -> some View {
        ZStack(alignment: .leading) {
            AvatarView(
                initials: "YOU",
                color: FitUpColors.Neon.cyan,
                size: 40,
                glow: true
            )
            .offset(x: 26)

            AvatarView(
                initials: match.opponent.initials,
                color: calendarOpponentColor(hex: match.opponent.colorHex),
                size: 40,
                glow: true
            )
        }
        .frame(height: 44)
        .padding(.bottom, 2)
    }

    private func verticalStepBars(match: CalendarDayBattleMatchDetail) -> some View {
        let maxSteps = max(match.mySteps, match.theirSteps, 1)
        let barMaxHeight: CGFloat = 72

        return HStack(alignment: .bottom, spacing: 28) {
            verticalBar(
                label: "YOU",
                steps: match.mySteps,
                height: barMaxHeight * CGFloat(match.mySteps) / CGFloat(maxSteps),
                color: FitUpColors.Neon.cyan,
                won: match.myWon == true,
                barMaxHeight: barMaxHeight
            )
            verticalBar(
                label: match.opponent.initials,
                steps: match.theirSteps,
                height: barMaxHeight * CGFloat(match.theirSteps) / CGFloat(maxSteps),
                color: calendarOpponentColor(hex: match.opponent.colorHex),
                won: match.myWon == false,
                barMaxHeight: barMaxHeight
            )
        }
    }

    private func verticalBar(
        label: String,
        steps: Int,
        height: CGFloat,
        color: Color,
        won: Bool,
        barMaxHeight: CGFloat
    ) -> some View {
        VStack(spacing: 6) {
            Text(formattedSteps(steps))
                .font(FitUpFont.mono(10, weight: .bold))
                .foregroundStyle(color)
                .frame(height: 14, alignment: .bottom)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 24, height: barMaxHeight)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.95), color.opacity(0.45)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 24, height: max(10, height))
                    .shadow(color: color.opacity(won ? 0.45 : 0.2), radius: won ? 8 : 2)
            }

            Text(label)
                .font(FitUpFont.mono(9, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.tertiary)
                .lineLimit(1)
        }
    }

    private func headToHeadColumn(match: CalendarDayBattleMatchDetail) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(match.opponent.displayName.uppercased())
                .font(FitUpFont.body(10, weight: .heavy))
                .tracking(1)
                .foregroundStyle(FitUpColors.Text.tertiary)
                .lineLimit(1)

            if let h2h = match.headToHead {
                Text("\(h2h.viewerWins) – \(h2h.opponentWins)")
                    .font(FitUpFont.display(28, weight: .bold))
                    .foregroundStyle(FitUpColors.Neon.green)
                Text("ALL-TIME W–L")
                    .font(FitUpFont.mono(9, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.tertiary)
                Text("\(h2h.totalCompleted) matches")
                    .font(FitUpFont.body(10))
                    .foregroundStyle(FitUpColors.Text.secondary)
            } else {
                Text("—")
                    .font(FitUpFont.display(24, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.tertiary)
            }

            dayOutcomeBadge(match: match)
        }
        .frame(minWidth: 96)
    }

    private func dayOutcomeBadgeStyle(for match: CalendarDayBattleMatchDetail) -> (text: String, color: Color) {
        if !match.isFinalized {
            return ("LIVE", FitUpColors.Neon.orange)
        }
        if match.isVoid {
            return ("VOID", FitUpColors.Neon.yellow)
        }
        if match.myWon == true {
            return ("WIN", FitUpColors.Neon.green)
        }
        if match.myWon == false {
            return ("LOSS", FitUpColors.Neon.red)
        }
        return ("—", FitUpColors.Text.tertiary)
    }

    private func dayOutcomeBadge(match: CalendarDayBattleMatchDetail) -> some View {
        let style = dayOutcomeBadgeStyle(for: match)
        return Text(style.text)
            .font(FitUpFont.mono(10, weight: .bold))
            .foregroundStyle(style.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(style.color.opacity(0.14))
            .clipShape(Capsule())
    }

    private var matchPager: some View {
        HStack(spacing: 6) {
            ForEach(0..<matchCount, id: \.self) { index in
                Button {
                    onSelectMatchIndex(index)
                } label: {
                    Circle()
                        .fill(index == matchIndex ? FitUpColors.Neon.cyan : Color.white.opacity(0.2))
                        .frame(width: 7, height: 7)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func formattedSteps(_ steps: Int) -> String {
        if steps >= 10_000 {
            return String(format: "%.1fk", Double(steps) / 1000)
        }
        return "\(steps)"
    }
}

private func calendarOpponentColor(hex: String) -> Color {
    guard let value = UInt32(hex, radix: 16) else {
        return FitUpColors.Neon.orange
    }
    return Color(rgb: value)
}
