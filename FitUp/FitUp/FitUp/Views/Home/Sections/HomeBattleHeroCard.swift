//
//  HomeBattleHeroCard.swift
//  FitUp
//
//  Home hero card: "Am I beating everyone today?"
//

import SwiftUI

struct HomeBattleHeroCard: View {
    private struct OpponentOrb: Identifiable {
        let id: String
        let name: String
        let initials: String
        let avatarColor: Color
        let margin: Int
        let rivalScoreHeadline: Int
        let rivalActualSteps: Int
        let marginIsBattleScore: Bool
        let marginColor: Color
        let isUrgent: Bool
        let opponentUpdatedAt: Date?
    }

    private struct RankedCompetitor: Identifiable {
        let id: String
        let name: String
        let score: Int
        let isMe: Bool
    }

    private struct NearbyRow: Identifiable {
        let id: String
        let rank: Int
        let name: String
        let score: Int
        let isMe: Bool
    }

    enum HeroMetric: String, CaseIterable, Identifiable {
        case steps
        case calories

        var id: String { rawValue }
        var label: String { self == .steps ? "Steps" : "Calories" }
        var metricType: String { self == .steps ? "steps" : "active_calories" }
        var unitLabel: String { self == .steps ? "steps" : "cal" }
    }

    let matches: [HomeActiveMatch]
    /// When set, ring and primary hero copy use this match (same as Home tap target). When `nil`, falls back to legacy selection inside the card.
    var featuredMatch: HomeActiveMatch? = nil

    private let selectedMetric: HeroMetric = .steps

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var animatedRingProgressTotal: Double = 0
    @State private var animatedCenterValue: Int = 0
    @State private var pulseGlow = false
    @State private var isBreathingExpanded = false
    @State private var urgentOrbPulse = false
    @State private var centerCountTask: Task<Void, Never>?

    private var matchesForSelectedMetric: [HomeActiveMatch] {
        matches.filter { normalizedMetric(for: $0.metricType) == selectedMetric }
    }

    private var topOpponentMatch: HomeActiveMatch? {
        matchesForSelectedMetric.max(by: { $0.comparableTheirScore < $1.comparableTheirScore })
    }

    private var closestAheadMatch: HomeActiveMatch? {
        matchesForSelectedMetric
            .filter { $0.comparableTheirScore > $0.comparableMyScore }
            .min(by: {
                ($0.comparableTheirScore - $0.comparableMyScore) < ($1.comparableTheirScore - $1.comparableMyScore)
            })
    }

    private var closestBehindMatch: HomeActiveMatch? {
        matchesForSelectedMetric
            .filter { $0.comparableTheirScore <= $0.comparableMyScore }
            .max(by: { $0.comparableTheirScore < $1.comparableTheirScore })
    }

    private var focusOpponentMatch: HomeActiveMatch? {
        featuredMatch ?? (closestAheadMatch ?? closestBehindMatch ?? topOpponentMatch)
    }

    private var hasAnyActiveMatch: Bool {
        !matchesForSelectedMetric.isEmpty
    }

    private var myToday: Int {
        matchesForSelectedMetric.map(\.myToday).max() ?? 0
    }

    /// Pace target for the ring: closest opponent ahead, else closest behind, else highest opponent total.
    private var focusOpponentToday: Int {
        guard let m = focusOpponentMatch else { return 0 }
        return m.comparableTheirScore
    }

    private var targetOpponentName: String {
        focusOpponentMatch?.opponent.displayName ?? "Opponent"
    }

    /// Leaderboard leader vs you — shown only when multiple battles and focus rival differs from top step total.
    private var topOpponentLineText: String? {
        guard hasAnyActiveMatch,
              matchesForSelectedMetric.count > 1,
              let top = topOpponentMatch,
              let focus = focusOpponentMatch,
              top.opponent.id != focus.opponent.id
        else { return nil }
        let topMargin = top.comparableMargin
        let status = topMargin == 0 ? "TIED" : (topMargin > 0 ? "AHEAD" : "BEHIND")
        return "Top: \(top.opponent.displayName) · \(status) \(formattedDelta(topMargin))"
    }

    private var isWinningState: Bool {
        hasAnyActiveMatch && marginVsTopOpponent > 0
    }

    private var isTiedState: Bool {
        hasAnyActiveMatch && marginVsTopOpponent == 0
    }

    private var neededToPass: Int {
        guard hasAnyActiveMatch, isBehindState else { return 0 }
        return abs(marginVsTopOpponent) + 1
    }

    private let ringOpenGapFraction: Double = 0.08

    private var ringTrackStart: Double {
        ringOpenGapFraction / 2
    }

    private var ringTrackSpan: Double {
        1 - ringOpenGapFraction
    }

