//
//  HomeEnergyBeamHeroCard.swift
//  FitUp
//
//  Production Home hero using EnergyBeamHeroCore + real `HomeActiveMatch` / `Profile` data.
//

import SwiftUI

/// Local-only persistence for the last hero comparable margin the user saw (per active match).
private enum EnergyBeamHeroLastDisplayedMarginStore {
    private static let keyPrefix = "fitup.energyBeamHero.lastDisplayedComparableMargin."

    private static func key(for matchId: UUID) -> String {
        keyPrefix + matchId.uuidString
    }

    static func load(for matchId: UUID) -> Int? {
        let k = key(for: matchId)
        guard UserDefaults.standard.object(forKey: k) != nil else { return nil }
        return UserDefaults.standard.integer(forKey: k)
    }

    static func save(margin: Int, for matchId: UUID) {
        UserDefaults.standard.set(margin, forKey: key(for: matchId))
    }
}

struct HomeEnergyBeamHeroCard: View {
    /// Flat zeros when opponent series not loaded yet; length matches ``HomeHeroSparklineLoader.normalizedSparklinePointCount``.
    private static let neutralOpponentSparkline: [CGFloat] = Array(
        repeating: 0,
        count: HomeHeroSparklineLoader.normalizedSparklinePointCount
    )

    let match: HomeActiveMatch?
    let profile: Profile?
    /// When non-nil, replaces mock intraday sparkline for the current user (normalized 0…1 samples).
    let sparklineUserValues: [CGFloat]?
    /// When non-nil, replaces mock intraday sparkline for the opponent.
    let sparklineOpponentValues: [CGFloat]?
    /// Last successful HealthKit steps read (`HomeViewModel.heroViewerHealthKitStepsReadAt`).
    let viewerIntradayHealthKitSyncedAt: Date?
    /// Latest opponent tick `recorded_at` from sparkline fetch (`HomeViewModel.heroOpponentIntradayLatestTickAt`).
    let opponentIntradayLatestTickAt: Date?
    /// DEBUG Home beam lab: when non-nil, procedural beam uses this margin; copy and momentum use real `displayMargin`.
    let beamCollisionMarginOverride: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var displayMargin: Double

    /// Drives headline/momentum during eased transitions (aligned with prototype).
    private var displayedMarginInt: Int { Int(displayMargin.rounded(.towardZero)) }

    /// Hero column label when `displayName` is missing or whitespace (does not change navigation title in `HomeView`).
    private static func resolvedOpponentDisplayName(for opponent: HomeOpponent) -> String {
        let trimmed = opponent.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let initials = opponent.initials.trimmingCharacters(in: .whitespacesAndNewlines)
        if !initials.isEmpty { return initials }
        return "Opponent"
    }

    init(
        match: HomeActiveMatch?,
        profile: Profile?,
        sparklineUserValues: [CGFloat]? = nil,
        sparklineOpponentValues: [CGFloat]? = nil,
        viewerIntradayHealthKitSyncedAt: Date? = nil,
        opponentIntradayLatestTickAt: Date? = nil,
        beamCollisionMarginOverride: Int? = nil
    ) {
        self.match = match
        self.profile = profile
        self.sparklineUserValues = sparklineUserValues
        self.sparklineOpponentValues = sparklineOpponentValues
        self.viewerIntradayHealthKitSyncedAt = viewerIntradayHealthKitSyncedAt
        self.opponentIntradayLatestTickAt = opponentIntradayLatestTickAt
        self.beamCollisionMarginOverride = beamCollisionMarginOverride
        let initial: Double
        if let match {
            let live = match.comparableMargin
            if let stored = EnergyBeamHeroLastDisplayedMarginStore.load(for: match.id) {
                initial = Double(stored)
            } else {
                initial = Double(live)
            }
        } else {
            initial = 0
        }
        _displayMargin = State(initialValue: initial)
    }

