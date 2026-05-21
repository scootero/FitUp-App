//
//  HomeEnergyBeamHeroCard.swift
//  FitUp
//
//  Production Home hero using EnergyBeamHeroCore + real `HomeActiveMatch` / `Profile` data.
//

import SwiftUI

/// Local-only persistence for the last hero battle snapshot the user saw (per active match).
private enum EnergyBeamHeroLastDisplayedSnapshotStore {
    private static let marginKeyPrefix = "fitup.energyBeamHero.lastDisplayedComparableMargin."
    private static let userBattleScoreKeyPrefix = "fitup.energyBeamHero.lastDisplayedUserBattleScore."
    private static let opponentBattleScoreKeyPrefix = "fitup.energyBeamHero.lastDisplayedOpponentBattleScore."

    struct Snapshot: Equatable {
        let margin: Int
        let userBattleScore: Int?
        let opponentBattleScore: Int?
    }

    private static func marginKey(for matchId: UUID) -> String { marginKeyPrefix + matchId.uuidString }
    private static func userBattleScoreKey(for matchId: UUID) -> String { userBattleScoreKeyPrefix + matchId.uuidString }
    private static func opponentBattleScoreKey(for matchId: UUID) -> String { opponentBattleScoreKeyPrefix + matchId.uuidString }

    static func load(for matchId: UUID) -> Snapshot? {
        let marginKey = marginKey(for: matchId)
        guard UserDefaults.standard.object(forKey: marginKey) != nil else { return nil }
        let userKey = userBattleScoreKey(for: matchId)
        let oppKey = opponentBattleScoreKey(for: matchId)
        return Snapshot(
            margin: UserDefaults.standard.integer(forKey: marginKey),
            userBattleScore: UserDefaults.standard.object(forKey: userKey) == nil
                ? nil
                : UserDefaults.standard.integer(forKey: userKey),
            opponentBattleScore: UserDefaults.standard.object(forKey: oppKey) == nil
                ? nil
                : UserDefaults.standard.integer(forKey: oppKey)
        )
    }

