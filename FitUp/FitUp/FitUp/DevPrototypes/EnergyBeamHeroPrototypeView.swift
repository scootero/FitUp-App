//
//  EnergyBeamHeroPrototypeView.swift
//  FitUp
//
//  DEBUG-only preview harness for the energy beam hero. Shared visuals: Views/Home/Sections/EnergyBeam/EnergyBeamHeroCore.swift
//

#if DEBUG

import SwiftUI

// MARK: - Tunable knobs (edit here; used throughout this file only)

/// All values this preview passes into the hero or uses for controls. **Procedural beam drawing** (lane counts, stroke widths, `wDraw`, etc.) still lives in `EnergyBeamHeroCore.swift`—change those there if you need deeper beam sculpting.
private enum EnergyBeamHeroPrototypeKnobs {

    // MARK: Beam driver (collision + “how hard margin pushes the impact sideways”)

    /// Fed into `EnergyBeamHeroGlassCardView(referenceBattleValue:)`, which flows into `normalizedBeamOffset` in the core. **Higher** = the same battle margin moves the collision **less** (beam feels stiffer / stays nearer center). **Lower** = same margin swings the collision farther left/right. Defaults to `EnergyBeamHeroLayout.defaultBeamReferenceValue`; replace with a raw `Int` here to try values without editing core. CPU: effectively unchanged.
    static let beamReferenceBattleValue: Int = EnergyBeamHeroLayout.defaultBeamReferenceValue

    /// Opening slider / state value for battle margin (same units as Home: battle-score points for balanced preview). Directly drives starting **collision X** via the core’s `tanh` mapping. CPU: unchanged.
    static let initialBattleMargin: Double = 200

    /// Slider lower bound for margin experiments (large negative = “way behind” → collision slides toward the opponent side). CPU: unchanged.
    static let marginSliderMinimum: Double = -10_000

    /// Slider upper bound for margin experiments. CPU: unchanged.
    static let marginSliderMaximum: Double = 10_000

    /// Slider step; **1** = integer margins only (stable, easy to compare). Smaller fractional steps are possible but rarely useful for this preview. CPU: unchanged.
    static let marginSliderStep: Double = 1

    // MARK: Mock battle scores (column numbers only — not Canvas geometry)

    /// Anchor for fake “Battle score” integers in the two player columns. Changing this shifts displayed scores but **does not** move the procedural beam; **margin + `beamReferenceBattleValue`** control collision. CPU: unchanged.
    static let mockMidpointBattleScore: Int = 7_234

    /// “User Ahead” preset margin (positive = you winning in this mock). CPU: unchanged.
    static let presetMarginUserAhead: Int = 2_431

    /// “Opponent Ahead” preset margin (negative = behind in this mock). CPU: unchanged.
    static let presetMarginOpponentAhead: Int = -1_120

    // MARK: Mock steps (columns only — not beam collision)

    /// Initial “You” step count in the preview card. Columns only; beam collision still follows **margin**. CPU: unchanged.
    static let initialUserSteps: Int = 9_125

    /// Initial opponent step count in the preview card. CPU: unchanged.
    static let initialOpponentSteps: Int = 6_530

    // MARK: Sparkline wiggle (mock timeline curves — not the energy beam Canvas)

    /// Starting vertical wiggle added to the mock user sparkline series. **Larger magnitude** = spikier fake day curve (slightly more path work per frame, still tiny). CPU: negligible unless extreme.
    static let initialSparklineWiggleUser: CGFloat = 0

    /// Starting wiggle for the opponent sparkline series. CPU: negligible unless extreme.
    static let initialSparklineWiggleOpponent: CGFloat = 0

    // MARK: Day-progress strip (under sparkline — not beam)

    /// 0…1 fill for the “% of day” capsule. Cosmetic only for this preview. CPU: unchanged.
    static let mockDayElapsedFraction: CGFloat = 0.62

    /// Caption under the day bar. Cosmetic. CPU: unchanged.
    static let mockDayProgressCaption: String = "3 PM · 62% of day elapsed"

    /// When `true`, the sparkline shows a small DEBUG timeline label from the core. CPU: negligible (one extra Text).
    static let showMockTimelineDebugLabel: Bool = true

    // MARK: “Simulate Health Update” random ranges

    /// Random **change** applied to battle margin on simulate (plus clamp by slider bounds). Bigger range = wilder collision jumps when testing. CPU: unchanged.
    static let simulateMarginDeltaRange: ClosedRange<Double> = -180 ... 220

    /// Random extra steps for you on simulate. Columns only. CPU: unchanged.
    static let simulateUserStepsIncreaseRange: ClosedRange<Int> = 150 ... 780

