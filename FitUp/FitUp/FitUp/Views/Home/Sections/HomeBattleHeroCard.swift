//
//  HomeBattleHeroCard.swift
//  FitUp
//
//  Home hero card: "Am I beating everyone today?"
//

import SwiftUI

struct HomeBattleHeroCard: View {
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

    @State private var animatedMyRingProgress: Double = 0
    @State private var animatedCenterValue: Int = 0
    @State private var pulseGlow = false
    @State private var marginPulse = false
    @State private var centerCountTask: Task<Void, Never>?

    private var matchesForSelectedMetric: [HomeActiveMatch] {
        matches.filter { normalizedMetric(for: $0.metricType) == selectedMetric }
    }

    private var topOpponentMatch: HomeActiveMatch? {
        matchesForSelectedMetric.max(by: { $0.theirToday < $1.theirToday })
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
        topOpponentMatch?.myToday ?? 0
    }

    private var topOpponentToday: Int {
        topOpponentMatch?.theirToday ?? 0
    }

    private var targetOpponentName: String {
        topOpponentMatch?.opponent.displayName ?? "Opponent"
    }

    private var isWinningState: Bool {
        guard hasAnyActiveMatch, topOpponentMatch != nil else { return false }
        return myToday >= topOpponentToday
    }

    private var neededToPass: Int {
        guard hasAnyActiveMatch, let _ = topOpponentMatch, myToday < topOpponentToday else { return 0 }
        return max(1, (topOpponentToday - myToday) + 1)
    }

    private var progressRaw: Double {
        guard hasAnyActiveMatch, topOpponentMatch != nil else { return 0 }
        return Double(myToday) / Double(max(topOpponentToday, 1))
    }

    private var ringScaleMax: Int {
        max(1, myToday, topOpponentToday)
    }

    private var myComparableRingProgress: Double {
        Double(myToday) / Double(ringScaleMax)
    }

    private var opponentComparableRingProgress: Double {
        Double(topOpponentToday) / Double(ringScaleMax)
    }

    private var accentColor: Color {
        if !hasAnyActiveMatch || topOpponentMatch == nil { return FitUpColors.Text.tertiary }
        return isWinningState ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange
    }

    private var accentGlowColor: Color {
        if !hasAnyActiveMatch || topOpponentMatch == nil { return Color.white.opacity(0.18) }
        return isWinningState ? FitUpColors.Neon.green : FitUpColors.Neon.pink
    }

    private var opponentColor: Color {
        if topOpponentMatch == nil { return FitUpColors.Text.tertiary }
        return isWinningState ? FitUpColors.Neon.purple : FitUpColors.Neon.blue
    }

    private var cardVariant: GlassCardVariant {
        if !hasAnyActiveMatch || topOpponentMatch == nil { return .base }
        return isWinningState ? .win : .lose
    }

    private var statusCopy: String {
        guard hasAnyActiveMatch, topOpponentMatch != nil else {
            return "Start a battle to activate your rank climb"
        }
        if isWinningState {
            return "You're ahead of everyone today"
        }
        return "Need \(neededToPass.formatted()) more \(selectedMetric.unitLabel) to pass \(targetOpponentName)"
    }

    private var targetCopy: String {
        guard hasAnyActiveMatch, topOpponentMatch != nil else {
            return "No active battle yet"
        }
        return "Top opponent: \(targetOpponentName) · \(topOpponentToday.formatted()) \(selectedMetric.unitLabel)"
    }

    private var marginVsTopOpponent: Int {
        myToday - topOpponentToday
    }

    /// Uses max defensively in case per-match snapshots are slightly out of sync.
    private var myScoreForRivalList: Int {
        matchesForSelectedMetric.map(\.myToday).max() ?? 0
    }

    private var rivalListRows: [HomeActiveMatch] {
        guard !matchesForSelectedMetric.isEmpty else { return [] }
        if isWinningState {
            return Array(matchesForSelectedMetric.sorted(by: { $0.theirToday > $1.theirToday }).prefix(3))
        }
        guard let leader = topOpponentMatch else { return [] }
        let catchable = matchesForSelectedMetric
            .filter { $0.id != leader.id && $0.theirToday > myScoreForRivalList }
            .sorted(by: { ($0.theirToday - myScoreForRivalList) < ($1.theirToday - myScoreForRivalList) })
        return [leader] + Array(catchable.prefix(2))
    }