    static func save(margin: Int, userBattleScore: Int, opponentBattleScore: Int, for matchId: UUID) {
        UserDefaults.standard.set(margin, forKey: marginKey(for: matchId))
        UserDefaults.standard.set(userBattleScore, forKey: userBattleScoreKey(for: matchId))
        UserDefaults.standard.set(opponentBattleScore, forKey: opponentBattleScoreKey(for: matchId))
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
    /// DEBUG beam lab: when true, beam collision animates via `debugBeamCollisionDelta`; headline/scores stay on live path.
    var debugBeamLabEnabled: Bool = false
    /// DEBUG beam lab: added to live comparable margin for animated beam collision preview.
    var debugBeamCollisionDelta: Double = 0
    /// DEBUG: bump to replay app-open intro + score catch-up from artificially stale values.
    var debugAppOpenPreviewToken: UUID = UUID()
    /// Opens the new battle flow when the hero has no active step battle.
    var onStartBattle: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var displayMargin: Double
    @State private var displayUserBattleScore: Double
    @State private var displayOpponentBattleScore: Double
    @State private var displayBeamCollisionMargin: Double
    @State private var beamIntroStartedAt: Date?
    @State private var holdIntroGhostBeforeFirstPlay = true
    @State private var battleCountAnimation: EnergyBeamHeroBattleCountAnimation?
    @State private var battleCountFinishTask: Task<Void, Never>?
    @State private var introFinishTask: Task<Void, Never>?
    @State private var didRunInitialOpenAnimation = false

    private func restingSnapshot() -> EnergyBeamHeroAnimatedSnapshot {
        .init(
            margin: displayMargin,
            userBattleScore: displayUserBattleScore,
            opponentBattleScore: displayOpponentBattleScore,
            beamCollisionMargin: displayBeamCollisionMargin
        )
    }

    private func isBeamIntroActive(at date: Date) -> Bool {
        guard !reduceMotion else { return false }
        if holdIntroGhostBeforeFirstPlay, beamIntroStartedAt == nil { return true }
        guard let beamIntroStartedAt else { return false }
        return EnergyBeamHeroLayout.beamIntroProgress(
            at: date,
            startedAt: beamIntroStartedAt,
            holdGhostBeforeStart: false
        ) < 1
    }

    private func effectiveSnapshot(at date: Date) -> EnergyBeamHeroAnimatedSnapshot {
        if let battleCountAnimation {
            return battleCountAnimation.snapshot(at: date)
        }
        let resting = restingSnapshot()
        if isBeamIntroActive(at: date), !debugBeamLabEnabled {
            return .init(
                margin: 0,
                userBattleScore: resting.userBattleScore,
                opponentBattleScore: resting.opponentBattleScore,
                beamCollisionMargin: 0
            )
        }
        return resting
    }

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
        debugBeamLabEnabled: Bool = false,
        debugBeamCollisionDelta: Double = 0,
        debugAppOpenPreviewToken: UUID = UUID(),
        onStartBattle: (() -> Void)? = nil
    ) {
        self.match = match
        self.profile = profile
        self.sparklineUserValues = sparklineUserValues
        self.sparklineOpponentValues = sparklineOpponentValues
        self.viewerIntradayHealthKitSyncedAt = viewerIntradayHealthKitSyncedAt
        self.opponentIntradayLatestTickAt = opponentIntradayLatestTickAt
        self.debugBeamLabEnabled = debugBeamLabEnabled
        self.debugBeamCollisionDelta = debugBeamCollisionDelta
        self.debugAppOpenPreviewToken = debugAppOpenPreviewToken
        self.onStartBattle = onStartBattle
        let initialMargin: Double
        let initialUserBattleScore: Double
        let initialOpponentBattleScore: Double
        if let match {
            let live = match.comparableMargin
            if let stored = EnergyBeamHeroLastDisplayedSnapshotStore.load(for: match.id) {
                initialMargin = Double(stored.margin)
                initialUserBattleScore = Double(stored.userBattleScore ?? match.myBattleScore)
                initialOpponentBattleScore = Double(stored.opponentBattleScore ?? match.theirBattleScore)
            } else {
                initialMargin = Double(live)
                initialUserBattleScore = Double(match.myBattleScore)
                initialOpponentBattleScore = Double(match.theirBattleScore)
            }
        } else {
            initialMargin = 0
            initialUserBattleScore = 0
            initialOpponentBattleScore = 0
        }
        _displayMargin = State(initialValue: initialMargin)
        _displayUserBattleScore = State(initialValue: initialUserBattleScore)
        _displayOpponentBattleScore = State(initialValue: initialOpponentBattleScore)
        _displayBeamCollisionMargin = State(initialValue: initialMargin)
        _beamIntroStartedAt = State(initialValue: nil)
        _holdIntroGhostBeforeFirstPlay = State(initialValue: true)
    }

    private var debugBeamCollisionTarget: Double? {
        guard debugBeamLabEnabled, let match else { return nil }
        let target = Double(match.comparableMargin) + debugBeamCollisionDelta
        return min(10_000, max(-10_000, target))
    }

