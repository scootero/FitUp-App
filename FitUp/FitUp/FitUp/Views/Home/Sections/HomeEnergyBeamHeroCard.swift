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

private struct HeroComparableValues: Equatable {
    let margin: Int
    let userBattleScore: Int
    let opponentBattleScore: Int
}

private enum HeroAnimContext: String {
    case coldLaunch = "cold_launch"
    case tabReturn = "tab_return"
    case foreground = "foreground"
    case matchReload = "match_reload"
    case handoff = "handoff"
    case debugPreview = "debug_preview"
    case dismount = "dismount"
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
    /// Slice 7: hide opponent + margin copy while handoff crossfade runs beam intro underneath blur.
    var handoffRevealActive: Bool = false
    /// Slice 7: bump to start app-open intro when handoff reveal begins (same path as DEBUG preview).
    var handoffIntroKickoff: UUID = UUID()
    /// Slice 7: parent keeps opponent blacked out until overlay is fully gone, then bumps this to fade in.
    var handoffOpponentRevealKickoff: UUID = UUID()
    /// When true, opponent column stays at reveal progress 0 (no flash before intentional fade-in).
    var handoffKeepOpponentBlackedOut: Bool = false
    /// Opens the new battle flow when the hero has no active step battle.
    var onStartBattle: (() -> Void)? = nil

