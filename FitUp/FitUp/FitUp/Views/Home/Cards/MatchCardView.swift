//
//  MatchCardView.swift
//  FitUp
//
//  Slice 3 active match card.
//

import SwiftUI

struct MatchCardView: View {
    let match: HomeActiveMatch
    let index: Int
    var onTap: () -> Void

    @State private var isVisible = false
    @State private var todayPipPulse = false

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.6), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 2)

                VStack(spacing: 12) {
                    headerRow
                    if match.daysLeft == 1, match.finalDayScoreEndsAt != nil {
                        Text("Results are posted once we have updated stats for the day from both players.")
                            .font(FitUpFont.body(10, weight: .regular))
                            .italic()
                            .foregroundStyle(FitUpColors.Text.tertiary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    playersRow
                    dayPipsRow
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .glassCard(match.isWinning ? .win : .lose)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 14)
            .animation(.easeOut(duration: 0.32).delay(Double(index) * 0.08), value: isVisible)
        }
        .buttonStyle(.plain)
        .onAppear {
            isVisible = true
            todayPipPulse = false
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                todayPipPulse = true
            }
        }
        .onDisappear {
            todayPipPulse = false
        }
    }

    private var accentColor: Color {
        match.isWinning ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: match.metricType == "active_calories" ? "flame.fill" : "figure.walk")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(accentColor)

            Text(match.sportLabel.uppercased())
                .font(FitUpFont.mono(11, weight: .bold))
                .foregroundStyle(accentColor)
                .tracking(0.8)

            NeonBadge(label: match.seriesLabel, color: accentColor)

            Spacer(minLength: 0)

            battleCountdownBlock
        }
    }

    private var battleCountdownBlock: some View {
        Group {
            if match.daysLeft > 1 {
                retroDaysLeftNumber(match.daysLeft, plural: true)
            } else if match.daysLeft == 1 {
                if let endsAt = match.finalDayScoreEndsAt {
                    finalDayCountdown(scoreEndsAt: endsAt)
                } else {
                    retroDaysLeftNumber(1, plural: false)
                }
            } else {
                Text("—")
                    .font(FitUpFont.mono(14, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.tertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(retroCountdownChrome)
            }
        }
        .frame(minWidth: 76, alignment: .trailing)
        .multilineTextAlignment(.trailing)
    }

    private func retroDaysLeftNumber(_ value: Int, plural: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("\(value)")
                .font(FitUpFont.mono(22, weight: .bold))
                .foregroundStyle(accentColor)
                .shadow(color: accentColor.opacity(0.4), radius: 3, x: 0, y: 0)
            Text(plural ? "DAYS" : "DAY")
                .font(FitUpFont.mono(8, weight: .heavy))
                .tracking(1.0)
                .foregroundStyle(accentColor.opacity(0.92))
            Text("TO WIN")
                .font(FitUpFont.mono(8, weight: .heavy))
                .tracking(1.0)
                .foregroundStyle(accentColor.opacity(0.78))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(retroCountdownChrome)
    }

    private func finalDayCountdown(scoreEndsAt: Date) -> some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            VStack(alignment: .trailing, spacing: 2) {
                Text("FINAL DAY")
                    .font(FitUpFont.mono(9, weight: .heavy))
                    .tracking(0.9)
                    .foregroundStyle(accentColor)
                Text(finalDayTimeLeft(from: context.date, deadline: scoreEndsAt))
                    .font(FitUpFont.mono(11, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(retroCountdownChrome)
        }
    }

    private var retroCountdownChrome: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.black.opacity(0.38))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(accentColor.opacity(0.42), lineWidth: 1)
            )
    }

    private func finalDayTimeLeft(from now: Date, deadline: Date) -> String {
        let seconds = max(0, deadline.timeIntervalSince(now))
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m left"
        }
        return "\(m)m left"
    }

    private var playersRow: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 8) {
                AvatarView(
                    initials: "YOU",
                    color: FitUpColors.Neon.cyan,
                    size: 38,
                    glow: match.isWinning
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text("You")
                        .font(FitUpFont.display(13, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.primary)
                    Text(match.myToday.formatted())
                        .font(FitUpFont.body(10, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(match.myScore)")
                        .font(FitUpFont.display(18, weight: .black))
                        .foregroundStyle(accentColor)
                    Text("–")
                        .font(FitUpFont.body(11, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                    Text("\(match.theirScore)")
                        .font(FitUpFont.display(18, weight: .black))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.4))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                )

                Text(match.isWinning ? "WINNING" : "LOSING")
                    .font(FitUpFont.mono(9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(accentColor)
            }

            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(match.opponent.displayName)
                        .font(FitUpFont.display(13, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.primary)
                        .lineLimit(1)
                    Text(match.theirToday.formatted())
                        .font(FitUpFont.body(10, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }
                AvatarView(
                    initials: match.opponent.initials,
                    color: color(from: match.opponent.colorHex),
                    size: 38
                )
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var dayPipsRow: some View {
        HStack(spacing: 5) {
            ForEach(match.dayPips) { pip in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(pipColor(for: pip.state))
                    .frame(width: pip.state == .today ? 22 : 16, height: 5)
                    .opacity(pip.state == .today ? (todayPipPulse ? 1 : 0.68) : 1)
                    .shadow(
                        color: pip.state == .today
                            ? FitUpColors.Neon.cyan.opacity(todayPipPulse ? 0.9 : 0.45)
                            : .clear,
                        radius: pip.state == .today ? (todayPipPulse ? 7 : 3) : 0,
                        x: 0,
                        y: 0
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func pipColor(for state: HomeDayPipState) -> Color {
        switch state {
        case .future:
            return Color.white.opacity(0.09)
        case .won:
            return FitUpColors.Neon.cyan
        case .lost:
            return FitUpColors.Neon.orange
        case .today:
            return FitUpColors.Neon.cyan.opacity(0.55)
        case .voided:
            return FitUpColors.Text.tertiary
        }
    }

    private func color(from hex: String) -> Color {
        guard let value = UInt32(hex, radix: 16) else {
            return FitUpColors.Neon.blue
        }
        return Color(rgb: value)
    }
}
