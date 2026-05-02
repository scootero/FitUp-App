//
//  HomeBattleHeroCard.swift
//  FitUp
//
//  Home hero card: "Am I beating everyone today?"
//

import SwiftUI

struct HomeBattleHeroCard: View {
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
    @Binding var selectedMetric: HeroMetric

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var animatedMyRingProgress: Double = 0
    @State private var animatedCenterValue: Int = 0
    @State private var pulseGlow = false
    @State private var isBreathingExpanded = false
    @State private var centerCountTask: Task<Void, Never>?

    private var matchesForSelectedMetric: [HomeActiveMatch] {
        matches.filter { normalizedMetric(for: $0.metricType) == selectedMetric }
    }

    private var topOpponentMatch: HomeActiveMatch? {
        matchesForSelectedMetric.max(by: { $0.theirToday < $1.theirToday })
    }

    private var closestAheadMatch: HomeActiveMatch? {
        matchesForSelectedMetric
            .filter { $0.theirToday > myScoreForRivalList }
            .min(by: { ($0.theirToday - myScoreForRivalList) < ($1.theirToday - myScoreForRivalList) })
    }

    private var closestBehindMatch: HomeActiveMatch? {
        matchesForSelectedMetric
            .filter { $0.theirToday <= myScoreForRivalList }
            .max(by: { $0.theirToday < $1.theirToday })
    }

    private var focusOpponentMatch: HomeActiveMatch? {
        closestAheadMatch ?? closestBehindMatch ?? topOpponentMatch
    }

    private var hasAnyActiveMatch: Bool {
        !matches.isEmpty
    }

    private var hasStepsMatch: Bool {
        matches.contains(where: { normalizedMetric(for: $0.metricType) == .steps })
    }

    private var hasCaloriesMatch: Bool {
        matches.contains(where: { normalizedMetric(for: $0.metricType) == .calories })
    }

    private var shouldShowMetricToggle: Bool {
        hasStepsMatch && hasCaloriesMatch
    }

    private var myToday: Int {
        matchesForSelectedMetric.map(\.myToday).max() ?? 0
    }

    private var topOpponentToday: Int {
        focusOpponentMatch?.theirToday ?? 0
    }

    private var targetOpponentName: String {
        focusOpponentMatch?.opponent.displayName ?? "Opponent"
    }

    private var isWinningState: Bool {
        guard hasAnyActiveMatch else { return false }
        return closestAheadMatch == nil
    }

    private var neededToPass: Int {
        guard hasAnyActiveMatch, let closestAheadMatch, myToday < closestAheadMatch.theirToday else { return 0 }
        return max(1, (topOpponentToday - myToday) + 1)
    }

    private var ringScaleMax: Int {
        max(1, myToday, topOpponentToday)
    }

    private var opponentComparableRingProgress: Double {
        Double(topOpponentToday) / Double(ringScaleMax)
    }

    private var marginRingProgress: Double {
        let leaderTotal = max(myToday, topOpponentToday, 1)
        let gap = abs(marginVsTopOpponent)
        return min(max(Double(gap) / Double(leaderTotal), 0), 1)
    }

    private var accentColor: Color {
        if !hasAnyActiveMatch || focusOpponentMatch == nil { return FitUpColors.Text.tertiary }
        return isWinningState ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange
    }

    private var accentGlowColor: Color {
        if !hasAnyActiveMatch || focusOpponentMatch == nil { return Color.white.opacity(0.18) }
        return isWinningState ? FitUpColors.Neon.green : FitUpColors.Neon.pink
    }

    private var opponentColor: Color {
        if focusOpponentMatch == nil { return FitUpColors.Text.tertiary }
        return isWinningState ? FitUpColors.Neon.purple : FitUpColors.Neon.blue
    }

    private var battleStatusLine: String {
        guard hasAnyActiveMatch, focusOpponentMatch != nil else {
            return "Start a battle to activate your rank climb"
        }
        if isWinningState {
            if let closest = closestBehindCompetitor {
                return "You are ahead. \(closest.name) is \((myScoreForRivalList - closest.score).formatted()) \(selectedMetric.unitLabel) behind you."
            }
            return "You are ahead of everyone."
        }
        return "You need \(neededToPass.formatted()) \(selectedMetric.unitLabel) to reach \(targetOpponentName)."
    }

    private var marginVsTopOpponent: Int {
        myToday - topOpponentToday
    }

    private var isBehindState: Bool {
        hasAnyActiveMatch && focusOpponentMatch != nil && marginVsTopOpponent < 0
    }

    private var displayedCenterTarget: Int {
        hasAnyActiveMatch ? marginVsTopOpponent : myToday
    }

    private var ringCenterUnitText: String {
        selectedMetric.unitLabel.uppercased()
    }

