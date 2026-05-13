//
//  HomeEnergyBeamHeroCard.swift
//  FitUp
//
//  Production Home hero using EnergyBeamHeroCore + real `HomeActiveMatch` / `Profile` data.
//

import SwiftUI

struct HomeEnergyBeamHeroCard: View {
    let match: HomeActiveMatch?
    let profile: Profile?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayMargin: Double

    /// Drives beam collision + headline/momentum during eased transitions (aligned with prototype).
    private var displayedMarginInt: Int { Int(displayMargin.rounded(.towardZero)) }

    init(match: HomeActiveMatch?, profile: Profile?) {
        self.match = match
        self.profile = profile
        _displayMargin = State(initialValue: Double(match?.comparableMargin ?? 0))
    }

    var body: some View {
        Group {
            if let match {
                EnergyBeamHeroGlassCardView(
                    margin: displayMargin,
                    referenceBattleValue: EnergyBeamHeroLayout.defaultBeamReferenceValue,
                    userName: profile?.displayName ?? "You",
                    opponentName: match.opponent.displayName,
                    userSteps: match.myToday,
                    opponentSteps: match.theirToday,
                    userBattleScore: match.myBattleScore,
                    opponentBattleScore: match.theirBattleScore,
                    battleScoreColumnTitle: "Battle Score",
                    resultEyebrow: Self.resultEyebrow(for: displayedMarginInt),
                    resultEyebrowColor: Self.resultEyebrowColor(for: displayedMarginInt),
                    resultHeroNumberText: Self.resultHeroNumberText(for: displayedMarginInt),
                    unitLabel: Self.unitLabel(for: match),
                    sparklineUserValues: EnergyBeamHeroMockSeries.cumulativeUser(wiggle: 0),
                    sparklineOpponentValues: EnergyBeamHeroMockSeries.cumulativeOpponent(wiggle: 0),
                    dayElapsedFraction: Self.dayProgressState(for: profile?.timezone).fraction,
                    dayProgressCaption: Self.dayProgressState(for: profile?.timezone).caption,
                    showMockTimelineDebugLabel: mockTimelineDebugFlag
                )
                .onAppear {
                    syncMargin(from: match, animated: false)
                }
                .onChange(of: match) { _, newMatch in
                    syncMargin(from: newMatch, animated: !reduceMotion)
                }
            } else {
                emptyHeroCard
            }
        }
    }

    private var mockTimelineDebugFlag: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    private var emptyHeroCard: some View {
        VStack(spacing: 14) {
            Text("NO ACTIVE STEP BATTLE")
                .font(FitUpFont.body(11, weight: .heavy))
                .foregroundStyle(Color.white.opacity(0.38))
                .tracking(2.4)

            Text("Start or accept a battle to see today’s matchup here.")
                .font(FitUpFont.body(14, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 18)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(FitUpColors.Bg.base.opacity(0.92))
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white.opacity(0.04))
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 14, y: 8)
    }

    private func syncMargin(from match: HomeActiveMatch, animated: Bool) {
        let target = Double(match.comparableMargin)
        guard animated else {
            displayMargin = target
            return
        }
        withAnimation(.easeInOut(duration: EnergyBeamHeroLayout.marginDrivenAnimationSeconds)) {
            displayMargin = target
        }
    }

    private static func resultEyebrow(for margin: Int) -> String {
        if margin == 0 { return "TIED" }
        if margin > 0 { return "AHEAD BY" }
        return "BEHIND BY"
    }

    private static func resultEyebrowColor(for margin: Int) -> Color {
        if margin == 0 { return FitUpColors.Text.secondary }
        if margin > 0 { return FitUpColors.Neon.cyan }
        return FitUpColors.Neon.orange.opacity(0.95)
    }

    private static func resultHeroNumberText(for margin: Int) -> String {
        if margin == 0 {
            return "0"
        }
        let nf = EnergyBeamNumberFormatting.score
        let n = nf.string(from: NSNumber(value: abs(margin))) ?? "\(abs(margin))"
        if margin > 0 {
            return "+\(n)"
        }
        return n
    }

    private static func unitLabel(for match: HomeActiveMatch) -> String {
        match.isBalancedStepsBattle ? "BATTLE SCORE" : "STEPS"
    }

    private static func dayProgressState(for timeZoneIdentifier: String?) -> (fraction: CGFloat, caption: String) {
        let tz = timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return (0, "")
        }
        let elapsed = now.timeIntervalSince(startOfDay)
        let total = max(endOfDay.timeIntervalSince(startOfDay), 1)
        let fraction = CGFloat(min(1, max(0, elapsed / total)))
        let percent = Int((Double(fraction) * 100).rounded())
        let tf = DateFormatter()
        tf.timeZone = tz
        tf.dateFormat = "h:mm a"
        let timeStr = tf.string(from: now)
        return (fraction, "\(timeStr) · \(percent)% of day elapsed")
    }
}

#if DEBUG
#Preview("Home energy beam — balanced") {
    HomeEnergyBeamHeroCard(
        match: HomeActiveMatch(
            id: UUID(),
            metricType: "steps",
            durationDays: 7,
            sportLabel: "Steps",
            seriesLabel: "7D",
            daysLeft: 4,
            finalDayCutoffAt: nil,
            finalDayScoreEndsAt: nil,
            myToday: 9_125,
            theirToday: 6_530,
            myScore: 2,
            theirScore: 3,
            isWinning: true,
            opponent: HomeOpponent(id: UUID(), displayName: "Mike", initials: "MI", colorHex: "#FF9500"),
            opponentTodayUpdatedAt: nil,
            dayPips: [],
            scoringMode: "balanced",
            difficulty: nil,
            myBaselineSteps: 8_000,
            theirBaselineSteps: 7_500
        ),
        profile: Profile(
            id: UUID(),
            authUserId: UUID(),
            displayName: "Scott",
            initials: "SC",
            avatarURL: nil,
            subscriptionTier: "free",
            timezone: "America/Los_Angeles",
            notificationsEnabled: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    )
    .padding()
    .background(FitUpColors.Bg.base)
}
#endif