    @State private var cardInstanceId = UUID()
    @State private var didLogCardMount = false
    private let initValueSource: String
    private let initComparableValues: HeroComparableValues

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
    @State private var keepHandoffMarginHeadlineHidden = false
    @State private var opponentRevealProgress: CGFloat

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
        handoffRevealActive: Bool = false,
        handoffIntroKickoff: UUID = UUID(),
        handoffOpponentRevealKickoff: UUID = UUID(),
        handoffKeepOpponentBlackedOut: Bool = false,
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
        self.handoffRevealActive = handoffRevealActive
        self.handoffIntroKickoff = handoffIntroKickoff
        self.handoffOpponentRevealKickoff = handoffOpponentRevealKickoff
        self.handoffKeepOpponentBlackedOut = handoffKeepOpponentBlackedOut
        self.onStartBattle = onStartBattle
        let startsWithOpponentBlackedOut = handoffRevealActive || handoffKeepOpponentBlackedOut
        let gateConsumed = HeroIntroSessionGate.hasPlayedColdOpenIntroThisSession
        let initialMargin: Double
        let initialUserBattleScore: Double
        let initialOpponentBattleScore: Double
        let valueSource: String
        if let match {
            let resolved = Self.resolvedInitialDisplayValues(for: match, gateConsumed: gateConsumed)
            initialMargin = resolved.margin
            initialUserBattleScore = resolved.userBattleScore
            initialOpponentBattleScore = resolved.opponentBattleScore
            valueSource = resolved.source
        } else {
            initialMargin = 0
            initialUserBattleScore = 0
            initialOpponentBattleScore = 0
            valueSource = "empty"
        }
        initValueSource = valueSource
        initComparableValues = HeroComparableValues(
            margin: Int(initialMargin.rounded(.towardZero)),
            userBattleScore: Int(initialUserBattleScore.rounded(.towardZero)),
            opponentBattleScore: Int(initialOpponentBattleScore.rounded(.towardZero))
        )
        _displayMargin = State(initialValue: initialMargin)
        _displayUserBattleScore = State(initialValue: initialUserBattleScore)
        _displayOpponentBattleScore = State(initialValue: initialOpponentBattleScore)
        _displayBeamCollisionMargin = State(initialValue: initialMargin)
        _beamIntroStartedAt = State(initialValue: nil)
        let shouldHoldIntroGhost = !HeroIntroSessionGate.hasPlayedColdOpenIntroThisSession && !startsWithOpponentBlackedOut
        _holdIntroGhostBeforeFirstPlay = State(initialValue: shouldHoldIntroGhost)
        _opponentRevealProgress = State(initialValue: startsWithOpponentBlackedOut ? 0 : 1)
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
                        suppressImpactBursts: slideActive,
                        opponentRevealProgress: opponentRevealProgress,
                        opponentContentSuppressed: handoffKeepOpponentBlackedOut,
                        hideMarginHeadline: keepHandoffMarginHeadlineHidden
                    )
                }
                .transaction { $0.disablesAnimations = false }
                .onChange(of: handoffRevealActive) { _, active in
                    if active {
                        resetOpponentForHandoffReveal()
                    }
                }
                .onAppear {
                    logCardMountIfNeeded(for: match)
                    if handoffRevealActive {
                        startHandoffRevealIntro(for: match)
                        return
                    }
                    guard !didRunInitialOpenAnimation else { return }
                    didRunInitialOpenAnimation = true
                    let context: HeroAnimContext = HeroIntroSessionGate.hasPlayedColdOpenIntroThisSession ? .tabReturn : .coldLaunch
                    if HeroIntroSessionGate.hasPlayedColdOpenIntroThisSession {
                        snapToTargetsFromSnapshot(for: match)
                        logHeroAnim(
                            message: "hero_intro_skipped",
                            trigger: "onAppear",
                            context: context,
                            gateAllowed: false,
                            gateReason: "session_gate",
                            match: match
                        )
                    } else {
                        playColdOpenIntro(for: match, context: context)
                    }
                }
                .onChange(of: handoffIntroKickoff) { _, _ in
                    guard handoffRevealActive else { return }
                    startHandoffRevealIntro(for: match)
                }
                .onChange(of: handoffOpponentRevealKickoff) { _, _ in
                    guard handoffRevealActive || handoffKeepOpponentBlackedOut else { return }
                    playOpponentRevealFromBlack()
                }
                .onChange(of: handoffKeepOpponentBlackedOut) { _, blackedOut in
                    if blackedOut {
                        opponentRevealProgress = 0
                    }
                }
                .onDisappear {
                    introFinishTask?.cancel()
                    battleCountFinishTask?.cancel()
                    persistDisplayedSnapshot(for: match, context: .dismount)
                }
                .onChange(of: scenePhase) { oldPhase, phase in
                    if phase == .inactive || phase == .background {
                        persistDisplayedSnapshot(for: match, context: .dismount)
                    } else if phase == .active, oldPhase == .background {
                        guard !isIntroSequenceInProgress(at: Date()) else {
                            logHeroAnim(
                                message: "hero_foreground_skipped",
                                trigger: "scenePhase",
                                context: .foreground,
                                gateReason: "intro_in_progress",
                                match: match
                            )
                            return
                        }
                        snapToTargetsFromSnapshot(for: match)
                        logHeroAnim(
                            message: "hero_foreground_snap",
                            trigger: "scenePhase",
                            context: .foreground,
                            gateAllowed: false,
                            gateReason: "session_gate",
                            match: match
                        )
                    }
                }
                .onChange(of: match) { oldMatch, newMatch in
                    if oldMatch.id != newMatch.id, !handoffRevealActive, !handoffKeepOpponentBlackedOut {
                        opponentRevealProgress = 1
                    }
                    if oldMatch.id != newMatch.id {
                        let resolved = Self.resolvedInitialDisplayValues(
                            for: newMatch,
                            gateConsumed: HeroIntroSessionGate.hasPlayedColdOpenIntroThisSession
                        )
                        displayMargin = resolved.margin
                        displayUserBattleScore = resolved.userBattleScore
                        displayOpponentBattleScore = resolved.opponentBattleScore
                        displayBeamCollisionMargin = resolved.margin
                        beamIntroStartedAt = nil
                        holdIntroGhostBeforeFirstPlay = !HeroIntroSessionGate.hasPlayedColdOpenIntroThisSession
                    }
                    if isIntroSequenceInProgress(at: Date()) {
                        logHeroAnim(
                            message: "hero_intro_skipped",
                            trigger: "onChange_match",
                            context: .matchReload,
                            gateReason: "intro_in_progress",
                            match: newMatch
                        )
                        return
                    }
                    reconcileLiveDataDeltaIfNeeded(for: newMatch)
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

    private func persistDisplayedSnapshot(for match: HomeActiveMatch, context: HeroAnimContext) {
        let decision = persistSnapshotDecision(for: match)
        guard decision.allowed else {
            logHeroAnim(
                message: "hero_snapshot_persist_skipped",
                trigger: "persistDisplayedSnapshot",
                context: context,
                gateReason: decision.reason,
                match: match
            )
            return
        }
        let snap = battleCountAnimation?.to ?? restingSnapshot()
        EnergyBeamHeroLastDisplayedSnapshotStore.save(
            margin: Int(snap.margin.rounded(.towardZero)),
            userBattleScore: Int(snap.userBattleScore.rounded(.towardZero)),
            opponentBattleScore: Int(snap.opponentBattleScore.rounded(.towardZero)),
            for: match.id
        )
        logHeroAnim(
            message: "hero_snapshot_persisted",
            trigger: "persistDisplayedSnapshot",
            context: context,
            from: snap,
            match: match,
            extra: ["margin": "\(Int(snap.margin.rounded(.towardZero)))"]
        )
    }

    private func persistSnapshotDecision(for match: HomeActiveMatch) -> (allowed: Bool, reason: String) {
        let now = Date()
        if isIntroSequenceInProgress(at: now) {
            return (false, "intro_in_progress")
        }
        if holdIntroGhostBeforeFirstPlay, beamIntroStartedAt == nil {
            return (false, "intro_ghost_hold")
        }
        let snap = battleCountAnimation?.to ?? restingSnapshot()
        let marginInt = Int(snap.margin.rounded(.towardZero))
        if marginInt == 0, match.comparableMargin != 0 {
            return (false, "stale_zero_margin")
        }
        return (true, "ok")
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
        duration: TimeInterval,
        trigger: String,
        context: HeroAnimContext
    ) {
        battleCountFinishTask?.cancel()
        let from = fromSnapshot ?? battleCountAnimation?.to ?? restingSnapshot()
        let startedAt = Date()
        battleCountAnimation = .init(startedAt: startedAt, duration: duration, from: from, to: target)
        logHeroAnim(
            message: "hero_battle_count_start",
            trigger: trigger,
            context: context,
            gateAllowed: false,
            gateReason: "battle_count_not_gated",
            from: from,
            to: target,
            match: match,
            extra: ["duration_s": String(format: "%.2f", duration)]
        )
        battleCountFinishTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration + 0.06))
            guard !Task.isCancelled, battleCountAnimation?.startedAt == startedAt else { return }
            commitRestingSnapshot(target)
            battleCountAnimation = nil
        }
    }

    private func startBeamIntro(trigger: String, context: HeroAnimContext) {
        holdIntroGhostBeforeFirstPlay = false
        beamIntroStartedAt = Date()
        logHeroAnim(
            message: "hero_beam_intro_start",
            trigger: trigger,
            context: context,
            gateAllowed: true,
            gateReason: "beam_intro",
            match: match
        )
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

    private func schedulePostIntroBattleCount(
        from: EnergyBeamHeroAnimatedSnapshot,
        to target: EnergyBeamHeroAnimatedSnapshot,
        context: HeroAnimContext
    ) {
        introFinishTask?.cancel()
        introFinishTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(EnergyBeamHeroLayout.beamIntroAnimationSeconds + 0.05))
            guard !Task.isCancelled else { return }
            keepHandoffMarginHeadlineHidden = false
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
                duration: duration,
                trigger: "schedulePostIntroBattleCount",
                context: context
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

    private func heroDisplayComparableValues() -> HeroComparableValues {
        HeroComparableValues(
            margin: Int(displayMargin.rounded(.towardZero)),
            userBattleScore: Int(displayUserBattleScore.rounded(.towardZero)),
            opponentBattleScore: Int(displayOpponentBattleScore.rounded(.towardZero))
        )
    }

    private func incomingComparableValues(for match: HomeActiveMatch) -> HeroComparableValues {
        HeroComparableValues(
            margin: match.comparableMargin,
            userBattleScore: match.myBattleScore,
            opponentBattleScore: match.theirBattleScore
        )
    }

    private func isIntroSequenceInProgress(at date: Date) -> Bool {
        if introFinishTask != nil { return true }
        guard !reduceMotion else { return false }
        return isBeamIntroActive(at: date)
    }

    private func snapToTargetsFromSnapshot(for match: HomeActiveMatch) {
        holdIntroGhostBeforeFirstPlay = false
        snapToTargets(for: match)
    }

    private func reconcileLiveDataDeltaIfNeeded(for match: HomeActiveMatch) {
        let incoming = incomingComparableValues(for: match)
        let displayed = heroDisplayComparableValues()
        guard incoming != displayed else {
            logHeroAnim(
                message: "hero_battle_count_skipped",
                trigger: "reconcileLiveDataDeltaIfNeeded",
                context: .matchReload,
                gateReason: "unchanged_values",
                match: match,
                extra: [
                    "display_margin": "\(displayed.margin)",
                    "incoming_margin": "\(incoming.margin)",
                ]
            )
            return
        }
        reconcileLiveBattleData(
            for: match,
            animated: !reduceMotion,
            includeBeamIntro: false,
            trigger: "reconcileLiveDataDeltaIfNeeded",
            context: .matchReload
        )
    }

    private func playColdOpenIntro(for match: HomeActiveMatch, context: HeroAnimContext) {
        introFinishTask?.cancel()
        battleCountFinishTask?.cancel()
        battleCountAnimation = nil
        guard HeroIntroSessionGate.tryConsumeColdOpenIntro() else {
            snapToTargetsFromSnapshot(for: match)
            logHeroAnim(
                message: "hero_intro_skipped",
                trigger: "playColdOpenIntro",
                context: context,
                gateAllowed: false,
                gateReason: "session_gate_race",
                match: match
            )
            return
        }
        reconcileLiveBattleData(
            for: match,
            animated: !reduceMotion,
            includeBeamIntro: true,
            trigger: "playColdOpenIntro",
            context: context
        )
        logHeroAnim(
            message: "hero_intro_played",
            trigger: "playColdOpenIntro",
            context: context,
            gateAllowed: true,
            gateReason: "consumed",
            match: match
        )
    }

    private func playHandoffIntroAnimation(for match: HomeActiveMatch) {
        introFinishTask?.cancel()
        battleCountFinishTask?.cancel()
        battleCountAnimation = nil
        logHeroAnim(
            message: "hero_handoff_intro_start",
            trigger: "playHandoffIntroAnimation",
            context: .handoff,
            gateAllowed: false,
            gateReason: "handoff_not_gated",
            match: match
        )
        reconcileLiveBattleData(
            for: match,
            animated: !reduceMotion,
            includeBeamIntro: true,
            trigger: "playHandoffIntroAnimation",
            context: .handoff
        )
    }

    private func logCardMountIfNeeded(for match: HomeActiveMatch) {
        guard !didLogCardMount else { return }
        didLogCardMount = true
        let context: HeroAnimContext = HeroIntroSessionGate.hasPlayedColdOpenIntroThisSession ? .tabReturn : .coldLaunch
        logHeroAnim(
            message: "hero_card_mount",
            trigger: "onAppear",
            context: context,
            gateAllowed: !HeroIntroSessionGate.hasPlayedColdOpenIntroThisSession,
            gateReason: HeroIntroSessionGate.hasPlayedColdOpenIntroThisSession ? "session_gate" : "cold_open_pending",
            match: match,
            extra: [
                "init_source": initValueSource,
                "init_margin": "\(initComparableValues.margin)",
                "init_user": "\(initComparableValues.userBattleScore)",
                "init_opp": "\(initComparableValues.opponentBattleScore)",
                "hold_ghost_init": holdIntroGhostBeforeFirstPlay ? "true" : "false",
            ]
        )
    }

    private func logHeroAnim(
        message: String,
        trigger: String,
        context: HeroAnimContext? = nil,
        gateAllowed: Bool? = nil,
        gateReason: String? = nil,
        from: EnergyBeamHeroAnimatedSnapshot? = nil,
        to: EnergyBeamHeroAnimatedSnapshot? = nil,
        match: HomeActiveMatch? = nil,
        extra: [String: String] = [:]
    ) {
        var metadata = extra
        metadata["instance_id"] = cardInstanceId.uuidString
        metadata["trigger"] = trigger
        if let context {
            metadata["context"] = context.rawValue
        }
        if let gateAllowed {
            metadata["gate_allowed"] = gateAllowed ? "true" : "false"
        }
        if let gateReason {
            metadata["gate_reason"] = gateReason
        }
        metadata["hold_ghost"] = holdIntroGhostBeforeFirstPlay ? "true" : "false"
        metadata["intro_active"] = isBeamIntroActive(at: Date()) ? "true" : "false"
        if let match {
            metadata["match_id"] = match.id.uuidString
            metadata["live_margin"] = "\(match.comparableMargin)"
        }
        if let from {
            metadata["from_margin"] = "\(Int(from.margin.rounded(.towardZero)))"
            metadata["from_user"] = "\(Int(from.userBattleScore.rounded(.towardZero)))"
            metadata["from_opp"] = "\(Int(from.opponentBattleScore.rounded(.towardZero)))"
        }
        if let to {
            metadata["to_margin"] = "\(Int(to.margin.rounded(.towardZero)))"
            metadata["to_user"] = "\(Int(to.userBattleScore.rounded(.towardZero)))"
            metadata["to_opp"] = "\(Int(to.opponentBattleScore.rounded(.towardZero)))"
        }
        AppLogger.log(
            category: "hero_anim",
            level: .info,
            message: message,
            userId: profile?.id,
            metadata: metadata
        )
    }

    private static func resolvedInitialDisplayValues(
        for match: HomeActiveMatch,
        gateConsumed: Bool
    ) -> (margin: Double, userBattleScore: Double, opponentBattleScore: Double, source: String) {
        let liveMargin = Double(match.comparableMargin)
        let liveUser = Double(match.myBattleScore)
        let liveOpp = Double(match.theirBattleScore)

        if gateConsumed {
            return (liveMargin, liveUser, liveOpp, "live_gate_consumed")
        }

        if let stored = EnergyBeamHeroLastDisplayedSnapshotStore.load(for: match.id) {
            let margin = Double(stored.margin)
            let user = Double(stored.userBattleScore ?? match.myBattleScore)
            let opp = Double(stored.opponentBattleScore ?? match.theirBattleScore)
            if margin == 0, match.comparableMargin != 0 {
                return (liveMargin, liveUser, liveOpp, "live_stale_zero_margin")
            }
            return (margin, user, opp, "user_defaults")
        }

        return (liveMargin, liveUser, liveOpp, "live")
    }

    private func resetOpponentForHandoffReveal() {
        opponentRevealProgress = 0
        keepHandoffMarginHeadlineHidden = true
    }

    /// Runs after the handoff overlay is fully gone — parent clears suppression first, then fade from black.
    private func playOpponentRevealFromBlack() {
        opponentRevealProgress = 0
        let duration = reduceMotion ? 0.2 : 1.05
        withAnimation(.easeIn(duration: duration)) {
            opponentRevealProgress = 1
        }
    }

    /// Slice 7 — beam intro under blur; opponent stays blacked until `playOpponentRevealFromBlack`.
    private func startHandoffRevealIntro(for match: HomeActiveMatch) {
        didRunInitialOpenAnimation = true
        resetOpponentForHandoffReveal()
        let resolved = Self.resolvedInitialDisplayValues(for: match, gateConsumed: false)
        displayMargin = resolved.margin
        displayUserBattleScore = resolved.userBattleScore
        displayOpponentBattleScore = resolved.opponentBattleScore
        displayBeamCollisionMargin = resolved.margin
        beamIntroStartedAt = nil
        holdIntroGhostBeforeFirstPlay = true
        playHandoffIntroAnimation(for: match)
    }

    #if DEBUG
    /// DEBUG: replay cold-open from stale margin/scores so counting + beam intro are visible on demand.
    private func previewDebugAppOpen(for match: HomeActiveMatch) {
        guard !reduceMotion else {
            reconcileLiveBattleData(
                for: match,
                animated: false,
                includeBeamIntro: true,
                trigger: "previewDebugAppOpen",
                context: .debugPreview
            )
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
        logHeroAnim(
            message: "hero_debug_preview_start",
            trigger: "previewDebugAppOpen",
            context: .debugPreview,
            gateAllowed: false,
            gateReason: "debug_not_gated",
            match: match
        )
        reconcileLiveBattleData(
            for: match,
            animated: true,
            includeBeamIntro: true,
            trigger: "previewDebugAppOpen",
            context: .debugPreview
        )
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
        startBattleCountAnimation(
            to: target,
            duration: duration,
            trigger: "syncBeamCollisionToDisplayMargin",
            context: .matchReload
        )
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
        startBattleCountAnimation(
            to: target,
            duration: duration,
            trigger: "reconcileDebugBeamCollision",
            context: .matchReload
        )
    }

    private func reconcileLiveBattleData(
        for match: HomeActiveMatch,
        animated: Bool,
        includeBeamIntro: Bool,
        trigger: String,
        context: HeroAnimContext
    ) {
        let target = targetSnapshot(for: match)

        guard animated else {
            snapToTargets(for: match)
            return
        }

        let from = battleCountAnimation?.to ?? restingSnapshot()

        if includeBeamIntro {
            introFinishTask?.cancel()
            battleCountFinishTask?.cancel()
            startBeamIntro(trigger: trigger, context: context)
            commitRestingSnapshot(centeredBattleSnapshot(from: from))
            schedulePostIntroBattleCount(from: from, to: target, context: context)
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
            startBattleCountAnimation(
                to: target,
                duration: duration,
                trigger: trigger,
                context: context
            )
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
