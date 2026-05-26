//
//  StatsArcadeSliceOneView.swift
//  FitUp
//
//  Slice 1/2 native SwiftUI stats surface.
//  Restores full mockup-style visual cards while preserving current data wiring.
//

import SwiftUI

struct StatsArcadeSliceOneView: View {
    let calendarUserId: UUID?
    let profileTimeZoneIdentifier: String?
    let battleStats: HealthBattleStats
    let rivalStats: [HomeRivalStat]
    let rangeMargins: [DailyBattleMargin]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var headerVisible = false

    private var topRivals: [HomeRivalStat] {
        rivalStats.sorted {
            if $0.finalizedDaysCompeted != $1.finalizedDaysCompeted {
                return $0.finalizedDaysCompeted > $1.finalizedDaysCompeted
            }
            return ($0.lastPlayedOn ?? .distantPast) > ($1.lastPlayedOn ?? .distantPast)
        }
    }

    private var mostWanted: HomeRivalStat? { topRivals.first }

    /// Neon green accent for the bounty-style Most Wanted card.
    private var mostWantedTint: Color { Color(red: 0.12, green: 1, blue: 0.42) }

    private var rematchButtonTint: Color { Color(red: 0.05, green: 0.92, blue: 0.38) }

    private var toughestRival: HomeRivalStat? {
        topRivals.max {
            if $0.matchLosses != $1.matchLosses { return $0.matchLosses < $1.matchLosses }
            return $0.finalizedDaysCompeted < $1.finalizedDaysCompeted
        }
    }

