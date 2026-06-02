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
    let battleStepsDisplay: StatsBattleStepsDisplay?
    let battleImpactMetric: StatsBattleImpactMetric?
    let monthlyBattleBonusMetric: StatsMonthlyBattleBonusMetric?
    let opponentStepsRollups: StatsOpponentStepsRollups?
    let streakTimelineDots: [StatsArcadeStreakDot]?
    let completedMatches: [ActivityCompletedMatch]
    let isLoadingCompletedMatches: Bool
    var onLoadCompletedMatches: () -> Void
    var onOpenMatchDetails: (UUID, String) -> Void
    var onOpenChallenge: (ChallengePrefillOpponent) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var headerVisible = false
    @State private var isAllRivalsSheetPresented = false
    @State private var isMostWantedPastMatchesExpanded = false
    @State private var isToughestPastMatchesExpanded = false
    @State private var isDominatedPastMatchesExpanded = false

    private static let rivalThemeColors: [Color] = [
        Color(red: 0, green: 0.86, blue: 1),
        Color(red: 1, green: 0.55, blue: 0),
        Color(red: 0.75, green: 0.38, blue: 1),
    ]

    private static let battleImpactPositiveTint = Color(red: 0, green: 0.86, blue: 1)
    private static let battleImpactNegativeTint = Color(red: 1, green: 0.84, blue: 0)
    private static let battleStepsTint = Color(red: 0.12, green: 1, blue: 0.55)

    private static let unresolvedPlaceholder = "—"

    private static let statsSectionTitle: CGFloat = 18
    private static let statsCardTitle: CGFloat = 16
    private static let statsGlassCardTitle: CGFloat = 14
    private static let opponentProfileAccent = Color(red: 1, green: 0.55, blue: 0.13)

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

    /// Series losses only — excludes rivals you have never lost a completed battle to.
    private var toughestRival: HomeRivalStat? {
        let candidates = topRivals.filter { $0.matchLosses > 0 }
        return candidates.max { a, b in
            if a.matchLosses != b.matchLosses { return a.matchLosses < b.matchLosses }
            let marginA = opponentBeatMarginSteps(for: a) ?? Int.max
            let marginB = opponentBeatMarginSteps(for: b) ?? Int.max
            if marginA != marginB { return marginA > marginB }
            return a.finalizedDaysCompeted < b.finalizedDaysCompeted
        }
    }

    /// Series wins only — excludes rivals you have never beaten in a completed battle.
    private var dominatedRival: HomeRivalStat? {
        let candidates = topRivals.filter { $0.matchWins > 0 }
        return candidates.max { a, b in
            if a.matchWins != b.matchWins { return a.matchWins < b.matchWins }
            let marginA = viewerBeatMarginSteps(for: a) ?? 0
            let marginB = viewerBeatMarginSteps(for: b) ?? 0
            if marginA != marginB { return marginA < marginB }
            return a.finalizedDaysCompeted < b.finalizedDaysCompeted
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            battleStepsHeroCard
            header
            battleImpactCard
            ActivityCalendarCard(
                userId: calendarUserId,
                profileTimeZoneIdentifier: profileTimeZoneIdentifier
            )
            opponentsCard
            currentStreakCard
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
        .sheet(isPresented: $isAllRivalsSheetPresented) {
            StatsArcadeAllRivalsSheet(rivals: topRivals)
        }
    }

    private var battleStepsHeroCard: some View {
        let display = battleStepsDisplay
        let todaySteps = display?.todaySteps ?? 0
        let allTimeSteps = display?.allTimeSteps ?? 0
        let isTodayBattleDay = display?.isTodayBattleDay == true
        let hasData = display != nil

        return VStack(alignment: .leading, spacing: 10) {
            Text("BATTLE STEPS")
                .font(.system(size: Self.statsSectionTitle, weight: .black))
                .tracking(2.2)
                .foregroundStyle(Self.battleStepsTint)

            HStack(spacing: 8) {
                battleStepsSubCard(
                    title: "TODAY'S BATTLE STEPS",
                    value: isTodayBattleDay ? todaySteps : nil,
                    subtitle: isTodayBattleDay
                        ? "Live steps on a battle day"
                        : "No steps battle today",
                    showsLiveNote: false
                )
                battleStepsSubCard(
                    title: "ALL-TIME BATTLE STEPS",
                    value: hasData ? allTimeSteps : nil,
                    subtitle: "Total steps taken on days you were in a battle",
                    showsLiveNote: isTodayBattleDay
                )
            }
        }
        .padding(12)
        .glassCard(.base)
    }

    private func battleStepsSubCard(
        title: String,
        value: Int?,
        subtitle: String,
        showsLiveNote: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .black))
                .tracking(0.6)
                .foregroundStyle(Self.battleStepsTint.opacity(0.92))
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            if let value {
                StatsAnimatedStepCount(value: value, tint: Self.battleStepsTint)
            } else {
                Text(Self.unresolvedPlaceholder)
                    .font(.system(size: 26, weight: .black, design: .monospaced))
                    .foregroundStyle(Self.battleStepsTint)
            }

            Text(subtitle)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)

            if showsLiveNote {
                Text("Includes today's live steps")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Self.battleStepsTint.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Self.battleStepsTint.opacity(0.22), lineWidth: 1)
        )
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
        let impact = battleImpactMetric
        let hasImpactData = impact?.hasEnoughSample == true
        let deltaSteps = impact?.deltaSteps ?? 0
        let isPositiveDelta = deltaSteps >= 0
        let heroTint = isPositiveDelta ? Self.battleImpactPositiveTint : Self.battleImpactNegativeTint
        let boostPercent = impact?.boostPercent ?? 0
        return themedCard(
            title: "BATTLE IMPACT",
            tint: Self.battleImpactPositiveTint,
            showsInfo: true
        ) {
            VStack(spacing: 10) {
                VStack(spacing: 6) {
                    Text("On battle days, you take")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.white.opacity(0.93))
                    Text(hasImpactData ? signedValue(deltaSteps) : Self.unresolvedPlaceholder)
                        .font(.system(size: 30, weight: .black, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(heroTint)
                        .shadow(color: heroTint.opacity(0.6), radius: 8)
                    if hasImpactData {
                        Text(isPositiveDelta ? "more steps than usual!" : "fewer steps than usual!")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(1.1)
                            .foregroundStyle(Color.white.opacity(0.78))
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.36))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(heroTint.opacity(0.2), lineWidth: 1)
                }

                HStack(spacing: 8) {
                    comparisonTile(
                        value: hasImpactData
                            ? (impact?.normalDayAverageSteps ?? 0).formatted()
                            : Self.unresolvedPlaceholder,
                        title: "NORMAL DAY",
                        subtitle: "AVERAGE",
                        tint: Color(red: 1, green: 0.55, blue: 0),
                        emphasized: false
                    )
                    Text("VS")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.white.opacity(0.32))
                    comparisonTile(
                        value: hasImpactData
                            ? (impact?.battleDayAverageSteps ?? 0).formatted()
                            : Self.unresolvedPlaceholder,
                        title: "BATTLE DAY",
                        subtitle: "AVERAGE",
                        tint: Self.battleImpactPositiveTint,
                        emphasized: true
                    )
                }

                if hasImpactData, boostPercent > 0 {
                    battleBoostSummaryRow(boostPercent: boostPercent)
                }

                if hasImpactData, !isPositiveDelta {
                    Text("You need to step it up when battling someone! Let's go!")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(Self.battleImpactNegativeTint.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }

                if !hasImpactData {
                    unresolvedPill("NEEDS MORE DATA")
                }
            }
        }
    }

    private var opponentsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR OPPONENTS")
                .font(.system(size: Self.statsSectionTitle, weight: .black))
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
                    Text("TOTAL BATTLE\nDAYS")
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
                        let themeColor = rivalThemeColor(at: idx)
                        HStack(spacing: 8) {
                            avatarBadge(for: rival, themeColor: themeColor)
                            Text("\(idx + 1). \(rival.opponentDisplayName)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(themeColor)
                            Spacer(minLength: 4)
                            Text("\(rival.finalizedDaysCompeted)")
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(themeColor)
                                .frame(width: 72, alignment: .center)
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
                    Button {
                        isAllRivalsSheetPresented = true
                    } label: {
                        Text("VIEW ALL RIVALS →")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(Color.white.opacity(topRivals.isEmpty ? 0.28 : 0.42))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(topRivals.isEmpty)
                }
            }
        }
    }

    private var mostWantedCard: some View {
        opponentsGlassCard(
            title: "MOST WANTED",
            tint: mostWantedTint,
            cornerLabel: "MOST BATTLED\nOPPONENT",
            compact: true
        ) {
            VStack(alignment: .leading, spacing: 7) {
                if let rival = mostWanted {
                    centeredOpponentProfile(
                        rival: rival,
                        avatarSize: 36,
                        battlesSubtitle: "\(rival.matchWins + rival.matchLosses + rival.matchTies) BATTLES"
                    )
                } else {
                    Text("No rival stats available yet.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .frame(maxWidth: .infinity)
                }

                HStack(spacing: 4) {
                    ForEach(Array((mostWantedRecentSeriesResults ?? []).enumerated()), id: \.offset) { _, result in
                        Text(result)
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(colorForSeriesResult(result))
                            .frame(width: 14, height: 14)
                            .background(colorForSeriesResult(result).opacity(0.16))
                            .clipShape(Circle())
                    }
                    Spacer()
                }

                if let rival = mostWanted {
                    HStack(spacing: 6) {
                        opponentStatCell(value: "\(rival.matchWins)", label: "WINS", valueColor: .green, glowTint: mostWantedTint)
                        opponentStatCell(value: "\(rival.matchLosses)", label: "LOSSES", valueColor: .red, glowTint: mostWantedTint)
                        opponentStatCell(
                            value: "\(rival.winPercentage)%",
                            label: "WIN RATE",
                            valueColor: Color(red: 1, green: 0.7, blue: 0),
                            glowTint: mostWantedTint
                        )
                    }
                }

                rematchButton

                if let rival = mostWanted {
                    opponentPastMatchesSection(
                        rival: rival,
                        tint: mostWantedTint,
                        isExpanded: $isMostWantedPastMatchesExpanded
                    )
                }

                if mostWantedRecentSeriesResults == nil {
                    unresolvedPill("BUILDING HISTORY")
                }
            }
        }
    }

    private var toughestCard: some View {
        opponentsDetailCard(
            kind: .toughest,
            tint: Color(red: 1, green: 0.31, blue: 0.31),
            cornerLabel: "BATTLES\nAGAINST YOU",
            pastMatchesExpanded: $isToughestPastMatchesExpanded,
            rival: toughestRival
        )
    }

    private var dominatedCard: some View {
        opponentsDetailCard(
            kind: .dominated,
            tint: Color(red: 0, green: 0.86, blue: 0.78),
            cornerLabel: "MOST BATTLES\nWON BY YOU",
            pastMatchesExpanded: $isDominatedPastMatchesExpanded,
            rival: dominatedRival
        )
    }

    private enum OpponentDetailCardKind {
        case toughest
        case dominated

        var title: String {
            switch self {
            case .toughest: return "TOUGHEST OPPONENT"
            case .dominated: return "MOST DOMINATED"
            }
        }

        var marginHeadline: String {
            switch self {
            case .toughest: return "They typically beat you by"
            case .dominated: return "You typically beat them by"
            }
        }

        var emptyMessage: String {
            switch self {
            case .toughest: return "No series losses yet — your toughest rival will show up here."
            case .dominated: return "No series wins yet — dominate someone to show up here."
            }
        }
    }

    private func opponentsDetailCard(
        kind: OpponentDetailCardKind,
        tint: Color,
        cornerLabel: String,
        pastMatchesExpanded: Binding<Bool>,
        rival: HomeRivalStat?
    ) -> some View {
        opponentsGlassCard(
            title: kind.title,
            tint: tint,
            cornerLabel: cornerLabel,
            compact: true
        ) {
            if let rival {
                let totalSeries = rival.matchWins + rival.matchLosses + rival.matchTies
                let winsByThem = rival.matchLosses
                let winsByYou = rival.matchWins
                let marginSteps = heroMarginSteps(for: rival, kind: kind)
                let battleDays = max(0, rival.finalizedDaysCompeted)
                let theyWonDays = max(0, rival.daysWonByOpponent ?? 0)
                let youWonDays = max(0, rival.daysWonByViewer ?? 0)
                let avgWinningMargin = heroMarginSteps(for: rival, kind: kind) ?? 0
                let hasSlice3ADetail = hasRivalDetailMargins(rival, kind: kind)

                VStack(alignment: .leading, spacing: 7) {
                    centeredOpponentProfile(rival: rival, avatarSize: 36)

                    VStack(spacing: 6) {
                        Text(kind.marginHeadline)
                            .font(.system(size: 13, weight: .black))
                            .tracking(0.6)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.white.opacity(0.92))
                            .frame(maxWidth: .infinity)

                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Spacer(minLength: 0)
                            Text(marginSteps.map { signedValue($0) } ?? Self.unresolvedPlaceholder)
                                .font(.system(size: 26, weight: .black, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(tint)
                            Text("steps")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(Color.white.opacity(0.78))
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.bottom, 4)

                    HStack(spacing: 6) {
                        opponentStatCell(value: "\(totalSeries)", label: "TOTAL BATTLES", valueColor: .white, glowTint: tint)
                        opponentStatCell(value: "\(winsByThem)", label: "BATTLES WON BY THEM", valueColor: .red, glowTint: tint)
                    }

                    HStack(spacing: 6) {
                        opponentStatCell(value: "\(battleDays)", label: "BATTLE DAYS", valueColor: .white, glowTint: tint)
                        opponentStatCell(value: "\(theyWonDays)", label: "DAYS THEY WON", valueColor: .red, glowTint: tint)
                        opponentStatCell(value: "\(youWonDays)", label: "DAYS YOU WON", valueColor: .green, glowTint: tint)
                    }

                    opponentLightSubcellPanel(glowTint: tint) {
                        VStack(spacing: 3) {
                            Text("AVG WINNING MARGIN · SERIES")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.4)
                                .foregroundStyle(.white)
                            Text(signedValue(avgWinningMargin))
                                .font(.system(size: 20, weight: .black, design: .monospaced))
                                .tracking(0.6)
                                .foregroundStyle(tint)
                            Text("steps on days won")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.3)
                                .foregroundStyle(Color.white.opacity(0.78))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }

                    if !hasSlice3ADetail {
                        unresolvedPill("NEEDS MORE DATA")
                    }

                    opponentPastMatchesSection(
                        rival: rival,
                        tint: tint,
                        isExpanded: pastMatchesExpanded
                    )
                }
            } else {
                unresolvedPill(kind.emptyMessage)
            }
        }
    }

    /// Average steps the opponent beats you by on days they won (viewer − opponent is negative).
    private func opponentBeatMarginSteps(for rival: HomeRivalStat) -> Int? {
        guard let margin = rival.avgMarginOnOpponentWinDays else { return nil }
        let steps = abs(Int(margin.rounded()))
        return steps > 0 ? steps : nil
    }

    /// Average steps you beat the opponent by on days you won.
    private func viewerBeatMarginSteps(for rival: HomeRivalStat) -> Int? {
        guard let margin = rival.avgMarginOnViewerWinDays else { return nil }
        let steps = Int(margin.rounded())
        return steps > 0 ? steps : nil
    }

    private func heroMarginSteps(for rival: HomeRivalStat, kind: OpponentDetailCardKind) -> Int? {
        switch kind {
        case .toughest:
            return opponentBeatMarginSteps(for: rival)
        case .dominated:
            return viewerBeatMarginSteps(for: rival)
        }
    }

    private func hasRivalDetailMargins(_ rival: HomeRivalStat, kind: OpponentDetailCardKind) -> Bool {
        guard rival.daysWonByViewer != nil, rival.daysWonByOpponent != nil else { return false }
        switch kind {
        case .toughest:
            return (rival.daysWonByOpponent ?? 0) > 0 && rival.avgMarginOnOpponentWinDays != nil
        case .dominated:
            return (rival.daysWonByViewer ?? 0) > 0 && rival.avgMarginOnViewerWinDays != nil
        }
    }

    private func opponentPastMatchesSection(
        rival: HomeRivalStat,
        tint: Color,
        isExpanded: Binding<Bool>
    ) -> some View {
        let filtered = completedMatches.filter { $0.opponentProfileId == rival.opponentProfileId }
        return PastMatchesExpandableList(
            title: "Past matches",
            matches: filtered,
            isExpanded: isExpanded.wrappedValue,
            isLoading: isLoadingCompletedMatches,
            style: .embedded,
            accent: tint,
            emptyMessage: "No past matches with \(rival.opponentDisplayName) yet.",
            onToggle: {
                let willExpand = !isExpanded.wrappedValue
                isExpanded.wrappedValue = willExpand
                if willExpand {
                    onLoadCompletedMatches()
                }
            },
            onOpenMatch: { match in
                onOpenMatchDetails(match.id, match.opponentName)
            }
        )
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

                if let dots = streakTimelineDots, !dots.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(dots.enumerated()), id: \.offset) { _, state in
                            streakDot(state: state)
                        }
                    }
                }

                if streakTimelineDots == nil {
                    unresolvedPill("BUILDING HISTORY")
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var stepsDuringBattlesCard: some View {
        let monthly = monthlyBattleBonusMetric
        let hasMonthlyData = monthly?.hasData == true
        return themedCard(
            title: "STEPS DURING BATTLES",
            tint: Color(red: 1, green: 0.84, blue: 0),
            showsInfo: true
        ) {
            VStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(red: 1, green: 0.84, blue: 0))
                Text(hasMonthlyData ? signedValue(monthly?.bonusSteps ?? 0) : Self.unresolvedPlaceholder)
                    .font(.system(size: 31, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 1, green: 0.84, blue: 0))
                    .shadow(color: Color(red: 1, green: 0.84, blue: 0).opacity(0.5), radius: 8)
                Text("BONUS STEPS FROM BATTLES THIS MONTH")
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.1)
                    .foregroundStyle(Color(red: 1, green: 0.84, blue: 0).opacity(0.9))
                Text(
                    hasMonthlyData
                        ? "~\((monthly?.approxMiles ?? 0).formatted()) extra miles because of your rivals"
                        : "\(Self.unresolvedPlaceholder) extra miles because of your rivals"
                )
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.62))
                if !hasMonthlyData {
                    unresolvedPill("NEEDS MORE DATA")
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var opponentsVsYouCard: some View {
        let rollups = opponentStepsRollups
        let hasRollups = rollups != nil
        return themedCard(
            title: "OPPONENTS VS YOU",
            tint: Color(red: 0.75, green: 0.38, blue: 1),
            showsInfo: true
        ) {
            VStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color(red: 0.75, green: 0.38, blue: 1))
                Text(hasRollups ? (rollups?.lifetimeSteps ?? 0).formatted() : Self.unresolvedPlaceholder)
                    .font(.system(size: 31, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 0.75, green: 0.38, blue: 1))
                    .shadow(color: Color(red: 0.75, green: 0.38, blue: 1).opacity(0.5), radius: 8)
                if let monthSteps = rollups?.currentMonthSteps, monthSteps > 0 {
                    Text("MTD: \(monthSteps.formatted())")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.72))
                }
                Text("STEPS YOUR OPPONENTS HAVE TAKEN AGAINST YOU")
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.75, green: 0.38, blue: 1).opacity(0.9))
                Text("Your rivals are grinding hard — stay ahead")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
                if !hasRollups {
                    unresolvedPill("NEEDS MORE DATA")
                }
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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: Self.statsCardTitle, weight: .black))
                .tracking(2)
                .foregroundStyle(tint)
                .padding(.trailing, showsInfo ? 44 : 0)

            content()
        }
        .padding(12)
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

    private func battleBoostSummaryRow(boostPercent: Int) -> some View {
        let boostTint = Self.battleImpactPositiveTint
        return Text("\(boostPercent)% MORE STEPS WHEN BATTLING")
            .font(.system(size: 14, weight: .black))
            .tracking(2.2)
            .foregroundStyle(boostTint)
            .shadow(color: boostTint.opacity(0.75), radius: 10)
            .shadow(color: boostTint.opacity(0.35), radius: 18)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(minHeight: 52)
            .background(boostTint.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(boostTint.opacity(0.22), lineWidth: 1)
            }
    }

    private var rematchButton: some View {
        Button {
            guard let rival = mostWanted else { return }
            onOpenChallenge(rival.challengePrefillOpponent())
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("REMATCH \(mostWanted?.opponentDisplayName.uppercased() ?? "RIVAL")")
                    .font(.system(size: 13, weight: .black))
                    .tracking(1.2)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(Color.black.opacity(0.88))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
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
        .disabled(mostWanted == nil)
        .opacity(mostWanted == nil ? 0.45 : 1)
    }

    private func opponentsGlassCard(
        title: String,
        tint: Color,
        cornerLabel: String? = nil,
        compact: Bool = false,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 8) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.system(size: Self.statsGlassCardTitle, weight: .black))
                    .tracking(1.3)
                    .foregroundStyle(tint)
                Spacer()
                if let cornerLabel {
                    Text(cornerLabel)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .foregroundStyle(Color.white.opacity(0.46))
                }
            }
            content()
        }
        .padding(10)
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

    private func centeredOpponentProfile(
        rival: HomeRivalStat,
        avatarSize: CGFloat = 36,
        battlesSubtitle: String? = nil
    ) -> some View {
        VStack(spacing: 6) {
            avatarBadge(for: rival, size: avatarSize, themeColor: Self.opponentProfileAccent)
            Text(rival.opponentDisplayName)
                .font(.system(size: 23, weight: .black))
                .foregroundStyle(Self.opponentProfileAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
            if let battlesSubtitle {
                Text(battlesSubtitle)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(Color.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func opponentStatCell(
        value: String,
        label: String,
        valueColor: Color,
        glowTint: Color
    ) -> some View {
        opponentLightSubcellPanel(glowTint: glowTint) {
            VStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.4)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.white)
                Text(value)
                    .font(.system(size: 23, weight: .black, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(valueColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
        }
    }

    private func opponentLightSubcellPanel<Content: View>(
        glowTint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.88, green: 0.92, blue: 0.98).opacity(0.14),
                                Color(red: 0.72, green: 0.82, blue: 0.95).opacity(0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8)
            }
            .shadow(color: Color.black.opacity(0.35), radius: 4, x: 2, y: 3)
            .shadow(color: glowTint.opacity(0.12), radius: 6)
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

    private func rivalThemeColor(at index: Int) -> Color {
        Self.rivalThemeColors[index % Self.rivalThemeColors.count]
    }

    private func avatarBadge(
        for rival: HomeRivalStat,
        size: CGFloat = 30,
        themeColor: Color? = nil
    ) -> some View {
        let stroke = themeColor ?? Color.white.opacity(0.22)
        return ZStack {
            Circle()
                .fill(Color.black.opacity(0.35))
                .overlay {
                    if let themeColor {
                        Circle().fill(themeColor.opacity(0.12))
                    }
                }
                .overlay {
                    Circle().strokeBorder(stroke.opacity(themeColor == nil ? 1 : 0.55), lineWidth: 1)
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

    private func streakDot(state: StatsArcadeStreakDot) -> some View {
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

    private var mostWantedRecentSeriesResults: [String]? {
        guard let rival = mostWanted else { return nil }
        guard let values = rival.recentSeriesResults else { return nil }
        let cleaned = values
            .map { normalizeSeriesResult($0) }
            .filter { ["W", "L", "T"].contains($0) }
        guard !cleaned.isEmpty else { return nil }
        return Array(cleaned.prefix(5))
    }

    private func normalizeSeriesResult(_ value: String) -> String {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "W", "WIN":
            return "W"
        case "L", "LOSS":
            return "L"
        case "T", "TIE":
            return "T"
        default:
            return ""
        }
    }

    private func colorForSeriesResult(_ result: String) -> Color {
        switch result {
        case "W":
            return .green
        case "L":
            return .red
        case "T":
            return Color(red: 1, green: 0.72, blue: 0)
        default:
            return Color.white.opacity(0.6)
        }
    }

}

#Preview {
    ScrollView {
        StatsArcadeSliceOneView(
            calendarUserId: nil,
            profileTimeZoneIdentifier: nil,
            battleStats: .empty,
            rivalStats: [],
            battleStepsDisplay: StatsBattleStepsDisplay(todaySteps: 8420, allTimeSteps: 1_204_500, isTodayBattleDay: true),
            battleImpactMetric: nil,
            monthlyBattleBonusMetric: nil,
            opponentStepsRollups: nil,
            streakTimelineDots: nil,
            completedMatches: [],
            isLoadingCompletedMatches: false,
            onLoadCompletedMatches: {},
            onOpenMatchDetails: { _, _ in },
            onOpenChallenge: { _ in }
        )
        .padding(.horizontal, 16)
    }
    .background { BackgroundGradientView() }
}

// MARK: - Animated step count (increase-only tick)

private struct StatsAnimatedStepCount: View {
    let value: Int
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedValue: Int = 0

    var body: some View {
        Text(displayedValue.formatted())
            .font(.system(size: 26, weight: .black, design: .monospaced))
            .foregroundStyle(tint)
            .shadow(color: tint.opacity(0.45), radius: 8)
            .contentTransition(.numericText())
            .onAppear {
                displayedValue = value
            }
            .onChange(of: value) { oldValue, newValue in
                if reduceMotion {
                    displayedValue = newValue
                } else if newValue > oldValue {
                    withAnimation(.linear(duration: 0.5)) {
                        displayedValue = newValue
                    }
                } else {
                    displayedValue = newValue
                }
            }
    }
}