    private var opponentComparableRingProgress: Double {
        guard hasAnyActiveMatch, let focus = focusOpponentMatch else { return 0 }
        let mine = focus.comparableMyScore
        let theirs = focus.comparableTheirScore
        let scale = max(1, mine, theirs)
        return min(max(Double(theirs) / Double(scale), 0), 1)
    }

    /// Relative pace proxy until 7-day baselines are threaded into HomeActiveMatch.
    /// Uses today's observed pace from both users so lead/deficit feels proportional.
    private var relativeDailyBaseline: Int {
        guard let focus = focusOpponentMatch else { return 3_000 }
        let mine = focus.comparableMyScore
        let theirs = focus.comparableTheirScore
        let nonZeroTotals = [mine, theirs].filter { $0 > 0 }
        guard !nonZeroTotals.isEmpty else { return 3_000 }
        let mean = Double(nonZeroTotals.reduce(0, +)) / Double(nonZeroTotals.count)
        return max(1_500, Int(mean.rounded()))
    }

    private var totalRelativeRingProgress: Double {
        let gap = abs(marginVsTopOpponent)
        return Double(gap) / Double(max(relativeDailyBaseline, 1))
    }

    private var primaryLapProgress: Double {
        min(max(animatedRingProgressTotal, 0), 1)
    }

    private var overflowLapProgress: Double {
        min(max(animatedRingProgressTotal - 1, 0), 1)
    }

    private func ringTrimEnd(for progress: Double) -> Double {
        ringTrackStart + (min(max(progress, 0), 1) * ringTrackSpan)
    }

    private var accentColor: Color {
        if !hasAnyActiveMatch || focusOpponentMatch == nil { return FitUpColors.Text.tertiary }
        if isTiedState { return FitUpColors.Neon.blue }
        return isWinningState ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange
    }

    private var accentGlowColor: Color {
        if !hasAnyActiveMatch || focusOpponentMatch == nil { return Color.white.opacity(0.18) }
        if isTiedState { return FitUpColors.Neon.cyan }
        return isWinningState ? FitUpColors.Neon.green : FitUpColors.Neon.pink
    }

    private var opponentColor: Color {
        if focusOpponentMatch == nil { return FitUpColors.Text.tertiary }
        return isWinningState ? FitUpColors.Neon.purple : FitUpColors.Neon.blue
    }

    private var ringLeadStatusLabel: String {
        guard hasAnyActiveMatch, focusOpponentMatch != nil else { return "NO BATTLE" }
        if marginVsTopOpponent > 0 { return "AHEAD BY" }
        if marginVsTopOpponent < 0 { return "BEHIND BY" }
        return "TIED"
    }

    private var heroCtaLine: String {
        guard hasAnyActiveMatch else { return "Start a battle to compete today" }
        if let m = focusOpponentMatch, m.isBalancedStepsBattle {
            let myBS = m.myBattleScore
            let theirBS = m.theirBattleScore
            if myBS == theirBS {
                return "Balanced Battle · Even Battle Score vs your rival"
            }
            if myBS > theirBS {
                return "Balanced Battle · +\(myBS - theirBS) Battle Score ahead"
            }
            return "Balanced Battle · \(theirBS - myBS) Battle Score behind"
        }
        if isBehindState { return "Walk \(neededToPass.formatted()) steps to take the lead" }
        if isWinningState { return "Keep your lead" }
        return "Take the lead today"
    }

    private var stateTextForRing: String {
        guard hasAnyActiveMatch else { return "NO BATTLE" }
        if isWinningState { return "WINNING TODAY" }
        if isBehindState { return "LOSING TODAY" }
        return "TIED TODAY"
    }

    private var marginVsTopOpponent: Int {
        guard let focus = focusOpponentMatch else { return 0 }
        return focus.comparableMargin
    }

    private var isBehindState: Bool {
        hasAnyActiveMatch && focusOpponentMatch != nil && marginVsTopOpponent < 0
    }

    private var displayedCenterTarget: Int {
        hasAnyActiveMatch ? marginVsTopOpponent : myToday
    }

    private var ringCenterUnitText: String {
        if let m = focusOpponentMatch, m.isBalancedStepsBattle { return "Battle Score" }
        return "STEPS"
    }

    private var ringCenterContextText: String {
        stateTextForRing
    }

    private var ringOpponentTotalText: String? {
        guard hasAnyActiveMatch, let focusOpponentMatch else { return nil }
        if focusOpponentMatch.isBalancedStepsBattle {
            return "Rival \(focusOpponentMatch.theirBattleScore.formatted()) Battle Score · You \(focusOpponentMatch.myBattleScore.formatted()) · Actual: You \(focusOpponentMatch.myToday.formatted()) · Them \(focusOpponentMatch.theirToday.formatted())"
        }
        return "\(focusOpponentMatch.theirToday.formatted()) total"
    }

