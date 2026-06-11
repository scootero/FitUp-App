//
//  CalendarBattleDayDetailPanel.swift
//  FitUp
//
//  Compact battle day breakdown: scrollable match cards, outcome colors, match navigation.
//

import SwiftUI

struct CalendarBattleDayDetailPanel: View {
    let detail: CalendarDayBattleDetail
    var onOpenMatchDetails: ((UUID, String) -> Void)?

    private let barMaxHeight: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if detail.matches.isEmpty {
                restDayShameContent
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(detail.matches.enumerated()), id: \.element.id) { index, match in
                            if index > 0 {
                                matchSeparator
                            }
                            matchCardButton(match: match)
                        }
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        VStack(spacing: 3) {
            Text(detail.displayTitle)
                .font(FitUpFont.display(17, weight: .bold))
                .foregroundStyle(FitUpColors.Text.primary)
            if !detail.matches.isEmpty {
                Text(detail.summaryLine)
                    .font(FitUpFont.body(11))
                    .foregroundStyle(FitUpColors.Text.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    private var restDayShameContent: some View {
        VStack(spacing: 18) {
            Text("You didn't battle — come on!")
                .font(FitUpFont.display(17, weight: .heavy))
                .foregroundStyle(FitUpColors.Text.primary)
                .multilineTextAlignment(.center)

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 112, height: 112)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.black.opacity(0.18), lineWidth: 1.5)
                    }

                Image(systemName: "skull.fill")
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundStyle(Color.black)
            }
            .shadow(color: Color.black.opacity(0.35), radius: 14, y: 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var matchSeparator: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            FitUpColors.Neon.cyan.opacity(0.05),
                            FitUpColors.Neon.purple.opacity(0.35),
                            FitUpColors.Neon.cyan.opacity(0.05),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }

    private func matchCardButton(match: CalendarDayBattleMatchDetail) -> some View {
        Button {
            onOpenMatchDetails?(match.matchId, match.opponent.displayName)
        } label: {
            matchCardContent(match: match)
        }
        .buttonStyle(.plain)
        .disabled(onOpenMatchDetails == nil)
    }

    private func matchCardContent(match: CalendarDayBattleMatchDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(match.opponent.displayName)
                    .font(FitUpFont.body(12, weight: .heavy))
                    .foregroundStyle(FitUpColors.Text.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(detail.displayTitle)
                    .font(FitUpFont.mono(10, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.tertiary)
            }

            HStack(alignment: .center, spacing: 10) {
                avatarCluster(match: match)

                Spacer(minLength: 4)

                compactStepBars(match: match)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.tertiary.opacity(0.7))
            }

            if let h2h = match.headToHead {
                Text("All-time \(h2h.viewerWins)–\(h2h.opponentWins) · \(h2h.totalCompleted) matches")
                    .font(FitUpFont.body(10))
                    .foregroundStyle(FitUpColors.Text.tertiary)
            }

            if !match.rivalryEmblems.isEmpty {
                CalendarBattleEmblemStrip(emblems: match.rivalryEmblems)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
        }
    }

    private func avatarCluster(match: CalendarDayBattleMatchDetail) -> some View {
        HStack(spacing: 8) {
            AvatarView(
                initials: "YOU",
                color: FitUpColors.Neon.cyan,
                size: 32,
                glow: false
            )

            compactOutcomeBadge(match: match)

            AvatarView(
                initials: match.opponent.initials,
                color: calendarOpponentColor(hex: match.opponent.colorHex),
                size: 32,
                glow: false
            )
        }
    }

    private func compactOutcomeBadge(match: CalendarDayBattleMatchDetail) -> some View {
        let style = dayOutcomeBadgeStyle(for: match)
        return Text(outcomeLetter(for: match))
            .font(FitUpFont.mono(11, weight: .black))
            .foregroundStyle(style.color)
            .frame(minWidth: 22)
    }

    private func outcomeLetter(for match: CalendarDayBattleMatchDetail) -> String {
        if !match.isFinalized { return "•" }
        if match.isVoid { return "T" }
        if match.myWon == true { return "W" }
        if match.myWon == false { return "L" }
        return "—"
    }

    private func compactStepBars(match: CalendarDayBattleMatchDetail) -> some View {
        let maxSteps = max(match.mySteps, match.theirSteps, 1)
        let myColor = scoreColor(isViewer: true, match: match)
        let theirColor = scoreColor(isViewer: false, match: match)

        return HStack(alignment: .bottom, spacing: 14) {
            miniBarColumn(
                steps: match.mySteps,
                height: barMaxHeight * CGFloat(match.mySteps) / CGFloat(maxSteps),
                color: myColor,
                label: "YOU"
            )
            miniBarColumn(
                steps: match.theirSteps,
                height: barMaxHeight * CGFloat(match.theirSteps) / CGFloat(maxSteps),
                color: theirColor,
                label: match.opponent.initials
            )
        }
    }

    private func miniBarColumn(
        steps: Int,
        height: CGFloat,
        color: Color,
        label: String
    ) -> some View {
        VStack(spacing: 4) {
            Text(formattedSteps(steps))
                .font(FitUpFont.mono(10, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 18, height: barMaxHeight)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color.opacity(0.85))
                    .frame(width: 18, height: max(8, height))
            }

            Text(label)
                .font(FitUpFont.mono(8, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.tertiary)
                .lineLimit(1)
        }
        .frame(width: 28)
    }

    private func scoreColor(isViewer: Bool, match: CalendarDayBattleMatchDetail) -> Color {
        if match.isFinalized {
            if match.myWon == true {
                return isViewer ? FitUpColors.Neon.green : FitUpColors.Text.secondary
            }
            if match.myWon == false {
                return isViewer ? FitUpColors.Neon.red : FitUpColors.Text.secondary
            }
            return FitUpColors.Text.secondary
        }

        if match.mySteps > match.theirSteps {
            return isViewer ? FitUpColors.Neon.green : FitUpColors.Text.secondary
        }
        if match.mySteps < match.theirSteps {
            return isViewer ? FitUpColors.Neon.red : FitUpColors.Text.secondary
        }
        return isViewer ? FitUpColors.Neon.cyan : FitUpColors.Text.secondary
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