    private var shouldShowRivalEllipsis: Bool {
        matchesForSelectedMetric.count > 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if shouldShowMetricToggle {
                metricToggle
                    .padding(.bottom, 14)
            }

            VStack(alignment: .center, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    ringView
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 2)

                    rivalColumn
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .background {
                    heroTopTexture
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                HStack(alignment: .top, spacing: 10) {
                    heroMiniCard(
                        title: "STATUS",
                        text: statusCopy,
                        accent: hasAnyActiveMatch ? accentColor : FitUpColors.Text.secondary
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    heroMiniCard(
                        title: "RIVAL",
                        text: targetCopy,
                        accent: FitUpColors.Text.secondary
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 2)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .homeLiquidGlassCard(cardVariant)
        .onAppear {
            pulseGlow = true
            marginPulse = true
            animateHeroRing()
        }
        .onDisappear {
            centerCountTask?.cancel()
            centerCountTask = nil
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
                .stroke(Color.white.opacity(0.11), lineWidth: 17)

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
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: opponentColor.opacity(0.28), radius: 10)
                .opacity(hasAnyActiveMatch ? 1 : 0.32)

            Circle()
                .trim(from: 0, to: CGFloat(animatedMyRingProgress))
                .stroke(
                    AngularGradient(
                        colors: [
                            accentColor.opacity(0.48),
                            accentColor,
                            accentGlowColor,
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 17, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: accentColor.opacity(0.56), radius: pulseGlow ? 18 : 10)
                .shadow(color: accentGlowColor.opacity(0.38), radius: pulseGlow ? 26 : 15)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseGlow)

            VStack(spacing: 2) {
                Text(animatedCenterValue.formatted())
                    .font(FitUpFont.display(28, weight: .black))
                    .foregroundStyle(FitUpColors.Text.primary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(selectedMetric.unitLabel.uppercased())
                    .font(FitUpFont.body(10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(FitUpColors.Text.secondary)
            }
        }
        .frame(width: 160, height: 160)
        .overlay(alignment: .bottom) {
            if hasAnyActiveMatch, topOpponentMatch != nil {
                Text("TO BEAT: \(topOpponentToday.formatted())")
                    .font(FitUpFont.mono(9, weight: .bold))
                    .foregroundStyle(opponentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.28))
                            .overlay(
                                Capsule()
                                    .strokeBorder(opponentColor.opacity(0.38), lineWidth: 1)
                            )
                    )
                    .offset(y: 12)
            }
        }
    }

    private var rivalColumn: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("RIVALS")
                .font(FitUpFont.mono(9, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.blue, FitUpColors.Neon.yellow.opacity(0.92)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .tracking(0.8)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.34), lineWidth: 0.5)
                        )
                )

            if rivalListRows.isEmpty {
                Text("No rivals")
                    .font(FitUpFont.body(11, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
            } else {
                ForEach(rivalListRows) { match in
                    rivalRow(match)
                }
                if shouldShowRivalEllipsis {
                    Text("···")
                        .font(FitUpFont.mono(12, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            ringTotalsSummary
                .padding(.top, 4)
        }
    }

    private var ringTotalsSummary: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if hasAnyActiveMatch, topOpponentMatch != nil {
                Text("\(marginVsTopOpponent >= 0 ? "Ahead by" : "Behind by") \(formattedDelta(marginVsTopOpponent)) \(selectedMetric.unitLabel)")
                    .font(FitUpFont.body(10, weight: .semibold))
                    .foregroundStyle(
                        marginVsTopOpponent >= 0
                            ? LinearGradient(
                                colors: [FitUpColors.Neon.green, FitUpColors.Neon.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [FitUpColors.Neon.orange, FitUpColors.Neon.pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .shadow(
                        color: (marginVsTopOpponent >= 0 ? FitUpColors.Neon.green : FitUpColors.Neon.pink)
                            .opacity(marginPulse ? 0.5 : 0.25),
                        radius: marginPulse ? 8 : 3
                    )
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: marginPulse)
            }

            Text("You: \(myToday.formatted()) \(selectedMetric.unitLabel)")
                .font(FitUpFont.body(11, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.blue.opacity(0.95)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text("Top rival: \(targetOpponentName) · \(topOpponentToday.formatted()) \(selectedMetric.unitLabel)")
                .font(FitUpFont.body(10, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [FitUpColors.Text.secondary, FitUpColors.Neon.purple.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func rivalRow(_ match: HomeActiveMatch) -> some View {
        let delta = myScoreForRivalList - match.theirToday
        return HStack(spacing: 7) {
            Circle()
                .fill(delta >= 0 ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange)
                .frame(width: 4, height: 4)

            Text(match.opponent.displayName)
                .font(FitUpFont.body(11, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(formattedDelta(delta))
                .font(FitUpFont.mono(11, weight: .bold))
                .foregroundStyle(delta >= 0 ? FitUpColors.Neon.green : FitUpColors.Neon.pink)
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func formattedDelta(_ delta: Int) -> String {
        let sign = delta >= 0 ? "+" : "-"
        return "\(sign)\(abs(delta).formatted())"
    }

    private func heroMiniCard(title: String, text: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FitUpFont.mono(9, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.blue, FitUpColors.Neon.yellow.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .tracking(0.8)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                        )
                )
            Text(text)
                .font(FitUpFont.body(12, weight: .semibold))
                .foregroundStyle(accent)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
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
            animatedMyRingProgress = min(max(myComparableRingProgress, 0), 1)
        }
        animateCenterValue(to: myToday)
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
                    dayPips: []
                ),
            ],
            selectedMetric: .constant(.steps)
        )
    }
    .padding()
    .background { BackgroundGradientView() }
}