    /// Random extra steps for opponent on simulate. CPU: unchanged.
    static let simulateOpponentStepsIncreaseRange: ClosedRange<Int> = 40 ... 420

    /// Extra sparkline wiggle for user after simulate. CPU: negligible.
    static let simulateSparklineWiggleUserRange: ClosedRange<Double> = 0.04 ... 0.11

    /// Extra sparkline wiggle for opponent after simulate. CPU: negligible.
    static let simulateSparklineWiggleOpponentRange: ClosedRange<Double> = -0.09 ... 0.07

    // MARK: Preview shell layout (ScrollView / card — no beam math)

    /// Space between hero card and controls stack. CPU: unchanged.
    static let rootStackSpacing: CGFloat = 20

    /// Caps preview width on wide simulators. CPU: unchanged.
    static let rootContentMaxWidth: CGFloat = 420

    /// Outer horizontal padding for scroll content. CPU: unchanged.
    static let rootHorizontalPadding: CGFloat = 14

    /// Outer vertical padding for scroll content. CPU: unchanged.
    static let rootVerticalPadding: CGFloat = 20

    /// Controls block inner horizontal padding. CPU: unchanged.
    static let controlsOuterHorizontalPadding: CGFloat = 16

    /// Extra bottom padding under controls. CPU: unchanged.
    static let controlsOuterBottomPadding: CGFloat = 24

    /// Inner padding for the controls card. CPU: unchanged.
    static let controlsCardInnerPadding: CGFloat = 16

    /// Spacing between labeled sections in controls. CPU: unchanged.
    static let controlsSectionSpacing: CGFloat = 14

    /// Spacing inside the slider block. CPU: unchanged.
    static let controlsInnerStackSpacing: CGFloat = 10

    /// Spacing between quick preset buttons. CPU: unchanged.
    static let presetButtonRowSpacing: CGFloat = 8

    // MARK: Copy / labels (cosmetic)

    static let previewUserName: String = "Scott"
    static let previewOpponentName: String = "Mike"
    static let previewBattleScoreColumnTitle: String = "Battle Score"
    static let previewUnitLabel: String = "BATTLE SCORE"
}

/// Preview harness uses shared margin transition curve + delta-scaled duration where applicable.
private enum EnergyBeamPreviewTiming {
    static var marginDrivenAnimationSeconds: Double { EnergyBeamHeroLayout.marginDrivenAnimationSeconds }

    static func marginAnimation(from start: Double, to target: Double) -> Animation {
        let d = EnergyBeamHeroLayout.marginTransitionDuration(start: start, target: target)
        return EnergyBeamHeroLayout.marginTransitionAnimation(duration: d)
    }
}

// MARK: - Root (DEBUG hero + preview controls)

struct EnergyBeamHeroPrototypeView: View {
    @State private var margin: Double = EnergyBeamHeroPrototypeKnobs.initialBattleMargin
    @State private var userSteps = EnergyBeamHeroPrototypeKnobs.initialUserSteps
    @State private var opponentSteps = EnergyBeamHeroPrototypeKnobs.initialOpponentSteps
    @State private var chartWiggleUser: CGFloat = EnergyBeamHeroPrototypeKnobs.initialSparklineWiggleUser
    @State private var chartWiggleOpp: CGFloat = EnergyBeamHeroPrototypeKnobs.initialSparklineWiggleOpponent

    @State private var beamIntroStartedAt: Date?
    @State private var holdIntroGhost = true
    @State private var displayMargin: Double = 0
    @State private var displayUserBattleScore: Double = 0
    @State private var displayOpponentBattleScore: Double = 0
    @State private var battleCountAnimation: EnergyBeamHeroBattleCountAnimation?
    @State private var sequenceTask: Task<Void, Never>?

    private var battleMarginInt: Int { Int(displayMargin.rounded(.towardZero)) }
    private var opponentBattleScore: Int { EnergyBeamHeroPrototypeKnobs.mockMidpointBattleScore - battleMarginInt / 2 }
    private var userBattleScore: Int { opponentBattleScore + battleMarginInt }
    private var liveMargin: Double { margin }

    private var resultEyebrow: String {
        if battleMarginInt == 0 { return "TIED" }
        if battleMarginInt > 0 { return "AHEAD BY" }
        return "BEHIND BY"
    }

    private var resultEyebrowColor: Color {
        if battleMarginInt == 0 { return FitUpColors.Text.secondary }
        if battleMarginInt > 0 { return FitUpColors.Neon.cyan }
        return FitUpColors.Neon.orange.opacity(0.95)
    }