    private var ringCenterContextText: String {
        hasAnyActiveMatch ? "vs top rival today" : "your total today"
    }

    private var accessibilityMetricUnit: String {
        selectedMetric == .steps ? "steps" : "calories"
    }

    private var ringCenterAccessibilityLabel: String {
        if hasAnyActiveMatch {
            let direction = displayedCenterTarget >= 0 ? "Plus" : "Minus"
            return "\(direction) \(abs(displayedCenterTarget).formatted()) \(accessibilityMetricUnit) versus the top rival today"
        }
        return "\(displayedCenterTarget.formatted()) \(accessibilityMetricUnit) today"
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
        matchesForSelectedMetric.map(\.myToday).max() ?? 0
    }

    private var rankedCompetitors: [RankedCompetitor] {
        var byOpponent: [String: RankedCompetitor] = [:]
        for match in matchesForSelectedMetric {
            let key = match.opponent.id.uuidString
            let existing = byOpponent[key]
            if existing == nil || match.theirToday > (existing?.score ?? 0) {
                byOpponent[key] = RankedCompetitor(
                    id: key,
                    name: match.opponent.displayName,
                    score: match.theirToday,
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
            if shouldShowMetricToggle {
                metricToggle
                    .padding(.bottom, 14)
            }

            VStack(alignment: .center, spacing: 18) {
                ZStack {
                    heroTopBackdrop

                    VStack(spacing: 22) {
                        ringView
                            .frame(maxWidth: .infinity, alignment: .center)
                        if let focusOpponentMatch {
                            TimelineView(.periodic(from: .now, by: 60)) { context in
                                if let freshnessLine = opponentFreshnessLine(
                                    opponentUpdatedAt: focusOpponentMatch.opponentTodayUpdatedAt,
                                    now: context.date
                                ) {
                                    Text(freshnessLine)
                                        .font(FitUpFont.body(12, weight: .medium))
                                        .foregroundStyle(FitUpColors.Text.tertiary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                        Text(battleStatusLine)
                            .font(FitUpFont.body(14, weight: .semibold))
                            .foregroundStyle(FitUpColors.Text.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 26)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 2)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.35)) {
                pulseGlow = true
            }
            startRingBreathing()
            animateHeroRing()
        }
        .onDisappear {
            centerCountTask?.cancel()
            centerCountTask = nil
        }
        .onChange(of: reduceMotion) { _, _ in
            startRingBreathing()
        }
        .onChange(of: selectedMetric) { _, _ in
            animateHeroRing()
        }
        .onChange(of: matches.map(\.id)) { _, _ in
            animateHeroRing()
        }
        .onChange(of: myToday) { _, _ in
            animateHeroRing()
        }
        .onChange(of: topOpponentToday) { _, _ in
            animateHeroRing()
        }
    }

    private var ringView: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isBehindState ? 0.14 : 0.11),
                            Color.white.opacity(isBehindState ? 0.08 : 0.06),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 20 + ringBreathLineWidthDelta
                )
                .overlay {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color.white.opacity(isBehindState ? 0.18 : 0.1),
                                    Color.white.opacity(0.03),
                                    Color.white.opacity(isBehindState ? 0.14 : 0.08),
                                ],
                                center: .center
                            ),
                            lineWidth: 16 + (ringBreathLineWidthDelta * 0.6)
                        )
                        .blur(radius: isBehindState ? 0.25 : 0.15)
                }

            if !isBehindState {
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(opponentComparableRingProgress, 0), 1)))
                    .stroke(
                        AngularGradient(
                            colors: [
                                opponentColor.opacity(0.16),
                                opponentColor.opacity(0.7),
                                opponentColor.opacity(0.28),
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 16 + (ringBreathLineWidthDelta * 0.6), lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: opponentColor.opacity(0.28), radius: 10)
                    .opacity(hasAnyActiveMatch ? 1 : 0.32)
            }

            Circle()
                .trim(from: 0, to: CGFloat(animatedMyRingProgress))
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
                    style: StrokeStyle(lineWidth: 20 + ringBreathLineWidthDelta, lineCap: .round)
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
                            .trim(from: 0, to: CGFloat(animatedMyRingProgress))
                            .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .scaleEffect(x: -1, y: 1)
                            .blur(radius: 0.2)
                    }
                }

            VStack(spacing: 2) {
                Text(hasAnyActiveMatch ? formattedDelta(animatedCenterValue) : animatedCenterValue.formatted())
                    .font(FitUpFont.display(32, weight: .black))
                    .foregroundStyle(FitUpColors.Text.primary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(ringCenterUnitText)
                    .font(FitUpFont.body(12, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(FitUpColors.Text.secondary)
                Text(ringCenterContextText)
                    .font(FitUpFont.body(11, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.tertiary)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ringCenterAccessibilityLabel)
            .accessibilityHint("Center value inside your battle ring")
        }
        .scaleEffect(ringBreathScale)
        .frame(width: 194, height: 194)
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

    private func formattedDelta(_ delta: Int) -> String {
        let sign = delta >= 0 ? "+" : "-"
        return "\(sign)\(abs(delta).formatted())"
    }

    private var metricToggle: some View {
        HStack(spacing: 0) {
            ForEach(HeroMetric.allCases) { metric in
                Button {
                    selectedMetric = metric
                } label: {
                    Text(metric.label)
                        .font(FitUpFont.body(12, weight: .bold))
                        .foregroundStyle(selectedMetric == metric ? Color.black : FitUpColors.Text.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if selectedMetric == metric {
                                Capsule()
                                    .fill(FitUpColors.Neon.cyan)
                                    .shadow(color: FitUpColors.Neon.cyan.opacity(0.4), radius: 9)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }

    private func animateHeroRing() {
        animatedMyRingProgress = 0
        withAnimation(.easeOut(duration: 0.75)) {
            animatedMyRingProgress = marginRingProgress
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

    private var heroTopTexture: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            FitUpColors.Neon.cyan.opacity(0.08),
                            FitUpColors.Neon.blue.opacity(0.06),
                            Color.black.opacity(0.2),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    FitUpColors.Neon.purple.opacity(0.18),
                                    Color.clear,
                                ],
                                center: .topTrailing,
                                startRadius: 8,
                                endRadius: 150
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                )

            Circle()
                .fill(FitUpColors.Neon.cyan.opacity(0.2))
                .frame(width: 140, height: 140)
                .blur(radius: 26)
                .offset(x: -65, y: -30)

            Ellipse()
                .fill(FitUpColors.Neon.pink.opacity(0.13))
                .frame(width: 170, height: 90)
                .blur(radius: 32)
                .offset(x: 75, y: 38)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.03), Color.black.opacity(0.23)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private var heroGlassVariant: GlassCardVariant {
        guard hasAnyActiveMatch, focusOpponentMatch != nil else { return .base }
        return isWinningState ? .win : .lose
    }

    /// Nearly invisible tint (~98% transparent) over material blur + liquid-glass edge read.
    private var heroTopBackdrop: some View {
        let variant = heroGlassVariant
        let corner: CGFloat = 24

        return RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.05),
                                Color.black.opacity(0.018),
                                Color.clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.034),
                                Color.white.opacity(0.012),
                                Color.clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: backdropGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(0.028)
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.045),
                                Color.clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .mask(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white, Color.white.opacity(0.22), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.14),
                                Color.white.opacity(0.04),
                                Color.clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.55)
                    .blur(radius: 0.32)
                    .mask(
                        LinearGradient(
                            colors: [Color.white, Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.32), lineWidth: 0.65)
                    .blur(radius: 0.28)
                    .mask(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white, Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(variant.borderColor.opacity(0.5), lineWidth: 0.88)
            }
            .shadow(color: variant.shadowColor.opacity(0.32), radius: 14, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.1), radius: 9, x: 0, y: 4)
    }

    private var backdropGradientColors: [Color] {
        guard hasAnyActiveMatch, focusOpponentMatch != nil else {
            return [
                FitUpColors.Neon.blue.opacity(0.16),
                Color.black.opacity(0.38),
                Color.black.opacity(0.58),
            ]
        }
        if isWinningState {
            return [
                FitUpColors.Neon.cyan.opacity(0.24),
                FitUpColors.Neon.blue.opacity(0.22),
                Color.black.opacity(0.56),
            ]
        }
        return [
            FitUpColors.Neon.orange.opacity(0.24),
            FitUpColors.Neon.pink.opacity(0.2),
            Color.black.opacity(0.58),
        ]
    }

    private func opponentFreshnessLine(opponentUpdatedAt: Date?, now: Date) -> String? {
        guard let opponentUpdatedAt else { return nil }
        let elapsedSeconds = max(0, Int(now.timeIntervalSince(opponentUpdatedAt)))
        let elapsedMinutes = elapsedSeconds / 60
        if elapsedMinutes < 2 { return "Opponent updated just now" }
        if elapsedMinutes <= 10 { return "Opponent updated \(elapsedMinutes)m ago" }
        if elapsedMinutes < 60 { return "Opponent stale: \(elapsedMinutes)m ago" }
        return "Opponent very stale: 1h+ ago"
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
                    dayPips: []
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
                    dayPips: []
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
                    dayPips: []
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
                    dayPips: []
                ),
            ],
            selectedMetric: .constant(.steps)
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
                    dayPips: []
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
                    dayPips: []
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
                    dayPips: []
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
                    dayPips: []
                ),
            ],
            selectedMetric: .constant(.steps)
        )
    }
    .padding()
    .background { BackgroundGradientView() }
}
