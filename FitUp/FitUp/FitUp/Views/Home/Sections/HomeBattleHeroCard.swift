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
    @State private var pulseGlow = false

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

    private var clampedProgress: Double {
        min(max(progressRaw, 0), 1)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if shouldShowMetricToggle {
                metricToggle
                    .padding(.bottom, 14)
            }

            HStack(alignment: .center, spacing: 14) {
                ringView
                VStack(alignment: .leading, spacing: 10) {
                    Text(statusCopy)
                        .font(FitUpFont.body(13, weight: .bold))
                        .foregroundStyle(hasAnyActiveMatch ? accentColor : FitUpColors.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(targetCopy)
                        .font(FitUpFont.body(11, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if hasAnyActiveMatch, topOpponentMatch != nil {
                        HStack(spacing: 6) {
                            Text("Progress")
                                .font(FitUpFont.body(10, weight: .semibold))
                                .foregroundStyle(FitUpColors.Text.tertiary)
                                .tracking(1)
                            Text("\(Int((progressRaw * 100).rounded()))%")
                                .font(FitUpFont.mono(11, weight: .bold))
                                .foregroundStyle(accentColor)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .glassCard(cardVariant)
        .onAppear {
            pulseGlow = true
            animateHeroRing()
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
                .stroke(Color.white.opacity(0.08), lineWidth: 14)

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
                    style: StrokeStyle(lineWidth: 11, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: opponentColor.opacity(0.24), radius: 7)
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
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: accentColor.opacity(0.5), radius: pulseGlow ? 14 : 8)
                .shadow(color: accentGlowColor.opacity(0.35), radius: pulseGlow ? 22 : 12)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseGlow)

            VStack(spacing: 2) {
                Text(myToday.formatted())
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
    }

    private func normalizedMetric(for metricType: String) -> HeroMetric {
        metricType == "active_calories" ? .calories : .steps
    }
}

#Preview {
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
                myToday: 2020,
                theirToday: 2862,
                myScore: 2,
                theirScore: 3,
                isWinning: false,
                opponent: HomeOpponent(id: UUID(), displayName: "Chris", initials: "CH", colorHex: "#00AAFF"),
                dayPips: []
            )
        ],
        selectedMetric: .constant(.steps)
    )
    .padding()
    .background { BackgroundGradientView() }
}