    private var resultHeroNumberText: String {
        if battleMarginInt == 0 {
            return "0"
        }
        let nf = EnergyBeamNumberFormatting.score
        let n = nf.string(from: NSNumber(value: abs(battleMarginInt))) ?? "\(abs(battleMarginInt))"
        if battleMarginInt > 0 {
            return "+\(n)"
        }
        return n
    }

    private func isIntroActive(at date: Date) -> Bool {
        if holdIntroGhost, beamIntroStartedAt == nil { return true }
        guard let beamIntroStartedAt else { return false }
        return EnergyBeamHeroLayout.beamIntroProgress(at: date, startedAt: beamIntroStartedAt, holdGhostBeforeStart: false) < 1
    }

    private func effectiveSnapshot(at date: Date) -> EnergyBeamHeroAnimatedSnapshot {
        if let battleCountAnimation {
            return battleCountAnimation.snapshot(at: date)
        }
        return .init(
            margin: displayMargin,
            userBattleScore: displayUserBattleScore,
            opponentBattleScore: displayOpponentBattleScore,
            beamCollisionMargin: displayMargin
        )
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: EnergyBeamHeroPrototypeKnobs.rootStackSpacing) {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let snap = effectiveSnapshot(at: timeline.date)
                    let introActive = isIntroActive(at: timeline.date)
                    let marginInt = Int(snap.margin.rounded(.towardZero))
                    let userScore = Int(snap.userBattleScore.rounded(.towardZero))
                    let oppScore = Int(snap.opponentBattleScore.rounded(.towardZero))
                    let motionScale = introActive
                        ? EnergyBeamHeroLayout.introProceduralMotionScale
                        : (battleCountAnimation != nil
                            ? EnergyBeamHeroLayout.battleCountProceduralMotionScale
                            : 1)
                    let slideActive = battleCountAnimation != nil
                    let impactScale: CGFloat = slideActive
                        ? CGFloat(EnergyBeamHeroLayout.battleCountImpactStrengthScale)
                        : 1
                    let stableBeamSeed = slideActive
                        ? Int(battleCountAnimation!.to.margin.rounded(.towardZero))
                        : nil

                    EnergyBeamHeroGlassCardView(
                        margin: snap.margin,
                        referenceBattleValue: EnergyBeamHeroPrototypeKnobs.beamReferenceBattleValue,
                        userName: EnergyBeamHeroPrototypeKnobs.previewUserName,
                        opponentName: EnergyBeamHeroPrototypeKnobs.previewOpponentName,
                        userSteps: userSteps,
                        opponentSteps: opponentSteps,
                        userBattleScore: userScore,
                        opponentBattleScore: oppScore,
                        battleScoreColumnTitle: EnergyBeamHeroPrototypeKnobs.previewBattleScoreColumnTitle,
                        resultEyebrow: resultEyebrow(for: marginInt),
                        resultEyebrowColor: resultEyebrowColor(for: marginInt),
                        resultHeroNumberText: resultHeroNumberText(for: marginInt),
                        unitLabel: EnergyBeamHeroPrototypeKnobs.previewUnitLabel,
                        sparklineUserValues: EnergyBeamHeroMockSeries.cumulativeUser(wiggle: chartWiggleUser),
                        sparklineOpponentValues: EnergyBeamHeroMockSeries.cumulativeOpponent(wiggle: chartWiggleOpp),
                        dayElapsedFraction: EnergyBeamHeroPrototypeKnobs.mockDayElapsedFraction,
                        dayProgressCaption: EnergyBeamHeroPrototypeKnobs.mockDayProgressCaption,
                        showMockTimelineDebugLabel: EnergyBeamHeroPrototypeKnobs.showMockTimelineDebugLabel,
                        viewerIntradayHealthKitSyncedAt: Date().addingTimeInterval(-320),
                        opponentIntradayLatestTickAt: Date().addingTimeInterval(-4_200),
                        beamVisualTuning: .endingProduction,
                        beamIntroStartedAt: beamIntroStartedAt,
                        beamIntroHoldGhost: holdIntroGhost,
                        pinCollisionToCenterDuringIntro: introActive,
                        proceduralMotionScale: motionScale,
                        impactStrengthScale: impactScale,
                        proceduralDrawSeed: stableBeamSeed,
                        suppressImpactBursts: slideActive
                    )
                }

