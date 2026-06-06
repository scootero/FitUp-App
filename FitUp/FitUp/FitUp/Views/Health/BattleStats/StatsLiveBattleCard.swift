//
//  StatsLiveBattleCard.swift
//  FitUp
//

import SwiftUI

struct StatsLiveBattleCard: View {
    let match: HomeActiveMatch
    var onOpenMatchDetails: () -> Void

    private var mySteps: Int { max(0, match.myToday) }
    private var theirSteps: Int { max(0, match.theirToday) }
    private var total: Int { max(1, mySteps + theirSteps) }
    private var myPct: Double { Double(mySteps) / Double(total) * 100 }
    private var leading: Bool { mySteps >= theirSteps }
    private var gap: Int { abs(mySteps - theirSteps) }

    var body: some View {
        Button(action: onOpenMatchDetails) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(BattleStatsTheme.green)
                            .frame(width: 8, height: 8)
                        Text("LIVE BATTLE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(BattleStatsTheme.green)
                    }
                    Spacer()
                    timeRemainingLabel
                }

                HStack(alignment: .center, spacing: 10) {
                    competitorColumn(
                        initials: "YOU",
                        steps: mySteps,
                        label: "YOUR STEPS",
                        accent: BattleStatsTheme.green,
                        emphasized: leading
                    )

                    VStack(spacing: 4) {
                        Text("VS")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.2))
                        Text("\(leading ? "+" : "-")\(gap.formatted())")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(leading ? BattleStatsTheme.green : BattleStatsTheme.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((leading ? BattleStatsTheme.green : BattleStatsTheme.red).opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    competitorColumn(
                        initials: String(match.opponent.initials.prefix(2)).uppercased(),
                        steps: theirSteps,
                        label: match.opponent.displayName.uppercased(),
                        accent: BattleStatsTheme.orange,
                        emphasized: !leading
                    )
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(rgb: 0x00C97A), BattleStatsTheme.green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(myPct / 100))
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(Int(myPct.rounded()))%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(BattleStatsTheme.green)
                    Spacer()
                    Text("\(Int((100 - myPct).rounded()))%")
                        .font(.system(size: BattleStatsTheme.Typography.captionSmall, weight: .medium, design: .monospaced))
                        .battleStatsStyle(.label, size: BattleStatsTheme.Typography.captionSmall, accent: .mint)
                }

                Text(leading ? "🔥 You're leading — keep pushing" : "⚠️ You're behind — time to grind")
                    .battleStatsStyle(.secondary, size: BattleStatsTheme.Typography.bodySmall, accent: .mint)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(BattleStatsTheme.cardPadding)
            .background(
                LinearGradient(
                    colors: [Color(rgb: 0x0A1A12), Color(rgb: 0x0D1420)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        (leading ? BattleStatsTheme.green : BattleStatsTheme.red).opacity(0.35),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Live battle versus \(match.opponent.displayName)")
        .accessibilityHint("Opens match details")
    }

    @ViewBuilder
    private var timeRemainingLabel: some View {
        if match.daysLeft > 1 {
            Text("\(match.daysLeft)d left")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(BattleStatsTheme.gold)
        } else if match.daysLeft == 1, let scoreEndsAt = match.finalDayScoreEndsAt {
            TimelineView(.periodic(from: Date(), by: 60)) { context in
                Text(timeLeftUntilMidnight(from: context.date, deadline: scoreEndsAt))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(BattleStatsTheme.gold)
            }
        } else if match.daysLeft == 1 {
            Text("1d left")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(BattleStatsTheme.gold)
        }
    }

    private func timeLeftUntilMidnight(from now: Date, deadline: Date) -> String {
        let seconds = max(0, deadline.timeIntervalSince(now))
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        }
        return "\(minutes)m left"
    }

    private func competitorColumn(
        initials: String,
        steps: Int,
        label: String,
        accent: Color,
        emphasized: Bool
    ) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.25))
                    .frame(width: 44, height: 44)
                Text(initials)
                    .font(.system(size: BattleStatsTheme.Typography.bodySmall, weight: .bold, design: .monospaced))
                    .battleStatsStyle(.primary, size: BattleStatsTheme.Typography.bodySmall, weight: .bold, accent: .mint)
            }
            .overlay {
                if emphasized {
                    Circle()
                        .strokeBorder(accent, lineWidth: 2)
                }
            }

            Text(steps.formatted())
                .battleStatsStyle(.primary, size: 26, weight: .bold, design: .monospaced, accent: .mint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Group {
                if emphasized {
                    Text(label)
                        .font(.system(size: BattleStatsTheme.Typography.caption, weight: .medium, design: .monospaced))
                        .foregroundStyle(accent)
                } else {
                    Text(label)
                        .font(.system(size: BattleStatsTheme.Typography.caption, weight: .medium, design: .monospaced))
                        .battleStatsStyle(.label, size: BattleStatsTheme.Typography.caption, accent: .mint)
                }
            }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}