    private var dominatedRival: HomeRivalStat? {
        topRivals.max {
            if $0.matchWins != $1.matchWins { return $0.matchWins < $1.matchWins }
            return $0.finalizedDaysCompeted < $1.finalizedDaysCompeted
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            battleImpactCard
            opponentsCard
            currentStreakCard
            ActivityCalendarCard(
                userId: calendarUserId,
                profileTimeZoneIdentifier: profileTimeZoneIdentifier
            )
            stepsDuringBattlesCard
            opponentsVsYouCard
        }
        .task {
            if reduceMotion {
                headerVisible = true
                return
            }
            try? await Task.sleep(nanoseconds: 80_000_000)
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.75)) {
                headerVisible = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("FITUP")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Color(red: 0, green: 0.86, blue: 1))
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 4, height: 4)
                Text("STATS")
                    .font(.system(size: 22, weight: .black))
                    .tracking(2.2)
                    .foregroundStyle(.white)
            }
            .opacity(headerVisible ? 1 : 0)
            .offset(x: headerVisible ? 0 : -140)

            Text("YOUR PROGRESS · YOUR RIVALS")
                .font(.system(size: 11, weight: .bold))
                .tracking(2.4)
                .foregroundStyle(Color(red: 0, green: 0.72, blue: 0.85))
        }
        .padding(.top, 6)
    }

    private var battleImpactCard: some View {
        themedCard(
            title: "BATTLE IMPACT",
            tint: Color(red: 0, green: 0.86, blue: 1),
            showsInfo: true
        ) {
            VStack(spacing: 10) {
                VStack(spacing: 6) {
                    Text("When battling you make")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.white.opacity(0.93))
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("+2,670")
                            .font(.system(size: 30, weight: .black, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(Color(red: 0, green: 0.86, blue: 1))
                            .shadow(color: Color(red: 0, green: 0.86, blue: 1).opacity(0.6), radius: 8)
                        Text("more steps")
                            .font(.system(size: 14, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(Color.white.opacity(0.88))
                    }
                    Text("than when you're not battling")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(Color.white.opacity(0.78))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.36))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(red: 0, green: 0.86, blue: 1).opacity(0.2), lineWidth: 1)
                }

                HStack(spacing: 8) {
                    comparisonTile(
                        value: "3,820",
                        title: "NORMAL DAY",
                        subtitle: "90-day avg",
                        tint: Color(red: 1, green: 0.55, blue: 0),
                        emphasized: false
                    )
                    Text("VS")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.white.opacity(0.32))
                    comparisonTile(
                        value: "6,490",
                        title: "BATTLE DAY",
                        subtitle: "Active matches",
                        tint: Color(red: 0, green: 0.86, blue: 1),
                        emphasized: true
                    )
                }

                battleBoostSummaryRow

                unresolvedPill("UNRESOLVED IN SLICE 2 · EXACT BASELINE VS BATTLE-DAY AVERAGES")
            }
        }
    }

    private var opponentsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR OPPONENTS")
                .font(.system(size: 21, weight: .black))
                .tracking(2.2)
                .foregroundStyle(Color(red: 1, green: 0.5, blue: 0.13))
                .shadow(color: Color(red: 1, green: 0.5, blue: 0.13).opacity(0.5), radius: 8)

            topRivalsCard
            mostWantedCard
            toughestCard
            dominatedCard
        }
        .padding(14)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(red: 1, green: 0.55, blue: 0.2).opacity(0.5), lineWidth: 1.6)
        }
    }

    private var topRivalsCard: some View {
        opponentsGlassCard(
            title: "TOP RIVALS",
            tint: Color(red: 0.75, green: 0.38, blue: 1),
            cornerLabel: "MOST MATCHES\nAGAINST YOU"
        ) {
            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    Text("RIVAL")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("FINALIZED\nDAYS")
                        .multilineTextAlignment(.center)
                        .frame(width: 72, alignment: .center)
                        .padding(.trailing, 6)
                    Text("ALL-TIME")
                        .frame(width: 58, alignment: .center)
                        .padding(.trailing, 4)
                }
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Color.white.opacity(0.46))

                if topRivals.isEmpty {
                    unresolvedPill("No rival stats available yet.")
                } else {
                    ForEach(Array(topRivals.prefix(3).enumerated()), id: \.element.id) { idx, rival in
                        HStack(spacing: 8) {
                            avatarBadge(for: rival)
                            Text("\(idx + 1). \(rival.opponentDisplayName)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer(minLength: 4)
                            Text("\(rival.finalizedDaysCompeted)")
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(Color(red: 0.75, green: 0.38, blue: 1))
                                .frame(width: 72, alignment: .center)
                                .shadow(color: Color.green.opacity(0.35), radius: 6)
                            Text(rivalSeriesRecord(rival))
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(rival.matchWins >= rival.matchLosses ? Color.green : Color.red)
                                .frame(width: 58, alignment: .center)
                                .padding(.trailing, 4)
                        }
                        if idx < min(topRivals.count, 3) - 1 {
                            Divider().overlay(Color.white.opacity(0.14))
                        }
                    }
                    Text("VIEW ALL RIVALS →")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.white.opacity(0.42))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
        }
    }

    private var mostWantedCard: some View {
        opponentsGlassCard(
            title: "MOST WANTED",
            tint: mostWantedTint,
            cornerLabel: "MOST BATTLED\nOPPONENT",
            cornerLabelScale: 2.6
        ) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .center, spacing: 10) {
                    if let rival = mostWanted {
                        avatarBadge(for: rival, size: 42)
                        Text(rival.opponentDisplayName)
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(mostWantedTint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 8)
                        Text("\(rival.matchWins + rival.matchLosses + rival.matchTies) BATTLES")
                            .font(.system(size: 11, weight: .black))
                            .tracking(2.2)
                            .foregroundStyle(Color.white.opacity(0.72))
                            .multilineTextAlignment(.trailing)
                            .padding(.trailing, 10)
                    } else {
                        Text("No rival stats available yet.")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.72))
                    }
                }

                HStack(spacing: 4) {
                    ForEach(Array(Self.lastFivePlaceholder.enumerated()), id: \.offset) { _, isWin in
                        Text(isWin ? "W" : "L")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(isWin ? Color.green : Color.red)
                            .frame(width: 14, height: 14)
                            .background((isWin ? Color.green : Color.red).opacity(0.16))
                            .clipShape(Circle())
                    }
                    Spacer()
                }

                if let rival = mostWanted {
                    HStack(spacing: 7) {
                        statCell(value: "\(rival.matchWins)", label: "WINS", color: .green)
                        statCell(value: "\(rival.matchLosses)", label: "LOSSES", color: .red)
                        statCell(value: "\(rival.winPercentage)%", label: "WIN RATE", color: Color(red: 1, green: 0.7, blue: 0))
                    }
                }

                rematchButton

                unresolvedPill("UNRESOLVED IN SLICE 2 · LAST-5 + TOTAL BATTLE COUNT")
            }
        }
    }

    private var toughestCard: some View {
        opponentsDetailCard(
            title: "TOUGHEST OPPONENT",
            tint: Color(red: 1, green: 0.31, blue: 0.31),
            cornerLabel: "MOST BATTLES\nWON VS YOU",
            cornerLabelScale: 2.6,
            rival: toughestRival,
            winsByThem: toughestRival?.matchLosses ?? 0,
            winsByYou: toughestRival?.matchWins ?? 0,
            marginHeadline: "They typically beat you by"
        )
    }

    private var dominatedCard: some View {
        opponentsDetailCard(
            title: "MOST DOMINATED",
            tint: Color(red: 0, green: 0.86, blue: 0.78),
            cornerLabel: "MOST BATTLES\nWON BY YOU",
            cornerLabelScale: 2.6,
            rival: dominatedRival,
            winsByThem: dominatedRival?.matchLosses ?? 0,
            winsByYou: dominatedRival?.matchWins ?? 0,
            marginHeadline: "You typically beat them by"
        )
    }

    private func opponentsDetailCard(
        title: String,
        tint: Color,
        cornerLabel: String,
        cornerLabelScale: CGFloat = 1,
        rival: HomeRivalStat?,
        winsByThem: Int,
        winsByYou: Int,
        marginHeadline: String
    ) -> some View {
        opponentsGlassCard(
            title: title,
            tint: tint,
            cornerLabel: cornerLabel,
            cornerLabelScale: cornerLabelScale
        ) {
            if let rival {
                let totalSeries = rival.matchWins + rival.matchLosses + rival.matchTies
                let marginSteps = abs(Int((rival.avgFinalizedDailyMargin ?? 0).rounded()))
                let unresolvedBattleDays = max(rival.finalizedDaysCompeted, 1)
                let unresolvedTheyWonDays = max(1, unresolvedBattleDays / 2)
                let unresolvedYouWonDays = max(1, unresolvedBattleDays - unresolvedTheyWonDays)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        avatarBadge(for: rival, size: 40)
                        Text(rival.opponentDisplayName)
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(tint)
                        Spacer()
                    }

                    VStack(spacing: 10) {
                        Text(marginHeadline)
                            .font(.system(size: 16, weight: .black))
                            .tracking(1.3)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.white.opacity(0.92))
                            .frame(maxWidth: .infinity)

                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Spacer(minLength: 0)
                            Text(signedValue(marginSteps))
                                .font(.system(size: 34, weight: .black, design: .monospaced))
                                .tracking(2)
                                .foregroundStyle(tint)
                            Text("steps")
                                .font(.system(size: 15, weight: .bold))
                                .tracking(2.4)
                                .foregroundStyle(Color.white.opacity(0.78))
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.bottom, 8)

                    HStack(spacing: 6) {
                        statCell(value: "\(totalSeries)", label: "TOTAL BATTLES", color: .white)
                        statCell(value: "\(winsByThem)", label: "BATTLES WON BY THEM", color: .red)
                    }

                    HStack(spacing: 6) {
                        statCell(value: "\(unresolvedBattleDays)", label: "BATTLE DAYS", color: .white)
                        statCell(value: "\(unresolvedTheyWonDays)", label: "DAYS THEY WON", color: .red)
                        statCell(value: "\(unresolvedYouWonDays)", label: "DAYS YOU WON", color: .green)
                    }

                    VStack(spacing: 3) {
                        Text("AVG WINNING MARGIN · SERIES")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.9)
                            .foregroundStyle(Color.white.opacity(0.82))
                        Text(String(format: "%.1f", Double(winsByYou - winsByThem)))
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(tint)
                        Text("days per battle (placeholder)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.78))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(tint.opacity(0.4), lineWidth: 1.2)
                    }

                    unresolvedPill("UNRESOLVED IN SLICE 2 · BATTLE-DAY GRIDS + DAY-LEVEL MARGINS")
                }
            } else {
                unresolvedPill("No rival stats available yet.")
            }
        }
    }

    private var currentStreakCard: some View {
        themedCard(
            title: "CURRENT STREAK",
            tint: Color(red: 1, green: 0.7, blue: 0),
            showsInfo: true
        ) {
            VStack(spacing: 8) {
                Text("\(battleStats.currentStreakCount)")
                    .font(.system(size: 52, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 1, green: 0.7, blue: 0))
                Text("MATCH STREAK (LIFETIME)")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2.4)
                    .foregroundStyle(Color(red: 1, green: 0.7, blue: 0).opacity(0.56))
                Text("Type: \(battleStats.currentStreakType.rawValue.capitalized)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.76))

                HStack(spacing: 6) {
                    ForEach(Array(Self.streakPlaceholder.enumerated()), id: \.offset) { _, state in
                        streakDot(state: state)
                    }
                }

                unresolvedPill("UNRESOLVED IN SLICE 2 · BATTLE-DAY TIMELINE DOTS")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var stepsDuringBattlesCard: some View {
        themedCard(
            title: "STEPS DURING BATTLES",
            tint: Color(red: 1, green: 0.84, blue: 0),
            showsInfo: true
        ) {
            VStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(red: 1, green: 0.84, blue: 0))
                Text("+24,847")
                    .font(.system(size: 31, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 1, green: 0.84, blue: 0))
                    .shadow(color: Color(red: 1, green: 0.84, blue: 0).opacity(0.5), radius: 8)
                Text("BONUS STEPS FROM BATTLES THIS MONTH")
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.1)
                    .foregroundStyle(Color(red: 1, green: 0.84, blue: 0).opacity(0.9))
                Text("~11 extra miles because of your rivals")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.62))
                unresolvedPill("UNRESOLVED IN SLICE 2 · CURRENT-MONTH BATTLE-DAY STEP ROLLUP")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var opponentsVsYouCard: some View {
        themedCard(
            title: "OPPONENTS VS YOU",
            tint: Color(red: 0.75, green: 0.38, blue: 1),
            showsInfo: true
        ) {
            VStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color(red: 0.75, green: 0.38, blue: 1))
                Text("31,204")
                    .font(.system(size: 31, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 0.75, green: 0.38, blue: 1))
                    .shadow(color: Color(red: 0.75, green: 0.38, blue: 1).opacity(0.5), radius: 8)
                Text("STEPS YOUR OPPONENTS HAVE TAKEN AGAINST YOU")
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.75, green: 0.38, blue: 1).opacity(0.9))
                Text("Your rivals are grinding hard — stay ahead")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
                Text("Est. by AI based on rival activity vs their baseline patterns")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.3))
                unresolvedPill("UNRESOLVED IN SLICE 2 · OPPONENT TOTAL STEP ROLLUP")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func themedCard(
        title: String,
        tint: Color,
        showsInfo: Bool = false,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .black))
                .tracking(2)
                .foregroundStyle(tint)
                .padding(.trailing, showsInfo ? 44 : 0)

            content()
        }
        .padding(14)
        .background(Color(red: 0.02, green: 0.03, blue: 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.42), lineWidth: 1.4)
        }
        .overlay(alignment: .topTrailing) {
            if showsInfo {
                StatsCardInfoButton(accessibilityTitle: title.lowercased()) {}
                    .padding(8)
            }
        }
    }

    private var battleBoostSummaryRow: some View {
        let boostTint = Color(red: 0, green: 0.86, blue: 1)
        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                neonRetroEqualsSign(tint: boostTint)
                Text("+70% MORE STEPS WHEN BATTLING")
                    .font(.system(size: 14, weight: .black))
                    .tracking(2.2)
                    .foregroundStyle(boostTint)
                    .shadow(color: boostTint.opacity(0.75), radius: 10)
                    .shadow(color: boostTint.opacity(0.35), radius: 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 12)
            .padding(.horizontal, 12)

            Text("Competition literally makes you move more")
                .font(.system(size: 11, weight: .medium))
                .tracking(3.2)
                .foregroundStyle(Color.white.opacity(0.58))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.top, 18)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, minHeight: 88)
        .background(boostTint.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(boostTint.opacity(0.22), lineWidth: 1)
        }
    }

    private var rematchButton: some View {
        Button {
            // Slice 2: wire rematch navigation
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("REMATCH \(mostWanted?.opponentDisplayName.uppercased() ?? "RIVAL")")
                    .font(.system(size: 15, weight: .black))
                    .tracking(1.8)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(Color.black.opacity(0.88))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [
                        rematchButtonTint,
                        Color(red: 0.28, green: 1, blue: 0.55),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.2)
            }
            .shadow(color: rematchButtonTint.opacity(0.55), radius: 12, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func neonRetroEqualsSign(tint: Color) -> some View {
        VStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tint)
                .frame(width: 18, height: 3)
                .shadow(color: tint.opacity(0.8), radius: 6)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tint)
                .frame(width: 18, height: 3)
                .shadow(color: tint.opacity(0.8), radius: 6)
        }
        .padding(6)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(tint.opacity(0.45), lineWidth: 1)
        }
    }

    private func opponentsGlassCard(
        title: String,
        tint: Color,
        cornerLabel: String? = nil,
        cornerLabelScale: CGFloat = 1,
        @ViewBuilder content: () -> some View
    ) -> some View {
        let cornerFontSize = 8 * cornerLabelScale
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.system(size: 16, weight: .black))
                    .tracking(1.3)
                    .foregroundStyle(tint)
                Spacer()
                if let cornerLabel {
                    Text(cornerLabel)
                        .font(.system(size: cornerFontSize, weight: .black))
                        .tracking(cornerLabelScale > 1 ? 1.6 : 1)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .minimumScaleFactor(0.65)
                        .foregroundStyle(tint.opacity(0.92))
                        .shadow(color: tint.opacity(0.45), radius: 8)
                }
            }
            content()
        }
        .padding(12)
        .background(tint.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.6), lineWidth: 1.2)
        }
    }

    private func comparisonTile(
        value: String,
        title: String,
        subtitle: String,
        tint: Color,
        emphasized: Bool
    ) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .heavy))
                .tracking(2.2)
                .foregroundStyle(Color.white.opacity(0.88))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(emphasized ? tint : Color.white)
                Text("steps")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            Text(subtitle)
                .font(.system(size: 8, weight: .medium))
                .tracking(1.1)
                .foregroundStyle(Color.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background((emphasized ? tint.opacity(0.09) : tint.opacity(0.06)))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder((emphasized ? tint.opacity(0.5) : tint.opacity(0.3)), lineWidth: emphasized ? 1.8 : 1.2)
        }
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(1.8)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .foregroundStyle(Color.white.opacity(0.58))
            Text(value)
                .font(.system(size: 30, weight: .black, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func unresolvedPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(Color.white.opacity(0.88))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
            .overlay {
                Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            }
    }

    private func avatarBadge(for rival: HomeRivalStat, size: CGFloat = 30) -> some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.35))
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                }
            Text(initials(for: rival))
                .font(.system(size: max(10, size * 0.35), weight: .heavy))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }

    private func initials(for rival: HomeRivalStat) -> String {
        let trimmed = rival.opponentInitials.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return String(trimmed.prefix(2)).uppercased() }
        let fallback = rival.opponentDisplayName.prefix(2)
        return String(fallback).uppercased()
    }

    private func rivalSeriesRecord(_ rival: HomeRivalStat) -> String {
        if rival.matchTies > 0 {
            return "\(rival.matchWins)-\(rival.matchLosses)-\(rival.matchTies)"
        }
        return "\(rival.matchWins)-\(rival.matchLosses)"
    }

    private func signedValue(_ value: Int) -> String {
        if value == 0 { return "0" }
        return value > 0 ? "+\(value.formatted())" : "-\(abs(value).formatted())"
    }

    private func streakDot(state: StreakDotState) -> some View {
        let baseColor: Color
        switch state {
        case .win:
            baseColor = .green
        case .loss:
            baseColor = .red
        case .today:
            baseColor = Color(red: 1, green: 0.7, blue: 0)
        }

        return Circle()
            .fill(baseColor.opacity(0.92))
            .frame(width: 11, height: 11)
            .overlay(alignment: .topTrailing) {
                if state == .win {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                        .overlay {
                            Circle().strokeBorder(Color.black.opacity(0.65), lineWidth: 1)
                        }
                        .offset(x: 2, y: -2)
                }
            }
    }

    private static let lastFivePlaceholder: [Bool] = [true, false, true, false, false]
    private static let streakPlaceholder: [StreakDotState] = [.loss, .win, .win, .loss, .win, .today]
}

private enum StreakDotState {
    case win
    case loss
    case today
}

#Preview {
    ScrollView {
        StatsArcadeSliceOneView(
            calendarUserId: nil,
            profileTimeZoneIdentifier: nil,
            battleStats: .empty,
            rivalStats: [],
            rangeMargins: []
        )
        .padding(.horizontal, 16)
    }
    .background { BackgroundGradientView() }
}