    var body: some View {
        Group {
            if let match {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let snapshot = effectiveSnapshot(at: timeline.date)
                    let introActive = isBeamIntroActive(at: timeline.date)
                    let marginInt = Int(snapshot.margin.rounded(.towardZero))
                    let userScoreInt = Int(snapshot.userBattleScore.rounded(.towardZero))
                    let opponentScoreInt = Int(snapshot.opponentBattleScore.rounded(.towardZero))
                    let beamCollision = debugBeamLabEnabled ? snapshot.beamCollisionMargin : snapshot.margin
                    let motionScale = introActive
                        ? EnergyBeamHeroLayout.introProceduralMotionScale
                        : (battleCountAnimation != nil
                            ? EnergyBeamHeroLayout.battleCountProceduralMotionScale
                            : 1)
                    let impactScale: CGFloat = battleCountAnimation != nil
                        ? CGFloat(EnergyBeamHeroLayout.battleCountImpactStrengthScale)
                        : 1
                    let slideActive = battleCountAnimation != nil
                    let stableBeamSeed = slideActive
                        ? Int(battleCountAnimation!.to.margin.rounded(.towardZero))
                        : nil

                    EnergyBeamHeroGlassCardView(
                        margin: snapshot.margin,
                        referenceBattleValue: EnergyBeamHeroLayout.defaultBeamReferenceValue,
                        userName: profile?.displayName ?? "You",
                        opponentName: Self.resolvedOpponentDisplayName(for: match.opponent),
                        userSteps: match.myToday,
                        opponentSteps: match.theirToday,
                        userBattleScore: userScoreInt,
                        opponentBattleScore: opponentScoreInt,
                        battleScoreColumnTitle: "Battle Score",
                        resultEyebrow: Self.resultEyebrow(for: marginInt),
                        resultEyebrowColor: Self.resultEyebrowColor(for: marginInt),
                        resultHeroNumberText: Self.resultHeroNumberText(for: marginInt),
                        unitLabel: Self.unitLabel(for: match),
                        sparklineUserValues: sparklineUserValues ?? EnergyBeamHeroMockSeries.cumulativeUser(wiggle: 0),
                        sparklineOpponentValues: sparklineOpponentValues ?? Self.neutralOpponentSparkline,
                        dayElapsedFraction: Self.dayProgressState(for: profile?.timezone).fraction,
                        dayProgressCaption: Self.dayProgressState(for: profile?.timezone).caption,
                        showMockTimelineDebugLabel: mockTimelineDebugFlag,
                        viewerIntradayHealthKitSyncedAt: viewerIntradayHealthKitSyncedAt,
                        opponentIntradayLatestTickAt: opponentIntradayLatestTickAt,
                        beamCollisionMarginPreciseOverride: debugBeamLabEnabled ? beamCollision : nil,
                        showTopBrandHeader: false,
                        beamVisualTuning: .endingProduction,
                        beamIntroStartedAt: reduceMotion ? nil : beamIntroStartedAt,
                        beamIntroHoldGhost: reduceMotion ? false : holdIntroGhostBeforeFirstPlay,
                        pinCollisionToCenterDuringIntro: introActive && !debugBeamLabEnabled,
                        proceduralMotionScale: motionScale,
                        impactStrengthScale: impactScale,
                        proceduralDrawSeed: stableBeamSeed,
                        suppressImpactBursts: slideActive
                    )
                }
                .transaction { $0.disablesAnimations = false }
                .onAppear {
                    guard !didRunInitialOpenAnimation else { return }
                    didRunInitialOpenAnimation = true
                    playSessionOpenAnimations(for: match)
                }
                .onDisappear {
                    introFinishTask?.cancel()
                    battleCountFinishTask?.cancel()
                    persistDisplayedSnapshot(for: match)
                }
                .onChange(of: scenePhase) { oldPhase, phase in
                    if phase == .inactive || phase == .background {
                        persistDisplayedSnapshot(for: match)
                    } else if phase == .active, oldPhase == .background || oldPhase == .inactive {
                        playSessionOpenAnimations(for: match)
                    }
                }
                .onChange(of: match) { oldMatch, newMatch in
                    if oldMatch.id != newMatch.id {
                        if let stored = EnergyBeamHeroLastDisplayedSnapshotStore.load(for: newMatch.id) {
                            displayMargin = Double(stored.margin)
                            displayUserBattleScore = Double(stored.userBattleScore ?? newMatch.myBattleScore)
                            displayOpponentBattleScore = Double(stored.opponentBattleScore ?? newMatch.theirBattleScore)
                            displayBeamCollisionMargin = Double(stored.margin)
                        } else {
                            displayMargin = Double(newMatch.comparableMargin)
                            displayUserBattleScore = Double(newMatch.myBattleScore)
                            displayOpponentBattleScore = Double(newMatch.theirBattleScore)
                            displayBeamCollisionMargin = Double(newMatch.comparableMargin)
                        }
                        beamIntroStartedAt = nil
                        holdIntroGhostBeforeFirstPlay = true
                    }
                    reconcileLiveBattleData(for: newMatch, animated: !reduceMotion, includeBeamIntro: false)
                }
                .onChange(of: debugBeamCollisionDelta) { _, _ in
                    reconcileDebugBeamCollision(animated: !reduceMotion)
                }
                .onChange(of: debugBeamLabEnabled) { _, enabled in
                    if enabled {
                        reconcileDebugBeamCollision(animated: !reduceMotion)
                    } else {
                        battleCountFinishTask?.cancel()
                        battleCountAnimation = nil
                        displayBeamCollisionMargin = displayMargin
                    }
                }
                #if DEBUG
                .onChange(of: debugAppOpenPreviewToken) { _, _ in
                    previewDebugAppOpen(for: match)
                }
                #endif
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

            Text("Start or accept a battle to see today’s battle here.")
                .font(FitUpFont.body(14, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            if let onStartBattle {
                Button("New Battle") {
                    onStartBattle()
                }
                .buttonStyle(.plain)
                .solidButton(color: FitUpColors.Neon.cyan)
                .padding(.top, 4)
            }
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

    private func persistDisplayedSnapshot(for match: HomeActiveMatch) {
        let snap = battleCountAnimation?.to ?? restingSnapshot()
        EnergyBeamHeroLastDisplayedSnapshotStore.save(
            margin: Int(snap.margin.rounded(.towardZero)),
            userBattleScore: Int(snap.userBattleScore.rounded(.towardZero)),
            opponentBattleScore: Int(snap.opponentBattleScore.rounded(.towardZero)),
            for: match.id
        )
    }

    private func commitRestingSnapshot(_ snapshot: EnergyBeamHeroAnimatedSnapshot) {
        displayMargin = snapshot.margin
        displayUserBattleScore = snapshot.userBattleScore
        displayOpponentBattleScore = snapshot.opponentBattleScore
        displayBeamCollisionMargin = snapshot.beamCollisionMargin
    }

    private func startBattleCountAnimation(
        from fromSnapshot: EnergyBeamHeroAnimatedSnapshot? = nil,
        to target: EnergyBeamHeroAnimatedSnapshot,
        duration: TimeInterval
    ) {
        battleCountFinishTask?.cancel()
        let from = fromSnapshot ?? battleCountAnimation?.to ?? restingSnapshot()
        let startedAt = Date()
        battleCountAnimation = .init(startedAt: startedAt, duration: duration, from: from, to: target)
        battleCountFinishTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration + 0.06))
            guard !Task.isCancelled, battleCountAnimation?.startedAt == startedAt else { return }
            commitRestingSnapshot(target)
            battleCountAnimation = nil
        }
    }

    private func startBeamIntro() {
        holdIntroGhostBeforeFirstPlay = false
        beamIntroStartedAt = Date()
    }

    private func snapToTargets(for match: HomeActiveMatch) {
        battleCountFinishTask?.cancel()
        introFinishTask?.cancel()
        battleCountAnimation = nil
        holdIntroGhostBeforeFirstPlay = false
        beamIntroStartedAt = nil
        let target = targetSnapshot(for: match)
        commitRestingSnapshot(target)
    }

    private func centeredBattleSnapshot(from base: EnergyBeamHeroAnimatedSnapshot) -> EnergyBeamHeroAnimatedSnapshot {
        .init(
            margin: 0,
            userBattleScore: base.userBattleScore,
            opponentBattleScore: base.opponentBattleScore,
            beamCollisionMargin: 0
        )
    }

    private func schedulePostIntroBattleCount(from: EnergyBeamHeroAnimatedSnapshot, to target: EnergyBeamHeroAnimatedSnapshot) {
        introFinishTask?.cancel()
        introFinishTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(EnergyBeamHeroLayout.beamIntroAnimationSeconds + 0.05))
            guard !Task.isCancelled else { return }
            let duration = EnergyBeamHeroLayout.heroBattleTransitionDuration(
                startMargin: 0,
                targetMargin: target.margin,
                startUserBattleScore: from.userBattleScore,
                targetUserBattleScore: target.userBattleScore,
                startOpponentBattleScore: from.opponentBattleScore,
                targetOpponentBattleScore: target.opponentBattleScore
            )
            startBattleCountAnimation(
                from: centeredBattleSnapshot(from: from),
                to: target,
                duration: duration
            )
        }
    }

    private func targetSnapshot(for match: HomeActiveMatch) -> EnergyBeamHeroAnimatedSnapshot {
        let margin = Double(match.comparableMargin)
        let beamCollision = debugBeamCollisionTarget.map { Double($0) } ?? margin
        return .init(
            margin: margin,
            userBattleScore: Double(match.myBattleScore),
            opponentBattleScore: Double(match.theirBattleScore),
            beamCollisionMargin: beamCollision
        )
    }

    /// App open / return to foreground: beam birth + margin/score catch-up in parallel.
    private func playSessionOpenAnimations(for match: HomeActiveMatch) {
        reconcileLiveBattleData(for: match, animated: !reduceMotion, includeBeamIntro: true)
    }

    #if DEBUG
    /// DEBUG: replay cold-open from stale margin/scores so counting + beam intro are visible on demand.
    private func previewDebugAppOpen(for match: HomeActiveMatch) {
        guard !reduceMotion else {
            reconcileLiveBattleData(for: match, animated: false, includeBeamIntro: true)
            return
        }

        let previewOffset = 150.0
        let live = targetSnapshot(for: match)
        battleCountFinishTask?.cancel()
        battleCountAnimation = nil
        commitRestingSnapshot(
            .init(
                margin: live.margin - previewOffset,
                userBattleScore: live.userBattleScore - previewOffset,
                opponentBattleScore: live.opponentBattleScore,
                beamCollisionMargin: (debugBeamLabEnabled ? live.beamCollisionMargin : live.margin) - previewOffset
            )
        )
        reconcileLiveBattleData(for: match, animated: true, includeBeamIntro: true)
    }
    #endif

    private func syncBeamCollisionToDisplayMargin(animated: Bool) {
        guard debugBeamLabEnabled else { return }
        var target = restingSnapshot()
        target.beamCollisionMargin = target.margin
        guard animated, !reduceMotion else {
            displayBeamCollisionMargin = target.beamCollisionMargin
            return
        }
        let duration = EnergyBeamHeroLayout.marginTransitionDuration(
            start: displayBeamCollisionMargin,
            target: target.beamCollisionMargin
        )
        startBattleCountAnimation(to: target, duration: duration)
    }

    private func reconcileDebugBeamCollision(animated: Bool) {
        guard debugBeamLabEnabled, let collisionTarget = debugBeamCollisionTarget else {
            syncBeamCollisionToDisplayMargin(animated: animated)
            return
        }
        var target = battleCountAnimation?.to ?? restingSnapshot()
        target.beamCollisionMargin = Double(collisionTarget)
        guard animated, !reduceMotion else {
            displayBeamCollisionMargin = target.beamCollisionMargin
            return
        }
        let duration = EnergyBeamHeroLayout.marginTransitionDuration(
            start: displayBeamCollisionMargin,
            target: target.beamCollisionMargin
        )
        startBattleCountAnimation(to: target, duration: duration)
    }

    private func reconcileLiveBattleData(for match: HomeActiveMatch, animated: Bool, includeBeamIntro: Bool) {
        let target = targetSnapshot(for: match)

        guard animated else {
            snapToTargets(for: match)
            return
        }

        let from = battleCountAnimation?.to ?? restingSnapshot()

        if includeBeamIntro {
            startBeamIntro()
            commitRestingSnapshot(centeredBattleSnapshot(from: from))
            schedulePostIntroBattleCount(from: from, to: target)
            return
        }

        let duration = EnergyBeamHeroLayout.heroBattleTransitionDuration(
            startMargin: from.margin,
            targetMargin: target.margin,
            startUserBattleScore: from.userBattleScore,
            targetUserBattleScore: target.userBattleScore,
            startOpponentBattleScore: from.opponentBattleScore,
            targetOpponentBattleScore: target.opponentBattleScore
        )
        let needsDataAnimation =
            from.margin != target.margin
            || from.userBattleScore != target.userBattleScore
            || from.opponentBattleScore != target.opponentBattleScore
            || from.beamCollisionMargin != target.beamCollisionMargin

        if needsDataAnimation {
            startBattleCountAnimation(to: target, duration: duration)
        } else if debugBeamLabEnabled {
            reconcileDebugBeamCollision(animated: true)
        } else {
            commitRestingSnapshot(target)
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