    private var accessibilityMetricUnit: String {
        "steps"
    }

    private var ringCenterAccessibilityLabel: String {
        if hasAnyActiveMatch, let m = focusOpponentMatch, m.isBalancedStepsBattle {
            let direction = displayedCenterTarget >= 0 ? "Plus" : "Minus"
            let state = isWinningState ? "winning today" : (isBehindState ? "losing today" : "tied today")
            return "\(direction) \(abs(displayedCenterTarget).formatted()) battle score, \(state), versus \(targetOpponentName)"
        }
        if hasAnyActiveMatch {
            let direction = displayedCenterTarget >= 0 ? "Plus" : "Minus"
            let state = isWinningState ? "winning today" : (isBehindState ? "losing today" : "tied today")
            return "\(direction) \(abs(displayedCenterTarget).formatted()) \(accessibilityMetricUnit), \(state), versus \(targetOpponentName)"
        }
        return "No step battle yet"
    }

    private var ringBreathScale: CGFloat {
        guard !reduceMotion else { return 1.0 }
        return isBreathingExpanded ? 1.0 : 0.969
    }

    private var ringBreathLineWidthDelta: CGFloat {
        guard !reduceMotion else { return 0 }
        return isBreathingExpanded ? 0.8 : -0.8
    }

    private var myScoreForRivalList: Int {
        guard !matchesForSelectedMetric.isEmpty else { return 0 }
        if matchesForSelectedMetric.contains(where: \.isBalancedStepsBattle) {
            return matchesForSelectedMetric.map(\.comparableMyScore).max() ?? 0
        }
        return myToday
    }

    private var displayedOpponentOrbs: [OpponentOrb] {
        Array(matchesForSelectedMetric.prefix(4).enumerated()).map { index, match in
            let margin = match.comparableMargin
            let rawInitials = match.opponent.initials.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = String(match.opponent.displayName.prefix(2)).uppercased()
            return OpponentOrb(
                id: match.id.uuidString,
                name: match.opponent.displayName,
                initials: rawInitials.isEmpty ? fallback : rawInitials,
                avatarColor: ProfileAccentColor.swiftUIColor(hex: match.opponent.colorHex),
                margin: margin,
                rivalScoreHeadline: match.isBalancedStepsBattle ? match.theirBattleScore : match.theirToday,
                rivalActualSteps: match.theirToday,
                marginIsBattleScore: match.isBalancedStepsBattle,
                marginColor: marginColor(for: margin),
                isUrgent: index == 0,
                opponentUpdatedAt: match.opponentTodayUpdatedAt
            )
        }
    }