                previewControlsSection
                    .padding(.horizontal, EnergyBeamHeroPrototypeKnobs.controlsOuterHorizontalPadding)
                    .padding(.bottom, EnergyBeamHeroPrototypeKnobs.controlsOuterBottomPadding)
            }
            .frame(maxWidth: EnergyBeamHeroPrototypeKnobs.rootContentMaxWidth)
            .padding(.horizontal, EnergyBeamHeroPrototypeKnobs.rootHorizontalPadding)
            .padding(.vertical, EnergyBeamHeroPrototypeKnobs.rootVerticalPadding)
            .frame(maxWidth: .infinity)
        }
        .background(FitUpColors.Bg.base.ignoresSafeArea())
        .onAppear {
            syncDisplayFromMargin()
        }
    }

    private func resultEyebrow(for margin: Int) -> String {
        if margin == 0 { return "TIED" }
        if margin > 0 { return "AHEAD BY" }
        return "BEHIND BY"
    }

    private func resultEyebrowColor(for margin: Int) -> Color {
        if margin == 0 { return FitUpColors.Text.secondary }
        if margin > 0 { return FitUpColors.Neon.cyan }
        return FitUpColors.Neon.orange.opacity(0.95)
    }

    private func resultHeroNumberText(for margin: Int) -> String {
        if margin == 0 { return "0" }
        let nf = EnergyBeamNumberFormatting.score
        let n = nf.string(from: NSNumber(value: abs(margin))) ?? "\(abs(margin))"
        return margin > 0 ? "+\(n)" : n
    }

    private func syncDisplayFromMargin() {
        let m = Int(margin.rounded(.towardZero))
        let opp = EnergyBeamHeroPrototypeKnobs.mockMidpointBattleScore - m / 2
        displayMargin = margin
        displayUserBattleScore = Double(opp + m)
        displayOpponentBattleScore = Double(opp)
    }

    private var previewControlsSection: some View {
        VStack(alignment: .leading, spacing: EnergyBeamHeroPrototypeKnobs.controlsSectionSpacing) {
            Text("PREVIEW CONTROLS (DEBUG)")
                .font(FitUpFont.body(11, weight: .heavy))
                .foregroundStyle(Color.white.opacity(0.35))
                .tracking(1.8)

            Text("Tune motion in EnergyBeamHeroCore: introProceduralMotionScale, lanePhaseSpeed*, wDrawIdleMultiplier, idleGlowSine*Frequency")
                .font(FitUpFont.body(10, weight: .medium))
                .foregroundStyle(FitUpColors.Text.tertiary)

            Button {
                playAppOpenSequence()
            } label: {
                Text("Preview app open (intro → slide)")
                    .font(FitUpFont.body(14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule(style: .continuous)
                            .fill(FitUpColors.Neon.cyan.opacity(0.18))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(FitUpColors.Neon.cyan.opacity(0.45), lineWidth: 1)
                            )
                    )
                    .foregroundStyle(FitUpColors.Text.primary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: EnergyBeamHeroPrototypeKnobs.controlsInnerStackSpacing) {
                HStack {
                    Text("Battle margin (\(Int(margin.rounded(.towardZero))))")
                        .font(FitUpFont.body(13, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.secondary)
                    Spacer()
                }

                Slider(
                    value: Binding(
                        get: { margin },
                        set: { newValue in
                            margin = newValue
                            animateMarginToLive(from: displayMargin, to: newValue)
                        }
                    ),
                    in: EnergyBeamHeroPrototypeKnobs.marginSliderMinimum ... EnergyBeamHeroPrototypeKnobs.marginSliderMaximum,
                    step: EnergyBeamHeroPrototypeKnobs.marginSliderStep
                )
                .tint(FitUpColors.Neon.cyan)
                .foregroundStyle(Color.white)

                HStack(spacing: EnergyBeamHeroPrototypeKnobs.presetButtonRowSpacing) {
                    controlButton(title: "Tie") {
                        snapMargin(0)
                    }
                    controlButton(title: "User Ahead") {
                        snapMargin(EnergyBeamHeroPrototypeKnobs.presetMarginUserAhead)
                    }
                    controlButton(title: "Opponent Ahead") {
                        snapMargin(EnergyBeamHeroPrototypeKnobs.presetMarginOpponentAhead)
                    }
                }

                Button {
                    simulateHealthBump()
                } label: {
                    Text("Simulate Health Update")
                        .font(FitUpFont.body(14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule(style: .continuous)
                                .fill(FitUpColors.Neon.blue.opacity(0.18))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .strokeBorder(FitUpColors.Neon.blue.opacity(0.45), lineWidth: 1)
                                )
                        )
                        .foregroundStyle(FitUpColors.Text.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(EnergyBeamHeroPrototypeKnobs.controlsCardInnerPadding)
            .background(
                RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .foregroundStyle(Color.white)
    }

    private func playAppOpenSequence() {
        sequenceTask?.cancel()
        battleCountAnimation = nil
        let target = liveMargin
        let opp = Double(EnergyBeamHeroPrototypeKnobs.mockMidpointBattleScore) - target / 2
        let from = EnergyBeamHeroAnimatedSnapshot(
            margin: target - 150,
            userBattleScore: opp + target - 150,
            opponentBattleScore: opp,
            beamCollisionMargin: target - 150
        )
        let to = EnergyBeamHeroAnimatedSnapshot(
            margin: target,
            userBattleScore: opp + target,
            opponentBattleScore: opp,
            beamCollisionMargin: target
        )
        holdIntroGhost = false
        beamIntroStartedAt = Date()
        displayMargin = 0
        displayUserBattleScore = from.userBattleScore
        displayOpponentBattleScore = from.opponentBattleScore

        sequenceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(EnergyBeamHeroLayout.beamIntroAnimationSeconds + 0.05))
            guard !Task.isCancelled else { return }
            let duration = EnergyBeamHeroLayout.heroBattleTransitionDuration(
                startMargin: 0,
                targetMargin: to.margin,
                startUserBattleScore: from.userBattleScore,
                targetUserBattleScore: to.userBattleScore,
                startOpponentBattleScore: from.opponentBattleScore,
                targetOpponentBattleScore: to.opponentBattleScore
            )
            battleCountAnimation = .init(startedAt: Date(), duration: duration, from: .init(
                margin: 0,
                userBattleScore: from.userBattleScore,
                opponentBattleScore: from.opponentBattleScore,
                beamCollisionMargin: 0
            ), to: to)
            try? await Task.sleep(for: .seconds(duration + 0.08))
            guard !Task.isCancelled else { return }
            displayMargin = to.margin
            displayUserBattleScore = to.userBattleScore
            displayOpponentBattleScore = to.opponentBattleScore
            battleCountAnimation = nil
        }
    }

    private func animateMarginToLive(from start: Double, to target: Double) {
        sequenceTask?.cancel()
        battleCountAnimation = nil
        beamIntroStartedAt = nil
        holdIntroGhost = false
        let m = Int(target.rounded(.towardZero))
        let opp = EnergyBeamHeroPrototypeKnobs.mockMidpointBattleScore - m / 2
        let to = EnergyBeamHeroAnimatedSnapshot(
            margin: target,
            userBattleScore: Double(opp + m),
            opponentBattleScore: Double(opp),
            beamCollisionMargin: target
        )
        let fromSnapshot = EnergyBeamHeroAnimatedSnapshot(
            margin: displayMargin,
            userBattleScore: displayUserBattleScore,
            opponentBattleScore: displayOpponentBattleScore,
            beamCollisionMargin: displayMargin
        )
        let duration = EnergyBeamHeroLayout.marginTransitionDuration(start: start, target: target)
        battleCountAnimation = .init(startedAt: Date(), duration: duration, from: fromSnapshot, to: to)
        sequenceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration + 0.08))
            guard !Task.isCancelled else { return }
            displayMargin = to.margin
            displayUserBattleScore = to.userBattleScore
            displayOpponentBattleScore = to.opponentBattleScore
            battleCountAnimation = nil
        }
    }

    private func snapMargin(_ m: Int) {
        let next = Double(m)
        animateMarginToLive(from: margin, to: next)
        margin = next
    }

    private func simulateHealthBump() {
        let start = margin
        var next = start + Double.random(in: EnergyBeamHeroPrototypeKnobs.simulateMarginDeltaRange)
        next = min(
            max(next, EnergyBeamHeroPrototypeKnobs.marginSliderMinimum),
            EnergyBeamHeroPrototypeKnobs.marginSliderMaximum
        )
        margin = next
        userSteps += Int.random(in: EnergyBeamHeroPrototypeKnobs.simulateUserStepsIncreaseRange)
        opponentSteps += Int.random(in: EnergyBeamHeroPrototypeKnobs.simulateOpponentStepsIncreaseRange)
        chartWiggleUser += CGFloat(Double.random(in: EnergyBeamHeroPrototypeKnobs.simulateSparklineWiggleUserRange))
        chartWiggleOpp += CGFloat(Double.random(in: EnergyBeamHeroPrototypeKnobs.simulateSparklineWiggleOpponentRange))
        animateMarginToLive(from: start, to: next)
    }

    private func controlButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(FitUpFont.body(13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.vertical, 10)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                )
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    EnergyBeamHeroPrototypeView()
}

#endif