    var body: some View {
        Group {
            if let match {
                EnergyBeamHeroGlassCardView(
                    margin: displayMargin,
                    referenceBattleValue: EnergyBeamHeroLayout.defaultBeamReferenceValue,
                    userName: profile?.displayName ?? "You",
                    opponentName: Self.resolvedOpponentDisplayName(for: match.opponent),
                    userSteps: match.myToday,
                    opponentSteps: match.theirToday,
                    userBattleScore: match.myBattleScore,
                    opponentBattleScore: match.theirBattleScore,
                    battleScoreColumnTitle: "Battle Score",
                    resultEyebrow: Self.resultEyebrow(for: displayedMarginInt),
                    resultEyebrowColor: Self.resultEyebrowColor(for: displayedMarginInt),
                    resultHeroNumberText: Self.resultHeroNumberText(for: displayedMarginInt),
                    unitLabel: Self.unitLabel(for: match),
                    sparklineUserValues: sparklineUserValues ?? EnergyBeamHeroMockSeries.cumulativeUser(wiggle: 0),
                    sparklineOpponentValues: sparklineOpponentValues ?? Self.neutralOpponentSparkline,
                    dayElapsedFraction: Self.dayProgressState(for: profile?.timezone).fraction,
                    dayProgressCaption: Self.dayProgressState(for: profile?.timezone).caption,
                    showMockTimelineDebugLabel: mockTimelineDebugFlag,
                    viewerIntradayHealthKitSyncedAt: viewerIntradayHealthKitSyncedAt,
                    opponentIntradayLatestTickAt: opponentIntradayLatestTickAt,
                    collisionMarginOverride: beamCollisionMarginOverride,
                    showTopBrandHeader: false
                )
                .onAppear {
                    reconcileToTarget(match, animated: !reduceMotion)
                }
                .onDisappear {
                    persistDisplayedMargin(for: match)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .inactive || phase == .background {
                        persistDisplayedMargin(for: match)
                    }
                }
                .onChange(of: match) { oldMatch, newMatch in
                    if oldMatch.id != newMatch.id {
                        let live = newMatch.comparableMargin
                        if let stored = EnergyBeamHeroLastDisplayedMarginStore.load(for: newMatch.id) {
                            displayMargin = Double(stored)
                        } else {
                            displayMargin = Double(live)
                        }
                    }
                    reconcileToTarget(newMatch, animated: !reduceMotion)
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
        .padding(.vertical, 40)
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

    private func persistDisplayedMargin(for match: HomeActiveMatch) {
        let value = Int(displayMargin.rounded(.towardZero))
        EnergyBeamHeroLastDisplayedMarginStore.save(margin: value, for: match.id)
    }

    private func reconcileToTarget(_ match: HomeActiveMatch, animated: Bool) {
        let target = Double(match.comparableMargin)
        guard animated else {
            displayMargin = target
            return
        }
        let start = displayMargin
        guard start != target else { return }

        let deltaI = abs(Int(target.rounded(.towardZero)) - Int(start.rounded(.towardZero)))
        if deltaI <= EnergyBeamHeroLayout.marginTransitionTinyIntDelta {
            withAnimation(
                EnergyBeamHeroLayout.marginTransitionAnimation(duration: EnergyBeamHeroLayout.marginTransitionTinySeconds)
            ) {
                displayMargin = target
            }
            return
        }

        let duration = EnergyBeamHeroLayout.marginTransitionDuration(start: start, target: target)
        withAnimation(EnergyBeamHeroLayout.marginTransitionAnimation(duration: duration)) {
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

#Preview("Home energy beam — raw behind huge margin") {
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
            myToday: 4_200,
            theirToday: 48_900,
            myScore: 0,
            theirScore: 1,
            isWinning: false,
            opponent: HomeOpponent(id: UUID(), displayName: "Jordan", initials: "JO", colorHex: "#BF5FFF"),
            opponentTodayUpdatedAt: nil,
            dayPips: [],
            scoringMode: nil,
            difficulty: nil,
            myBaselineSteps: nil,
            theirBaselineSteps: nil
        ),
        profile: Profile(
            id: UUID(),
            authUserId: UUID(),
            displayName: "Alex Verylongdisplayname",
            initials: "AL",
            avatarURL: nil,
            subscriptionTier: "free",
            timezone: "America/New_York",
            notificationsEnabled: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    )
    .padding()
    .background(FitUpColors.Bg.base)
}

#Preview("Home energy beam — balanced tie") {
    HomeEnergyBeamHeroCard(
        match: HomeActiveMatch(
            id: UUID(),
            metricType: "steps",
            durationDays: 1,
            sportLabel: "Steps",
            seriesLabel: "1D",
            daysLeft: 1,
            finalDayCutoffAt: nil,
            finalDayScoreEndsAt: nil,
            myToday: 6_000,
            theirToday: 6_000,
            myScore: 0,
            theirScore: 0,
            isWinning: true,
            opponent: HomeOpponent(id: UUID(), displayName: "Sam", initials: "SA", colorHex: "#39FF14"),
            opponentTodayUpdatedAt: nil,
            dayPips: [],
            scoringMode: "balanced",
            difficulty: nil,
            myBaselineSteps: 8_000,
            theirBaselineSteps: 8_000
        ),
        profile: Profile(
            id: UUID(),
            authUserId: UUID(),
            displayName: "You",
            initials: "YO",
            avatarURL: nil,
            subscriptionTier: "free",
            timezone: "UTC",
            notificationsEnabled: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    )
    .padding()
    .background(FitUpColors.Bg.base)
}

#Preview("Home energy beam — empty opponent name") {
    HomeEnergyBeamHeroCard(
        match: HomeActiveMatch(
            id: UUID(),
            metricType: "steps",
            durationDays: 7,
            sportLabel: "Steps",
            seriesLabel: "7D",
            daysLeft: 3,
            finalDayCutoffAt: nil,
            finalDayScoreEndsAt: nil,
            myToday: 120,
            theirToday: 80,
            myScore: 1,
            theirScore: 1,
            isWinning: true,
            opponent: HomeOpponent(id: UUID(), displayName: "   ", initials: "QZ", colorHex: "#00CED1"),
            opponentTodayUpdatedAt: nil,
            dayPips: [],
            scoringMode: nil,
            difficulty: nil,
            myBaselineSteps: nil,
            theirBaselineSteps: nil
        ),
        profile: Profile(
            id: UUID(),
            authUserId: UUID(),
            displayName: "Pat",
            initials: "PT",
            avatarURL: nil,
            subscriptionTier: "free",
            timezone: nil,
            notificationsEnabled: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    )
    .padding()
    .background(FitUpColors.Bg.base)
}
#endif