    private var rankedCompetitors: [RankedCompetitor] {
        var byOpponent: [String: RankedCompetitor] = [:]
        for match in matchesForSelectedMetric {
            let key = match.opponent.id.uuidString
            let existing = byOpponent[key]
            let score = match.comparableTheirScore
            if existing == nil || score > (existing?.score ?? 0) {
                byOpponent[key] = RankedCompetitor(
                    id: key,
                    name: match.opponent.displayName,
                    score: score,
                    isMe: false
                )
            }
        }
        byOpponent["me"] = RankedCompetitor(id: "me", name: "You", score: myScoreForRivalList, isMe: true)
        return byOpponent.values.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                if lhs.isMe != rhs.isMe { return lhs.isMe }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.score > rhs.score
        }
    }

    private var myRankedIndex: Int? {
        rankedCompetitors.firstIndex(where: \.isMe)
    }

    private var closestBehindCompetitor: RankedCompetitor? {
        rankedCompetitors
            .dropFirst()
            .first(where: { !$0.isMe })
    }

    private var nearbyRows: [NearbyRow] {
        guard !rankedCompetitors.isEmpty, let myIndex = myRankedIndex else { return [] }
        var selected = Set<Int>([myIndex])
        if myIndex - 1 >= 0 { selected.insert(myIndex - 1) }
        if myIndex + 1 < rankedCompetitors.count { selected.insert(myIndex + 1) }
        var distance = 2
        while selected.count < min(3, rankedCompetitors.count) {
            let up = myIndex - distance
            let down = myIndex + distance
            if up >= 0 { selected.insert(up) }
            if selected.count >= min(3, rankedCompetitors.count) { break }
            if down < rankedCompetitors.count { selected.insert(down) }
            distance += 1
            if up < 0, down >= rankedCompetitors.count { break }
        }
        if myIndex >= 2 {
            selected.insert(0)
        }
        let sortedIndexes = selected.sorted()
        return sortedIndexes.map { idx in
            let person = rankedCompetitors[idx]
            return NearbyRow(
                id: person.id,
                rank: idx + 1,
                name: person.name,
                score: person.score,
                isMe: person.isMe
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .center, spacing: 12) {
                VStack(spacing: 10) {
                    if hasAnyActiveMatch {
                        Text(heroCtaLine)
                            .font(FitUpFont.body(13, weight: .semibold))
                            .foregroundStyle(FitUpColors.Text.primary)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 2)
                    }

                    ringView
                        .frame(maxWidth: .infinity, alignment: .center)

                    if hasAnyActiveMatch {
                        if let topOpponentLineText {
                            Text(topOpponentLineText)
                                .font(FitUpFont.body(11, weight: .semibold))
                                .foregroundStyle(FitUpColors.Text.secondary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 8)
                        }
                        if !displayedOpponentOrbs.isEmpty {
                            opponentOrbCard
                        }
                    } else {
                        Text("No step battle yet")
                            .font(FitUpFont.body(13, weight: .semibold))
                            .foregroundStyle(FitUpColors.Text.secondary)
                            .multilineTextAlignment(.center)
                        Text("Start a battle to compete today")
                            .font(FitUpFont.body(12, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.tertiary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 2)
        .padding(.top, -25)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.35)) {
                pulseGlow = true
            }
            startRingBreathing()
            animateHeroRing()
            startUrgentOrbPulse()
        }
        .onDisappear {
            centerCountTask?.cancel()
            centerCountTask = nil
        }
        .onChange(of: reduceMotion) { _, _ in
            startRingBreathing()
            startUrgentOrbPulse()
        }
        .onChange(of: matches.map(\.id)) { _, _ in
            animateHeroRing()
            startUrgentOrbPulse()
        }
        .onChange(of: featuredMatch?.id) { _, _ in
            animateHeroRing()
            startUrgentOrbPulse()
        }
        .onChange(of: myToday) { _, _ in
            animateHeroRing()
        }
        .onChange(of: marginVsTopOpponent) { _, _ in
            animateHeroRing()
        }
        .onChange(of: focusOpponentToday) { _, _ in
            animateHeroRing()
        }
        .onChange(of: displayedOpponentOrbs.map(\.id)) { _, _ in
            startUrgentOrbPulse()
        }
    }

    private var ringView: some View {
        ZStack {
            Circle()
                .trim(from: ringTrackStart, to: ringTrackStart + ringTrackSpan)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isBehindState ? 0.14 : 0.11),
                            Color.white.opacity(isBehindState ? 0.08 : 0.06),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 24 + (ringBreathLineWidthDelta * 1.2)
                )
                .overlay {
                    Circle()
                        .trim(from: ringTrackStart, to: ringTrackStart + ringTrackSpan)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color.white.opacity(isBehindState ? 0.18 : 0.1),
                                    Color.white.opacity(0.03),
                                    Color.white.opacity(isBehindState ? 0.14 : 0.08),
                                ],
                                center: .center
                            ),
                            lineWidth: 18 + (ringBreathLineWidthDelta * 0.7)
                        )
                        .blur(radius: isBehindState ? 0.25 : 0.15)
                }

            if !isBehindState {
                Circle()
                    .trim(from: ringTrackStart, to: ringTrimEnd(for: opponentComparableRingProgress))
                    .stroke(
                        AngularGradient(
                            colors: [
                                opponentColor.opacity(0.16),
                                opponentColor.opacity(0.7),
                                opponentColor.opacity(0.28),
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 18 + (ringBreathLineWidthDelta * 0.7), lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: opponentColor.opacity(0.28), radius: 10)
                    .opacity(hasAnyActiveMatch ? 1 : 0.32)
            }

            Circle()
                .trim(from: ringTrackStart, to: ringTrimEnd(for: primaryLapProgress))
                .stroke(
                    AngularGradient(
                        colors: isBehindState
                            ? [
                                FitUpColors.Neon.orange.opacity(0.85),
                                FitUpColors.Neon.pink.opacity(0.95),
                                FitUpColors.Neon.red.opacity(0.86),
                            ]
                            : [
                                accentColor.opacity(0.48),
                                accentColor,
                                accentGlowColor,
                            ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 24 + (ringBreathLineWidthDelta * 1.2), lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .scaleEffect(x: isBehindState ? -1 : 1, y: 1)
                .shadow(
                    color: (isBehindState ? FitUpColors.Neon.orange : accentColor)
                        .opacity(0.56),
                    radius: pulseGlow ? 18 : 10
                )
                .shadow(
                    color: (isBehindState ? FitUpColors.Neon.pink : accentGlowColor)
                        .opacity(0.38),
                    radius: pulseGlow ? 26 : 15
                )
                .overlay {
                    if isBehindState {
                        Circle()
                            .trim(from: ringTrackStart, to: ringTrimEnd(for: primaryLapProgress))
                            .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .scaleEffect(x: -1, y: 1)
                            .blur(radius: 0.2)
                    }
                }

            if overflowLapProgress > 0 {
                Circle()
                    .trim(from: ringTrackStart, to: ringTrimEnd(for: overflowLapProgress))
                    .stroke(
                        AngularGradient(
                            colors: isBehindState
                                ? [
                                    FitUpColors.Neon.red.opacity(0.86),
                                    FitUpColors.Neon.orange.opacity(0.96),
                                    FitUpColors.Neon.pink.opacity(0.9),
                                ]
                                : [
                                    FitUpColors.Neon.green.opacity(0.52),
                                    FitUpColors.Neon.cyan.opacity(0.92),
                                    FitUpColors.Neon.blue.opacity(0.84),
                                ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12 + (ringBreathLineWidthDelta * 0.7), lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(x: isBehindState ? -1 : 1, y: 1)
                    .shadow(
                        color: (isBehindState ? FitUpColors.Neon.red : FitUpColors.Neon.green)
                            .opacity(0.5),
                        radius: pulseGlow ? 12 : 8
                    )
                    .opacity(0.92)
            }

            VStack(spacing: 2) {
                Text(ringLeadStatusLabel)
                    .font(FitUpFont.body(10, weight: .heavy))
                    .tracking(1.0)
                    .foregroundStyle(FitUpColors.Text.tertiary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                Text(hasAnyActiveMatch ? formattedDelta(animatedCenterValue) : animatedCenterValue.formatted())
                    .font(FitUpFont.display(28, weight: .black))
                    .foregroundStyle(FitUpColors.Text.primary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(ringCenterUnitText)
                    .font(FitUpFont.body(11, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(FitUpColors.Text.secondary)
                if let ringOpponentTotalText {
                    Text(ringOpponentTotalText)
                        .font(FitUpFont.body(10, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.secondary.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Text(ringCenterContextText)
                    .font(FitUpFont.body(10, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.tertiary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
                    .lineLimit(2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ringCenterAccessibilityLabel)
            .accessibilityHint("Center value inside your battle ring")
        }
        .scaleEffect(ringBreathScale)
        .frame(width: 238, height: 238)
    }

    private var opponentOrbCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LIVE OPPONENTS")
                .font(FitUpFont.mono(9, weight: .bold))
                .foregroundStyle(FitUpColors.Text.tertiary)

            TimelineView(.periodic(from: .now, by: 60)) { context in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(displayedOpponentOrbs) { orb in
                            opponentOrbChip(orb, now: context.date)
                        }
                    }
                    .padding(.vertical, 1)
                    .padding(.horizontal, 1)
                }
                .scrollClipDisabled()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func opponentOrbChip(_ orb: OpponentOrb, now: Date) -> some View {
        let chipColor = opponentChipColor(for: orb.margin)
        return VStack(alignment: .center, spacing: 4) {
            HStack(spacing: 6) {
                AvatarView(initials: orb.initials, color: orb.avatarColor, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(orb.name)
                        .font(FitUpFont.body(11, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.primary)
                        .lineLimit(1)
                    Text("\(formattedDelta(orb.margin)) \(orb.marginIsBattleScore ? "Battle Score" : "steps")")
                        .font(FitUpFont.mono(13, weight: .bold))
                        .foregroundStyle(chipColor)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(chipColor.opacity(0.24))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(chipColor.opacity(0.50), lineWidth: 1.2)
                    )
            )
            .scaleEffect(orb.isUrgent && urgentOrbPulse ? 1.03 : 1)
            .opacity(orb.isUrgent && urgentOrbPulse ? 1 : 0.95)

            Group {
                if orb.marginIsBattleScore {
                    Text("\(orb.rivalActualSteps.formatted()) actual steps")
                } else {
                    Text("\(orb.rivalScoreHeadline.formatted()) total")
                }
            }
            .font(FitUpFont.mono(10, weight: .semibold))
            .foregroundStyle(FitUpColors.Text.secondary)
            .lineLimit(1)

            if let freshnessShort = opponentFreshnessShortLine(opponentUpdatedAt: orb.opponentUpdatedAt, now: now) {
                let pillTextColor = freshnessColor(opponentUpdatedAt: orb.opponentUpdatedAt, now: now)
                Text(freshnessShort)
                    .font(FitUpFont.mono(9, weight: .medium))
                    .foregroundStyle(pillTextColor.opacity(0.78))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(pillTextColor.opacity(0.12))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(pillTextColor.opacity(0.22), lineWidth: 1)
                            )
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(orb.initials), \(formattedDelta(orb.margin)) \(orb.marginIsBattleScore ? "battle score" : "steps")")
    }

    private var nearbyOpponentsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("NEARBY OPPONENTS")
                    .font(FitUpFont.mono(10, weight: .bold))
                    .fitUpGlobalTitleStyle(weight: .bold, tracking: 0.8)
                    .foregroundStyle(FitUpColors.Neon.cyan)
                Spacer(minLength: 0)
                Text("TODAY")
                    .font(FitUpFont.mono(10, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.tertiary)
            }

            if nearbyRows.isEmpty {
                Text("No rivals yet. Start a battle to populate your leaderboard.")
                    .font(FitUpFont.body(12, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
            } else {
                ForEach(Array(nearbyRows.enumerated()), id: \.element.id) { idx, row in
                    let gapAbove = idx > 0 ? max(0, nearbyRows[idx - 1].score - row.score) : nil
                    let gapBelow = idx < nearbyRows.count - 1 ? max(0, row.score - nearbyRows[idx + 1].score) : nil
                    nearbyRowView(row, gapAbove: gapAbove, gapBelow: gapBelow)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func nearbyRowView(_ row: NearbyRow, gapAbove: Int?, gapBelow: Int?) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Text("\(row.rank)")
                    .font(FitUpFont.mono(13, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.tertiary)
                    .frame(width: 22, alignment: .leading)

                Circle()
                    .fill(row.isMe ? FitUpColors.Neon.cyan : FitUpColors.Neon.purple.opacity(0.8))
                    .frame(width: 10, height: 10)

                Text(row.name)
                    .font(FitUpFont.body(14, weight: row.isMe ? .bold : .semibold))
                    .foregroundStyle(row.isMe ? FitUpColors.Text.primary : FitUpColors.Text.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if row.isMe {
                    Text("ME")
                        .font(FitUpFont.mono(11, weight: .bold))
                        .foregroundStyle(FitUpColors.Neon.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(FitUpColors.Neon.cyan.opacity(0.14))
                        )
                }

                Spacer(minLength: 0)

                Text("\(row.score.formatted())")
                    .font(FitUpFont.display(18, weight: .heavy))
                    .foregroundStyle(row.isMe ? FitUpColors.Neon.cyan : FitUpColors.Text.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            if gapAbove != nil || gapBelow != nil {
                HStack(spacing: 14) {
                    if let gapAbove {
                        nearbyGapPiece(symbol: "chevron.up", value: gapAbove, isMe: row.isMe)
                    }
                    if let gapBelow {
                        nearbyGapPiece(symbol: "chevron.down", value: gapBelow, isMe: row.isMe)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
                .fill(Color.white.opacity(row.isMe ? 0.20 : 0.10))
                .overlay {
                    if row.isMe {
                        RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
                            .fill(FitUpColors.Neon.cyan.opacity(0.06))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
                        .strokeBorder(Color.white.opacity(row.isMe ? 0.32 : 0.18), lineWidth: 1)
                )
        )
    }

    private func nearbyGapPiece(symbol: String, value: Int, isMe: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
            Text("+\(value.formatted()) \(selectedMetric.unitLabel)")
                .font(FitUpFont.mono(11, weight: .semibold))
        }
        .foregroundStyle(isMe ? FitUpColors.Text.secondary : FitUpColors.Text.tertiary)
    }

    private func marginColor(for margin: Int) -> Color {
        if margin > 0 { return FitUpColors.Neon.cyan }
        if margin < 0 { return FitUpColors.Neon.orange }
        return FitUpColors.Text.secondary
    }

    private func formattedDelta(_ delta: Int) -> String {
        if delta > 0 { return "+\(delta.formatted())" }
        if delta < 0 { return abs(delta).formatted() }
        return "0"
    }

    private var metricToggle: some View {
        EmptyView()
    }

    private func animateHeroRing() {
        animatedRingProgressTotal = 0
        withAnimation(.easeOut(duration: 0.75)) {
            animatedRingProgressTotal = totalRelativeRingProgress
        }
        animateCenterValue(to: displayedCenterTarget)
    }

    private func startRingBreathing() {
        guard !reduceMotion else {
            isBreathingExpanded = true
            return
        }

        isBreathingExpanded = false
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            isBreathingExpanded = true
        }
    }

    private func startUrgentOrbPulse() {
        guard !displayedOpponentOrbs.isEmpty else {
            urgentOrbPulse = false
            return
        }
        guard !reduceMotion else {
            urgentOrbPulse = false
            return
        }
        urgentOrbPulse = false
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            urgentOrbPulse = true
        }
    }

    private func opponentFreshnessShortLine(opponentUpdatedAt: Date?, now: Date) -> String? {
        guard let opponentUpdatedAt else { return nil }
        let elapsedSeconds = max(0, Int(now.timeIntervalSince(opponentUpdatedAt)))
        let elapsedHours = elapsedSeconds / 3600
        return "\(elapsedHours)h ago"
    }

    private func freshnessColor(opponentUpdatedAt: Date?, now: Date) -> Color {
        guard let opponentUpdatedAt else { return FitUpColors.Text.tertiary }
        let elapsedHours = max(0, now.timeIntervalSince(opponentUpdatedAt) / 3600)
        if elapsedHours <= 2 { return Color(red: 0.58, green: 0.95, blue: 0.62) }
        if elapsedHours <= 4 { return Color(red: 0.97, green: 0.84, blue: 0.46) }
        return Color(red: 1.0, green: 0.50, blue: 0.50)
    }

    private func opponentChipColor(for margin: Int) -> Color {
        if margin == 0 { return Color(red: 0.20, green: 0.70, blue: 1.0) } // tied: bright blue
        if margin < 0 { return Color(red: 0.30, green: 1.0, blue: 0.45) } // they are ahead: bright green
        if margin <= 400 { return Color(red: 1.0, green: 0.84, blue: 0.25) } // small lead: yellow
        return Color(red: 1.0, green: 0.38, blue: 0.33) // large lead: red
    }

    private func animateCenterValue(to target: Int) {
        centerCountTask?.cancel()
        let start = animatedCenterValue
        guard start != target else { return }

        let delta = abs(target - start)
        let direction = target > start ? 1 : -1
        let maxDuration: Double = 2.5
        let minDuration: Double = 1.5
        let maxTicks = 260
        let step = max(1, Int(ceil(Double(delta) / Double(maxTicks))))
        let tickCount = Int(ceil(Double(delta) / Double(step)))
        let duration = min(maxDuration, max(minDuration, Double(delta) * 0.0022))

        var weightTotal: Double = 0
        if tickCount > 0 {
            for i in 1...tickCount {
                let p = Double(i - 1) / Double(max(tickCount - 1, 1))
                let weight = 1.35 - (0.7 * sin(.pi * p))
                weightTotal += max(0.2, weight)
            }
        }

        centerCountTask = Task {
            var value = start
            guard tickCount > 0 else { return }
            for i in 1...tickCount {
                guard !Task.isCancelled else { break }
                value += direction * step
                if direction > 0 {
                    value = min(value, target)
                } else {
                    value = max(value, target)
                }
                await MainActor.run {
                    animatedCenterValue = value
                }
                let p = Double(i - 1) / Double(max(tickCount - 1, 1))
                let weight = max(0.2, 1.35 - (0.7 * sin(.pi * p)))
                let sleepSeconds = duration * (weight / max(weightTotal, 0.001))
                let sleepNs = UInt64(max(0.001, sleepSeconds) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: sleepNs)
            }
        }
    }

    private func normalizedMetric(for metricType: String) -> HeroMetric {
        metricType == "active_calories" ? .calories : .steps
    }
}

#Preview {
    VStack(spacing: 18) {
        HomeBattleHeroCard(
            matches: [
                HomeActiveMatch(
                    id: UUID(),
                    metricType: "steps",
                    durationDays: 7,
                    sportLabel: "Steps",
                    seriesLabel: "7D",
                    daysLeft: 4,
                    finalDayCutoffAt: nil,
                    finalDayScoreEndsAt: nil,
                    myToday: 4200,
                    theirToday: 3880,
                    myScore: 2,
                    theirScore: 3,
                    isWinning: true,
                    opponent: HomeOpponent(id: UUID(), displayName: "Chris", initials: "CH", colorHex: "#00AAFF"),
                    opponentTodayUpdatedAt: nil,
                    dayPips: [],
                    scoringMode: nil,
                    difficulty: nil,
                    myBaselineSteps: nil,
                    theirBaselineSteps: nil
                ),
                HomeActiveMatch(
                    id: UUID(),
                    metricType: "steps",
                    durationDays: 7,
                    sportLabel: "Steps",
                    seriesLabel: "7D",
                    daysLeft: 4,
                    finalDayCutoffAt: nil,
                    finalDayScoreEndsAt: nil,
                    myToday: 4200,
                    theirToday: 3650,
                    myScore: 2,
                    theirScore: 3,
                    isWinning: true,
                    opponent: HomeOpponent(id: UUID(), displayName: "Taylor", initials: "TA", colorHex: "#FF6200"),
                    opponentTodayUpdatedAt: nil,
                    dayPips: [],
                    scoringMode: nil,
                    difficulty: nil,
                    myBaselineSteps: nil,
                    theirBaselineSteps: nil
                ),
                HomeActiveMatch(
                    id: UUID(),
                    metricType: "steps",
                    durationDays: 7,
                    sportLabel: "Steps",
                    seriesLabel: "7D",
                    daysLeft: 4,
                    finalDayCutoffAt: nil,
                    finalDayScoreEndsAt: nil,
                    myToday: 4200,
                    theirToday: 3420,
                    myScore: 2,
                    theirScore: 3,
                    isWinning: true,
                    opponent: HomeOpponent(id: UUID(), displayName: "Jordan", initials: "JO", colorHex: "#BF5FFF"),
                    opponentTodayUpdatedAt: nil,
                    dayPips: [],
                    scoringMode: nil,
                    difficulty: nil,
                    myBaselineSteps: nil,
                    theirBaselineSteps: nil
                ),
                HomeActiveMatch(
                    id: UUID(),
                    metricType: "steps",
                    durationDays: 7,
                    sportLabel: "Steps",
                    seriesLabel: "7D",
                    daysLeft: 4,
                    finalDayCutoffAt: nil,
                    finalDayScoreEndsAt: nil,
                    myToday: 4200,
                    theirToday: 3010,
                    myScore: 2,
                    theirScore: 3,
                    isWinning: true,
                    opponent: HomeOpponent(id: UUID(), displayName: "Morgan", initials: "MO", colorHex: "#39FF14"),
                    opponentTodayUpdatedAt: nil,
                    dayPips: [],
                    scoringMode: nil,
                    difficulty: nil,
                    myBaselineSteps: nil,
                    theirBaselineSteps: nil
                )
            ]
        )

        HomeBattleHeroCard(
            matches: [
                HomeActiveMatch(
                    id: UUID(),
                    metricType: "steps",
                    durationDays: 7,
                    sportLabel: "Steps",
                    seriesLabel: "7D",
                    daysLeft: 4,
                    finalDayCutoffAt: nil,
                    finalDayScoreEndsAt: nil,
                    myToday: 2200,
                    theirToday: 3100,
                    myScore: 2,
                    theirScore: 3,
                    isWinning: false,
                    opponent: HomeOpponent(id: UUID(), displayName: "Leader", initials: "LE", colorHex: "#00AAFF"),
                    opponentTodayUpdatedAt: nil,
                    dayPips: [],
                    scoringMode: nil,
                    difficulty: nil,
                    myBaselineSteps: nil,
                    theirBaselineSteps: nil
                ),
                HomeActiveMatch(
                    id: UUID(),
                    metricType: "steps",
                    durationDays: 7,
                    sportLabel: "Steps",
                    seriesLabel: "7D",
                    daysLeft: 4,
                    finalDayCutoffAt: nil,
                    finalDayScoreEndsAt: nil,
                    myToday: 2200,
                    theirToday: 2300,
                    myScore: 2,
                    theirScore: 3,
                    isWinning: false,
                    opponent: HomeOpponent(id: UUID(), displayName: "Close1", initials: "C1", colorHex: "#FF6200"),
                    opponentTodayUpdatedAt: nil,
                    dayPips: [],
                    scoringMode: nil,
                    difficulty: nil,
                    myBaselineSteps: nil,
                    theirBaselineSteps: nil
                ),
                HomeActiveMatch(
                    id: UUID(),
                    metricType: "steps",
                    durationDays: 7,
                    sportLabel: "Steps",
                    seriesLabel: "7D",
                    daysLeft: 4,
                    finalDayCutoffAt: nil,
                    finalDayScoreEndsAt: nil,
                    myToday: 2200,
                    theirToday: 2420,
                    myScore: 2,
                    theirScore: 3,
                    isWinning: false,
                    opponent: HomeOpponent(id: UUID(), displayName: "Close2", initials: "C2", colorHex: "#BF5FFF"),
                    opponentTodayUpdatedAt: nil,
                    dayPips: [],
                    scoringMode: nil,
                    difficulty: nil,
                    myBaselineSteps: nil,
                    theirBaselineSteps: nil
                ),
                HomeActiveMatch(
                    id: UUID(),
                    metricType: "steps",
                    durationDays: 7,
                    sportLabel: "Steps",
                    seriesLabel: "7D",
                    daysLeft: 4,
                    finalDayCutoffAt: nil,
                    finalDayScoreEndsAt: nil,
                    myToday: 2200,
                    theirToday: 2800,
                    myScore: 2,
                    theirScore: 3,
                    isWinning: false,
                    opponent: HomeOpponent(id: UUID(), displayName: "Farther", initials: "FA", colorHex: "#39FF14"),
                    opponentTodayUpdatedAt: nil,
                    dayPips: [],
                    scoringMode: nil,
                    difficulty: nil,
                    myBaselineSteps: nil,
                    theirBaselineSteps: nil
                )
            ]
        )
    }
    .padding()
    .background { BackgroundGradientView() }
}
