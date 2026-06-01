//
//  EnergyBeamHeroCore.swift
//  FitUp
//
//  Always-compiled energy beam hero visuals (beam, sparkline, momentum, glass chrome).
//  DEBUG playgrounds: DevPrototypes/EnergyBeamHeroPrototypeView.swift, DevPrototypes/HomeEnergyBeamDebugLab.swift
//

import SwiftUI

// MARK: - Beam visual tuning (all procedural-beam knobs; interpolate between presets for intro animations)

/// Single bundle of every parameter the procedural energy beam reads while drawing (margin → collision is still driven separately by `referenceBattleValue` on the glass card). **Tip:** tween from `beginningIntro` → `endingProduction` in lockstep for app-open transitions.
struct EnergyBeamVisualTuning: Equatable, Sendable {
    /// Short name for logs / previews.
    let label: String

    // MARK: Timeline / cost
    /// **Smaller** ⇒ more `TimelineView` ticks per second (smoother motion, more CPU).
    let timelineInterval: TimeInterval
    /// Main lightning lanes per side; **more** ⇒ denser beam, higher GPU.
    let lanesPerSide: Int
    /// Collision sparkle stroke count; **more** ⇒ busier impact, higher GPU.
    let sparkCount: Int
    /// Minimum tendril polyline segments per lane; raise with `tendrilSegmentMax` for smoother curves (costlier).
    let tendrilSegmentMin: Int
    /// Maximum tendril segments per lane (must be ≥ `tendrilSegmentMin`).
    let tendrilSegmentMax: Int
    /// Random lanes above this (0…1) spawn fork branches; **higher** ⇒ fewer forks, calmer, slightly cheaper.
    let forkProbabilityThreshold: CGFloat
    /// Fast horizontal flow streaks per side; **more** ⇒ busier ribbons, higher GPU.
    let flowStreakCount: Int
    /// Traveling “packet” sprites per side; **more** ⇒ more motion, higher GPU.
    let flowPacketCount: Int
    /// Base reflected fragment polylines per side (still scaled by impact); **more** ⇒ richer bounce-off, higher GPU.
    let reflectFragmentCount: Int

    // MARK: Layout strip
    /// Total SwiftUI height of the beam strip.
    let beamOuterHeight: CGFloat

    // MARK: Margin → collision X (`normalizedBeamOffset`)
    /// Floor for reference value inside offset math; **higher** ⇒ slightly less extreme offsets at tiny references.
    let referenceFloor: Double
    /// Multiplier inside `scale = max(reference * mul, minimum)`; **higher** ⇒ same margin moves collision **less**.
    let referenceScaleMultiplier: Double
    /// Floor for that scale term; **higher** ⇒ dampens sensitivity when reference is small.
    let referenceScaleMinimum: Double
    /// Max horizontal fraction of card width the collision can shift from center; **lower** ⇒ stays nearer middle.
    let marginMaxHorizontalFraction: CGFloat

    // MARK: Collision clamp (fractions of card width)
    /// Left clamp for collision X as a fraction of width; **raise** toward `0.5` to pin impact toward center-right of left half.
    let collisionClampMinFraction: CGFloat
    /// Right clamp; **lower** toward `0.5` to pin impact toward center.
    let collisionClampMaxFraction: CGFloat

    // MARK: Wall-clock scroll (`wDraw`)
    /// Idle multiplier on `wall` for texture advection; **higher** ⇒ faster drift along lanes without an impact pulse.
    let wDrawIdleMultiplier: Double
    /// Extra multiplier added when `impact` is active; **higher** ⇒ bigger speed burst on margin integer changes.
    let wDrawImpactExtra: Double

    // MARK: Impact pulse (when integer margin ticks)
    /// Seconds the impact flash stays non-zero; **longer** ⇒ longer collision read.
    let impactBoostWindowSeconds: CGFloat
    /// Sharpness of the decay curve; **higher** ⇒ snappier spike, shorter-feeling peak.
    let impactBoostPeakExponent: Double
    /// Shimmer strength on top of peak; **higher** ⇒ more oscillation during the pulse.
    let impactBoostShimmerAmplitude: Double
    /// Shimmer frequency during pulse; **higher** ⇒ faster flicker.
    let impactBoostShimmerFrequency: Double

    // MARK: Horizontal band for tendrils (fractions of width, or absolute pads)
    /// When `true`, `leftPad` / `rightPad` use `horizontalBand*` fractions of `w`; when `false`, use absolute leading/trailing offsets below.
    let useProportionalHorizontalPads: Bool
    /// Left edge of drawable band as fraction of `w` when proportional pads are on; **raise** toward center to squeeze energy inward.
    let horizontalBandLeftEdgeFraction: CGFloat
    /// Right edge of drawable band as fraction of `w` when proportional; **lower** toward center to squeeze inward.
    let horizontalBandRightEdgeFraction: CGFloat
    /// When not proportional: tendril start X is this offset from the view’s leading edge (often negative to start off-card).
    let leftPadLeadingOffset: CGFloat
    /// When not proportional: right tendril end is `width + this`.
    let rightPadTrailingExtra: CGFloat

    // MARK: Global visual gain
    /// Multiplies the raw `impact` scalar inside `drawBeam` (0…1 clamped after multiply); **lower** ⇒ weaker flashes, calmer collision read.
    let impactVisualScale: CGFloat
    /// Multiplies every opacity fed into `layeredTendrilStrokes`; **lower** ⇒ ghostier beam.
    let masterStrokeOpacity: CGFloat

    // MARK: drawBeam intensity scaffolding
    /// Scales how much `impact` brightens the whole pass (`globalBright`).
    let globalBrightImpactCoefficient: CGFloat
    /// Base offset inside flare multiplier before impact term.
    let flareMulBase: CGFloat
    /// How strongly `impact` grows flare length / hotness.
    let flareMulImpactCoefficient: CGFloat
    /// Base burst width scale before impact.
    let burstScaleBase: CGFloat
    /// How much `impact` widens bursts.
    let burstScaleImpactCoefficient: CGFloat
    /// Flow-streak speed helper base.
    let flowMulBase: CGFloat
    /// Flow-streak speed helper impact term.
    let flowMulImpactCoefficient: CGFloat

    // MARK: Idle shimmer (`idleGlowFactor`)
    /// Baseline brightness before sine waves; **lower** ⇒ dimmer idle beam.
    let idleGlowBase: CGFloat
    let idleGlowSeedStride: Double
    let idleGlowSineAFrequency: Double
    let idleGlowSineAAmplitude: CGFloat
    let idleGlowSineBFrequency: Double
    let idleGlowSineBAmplitude: CGFloat
    let idleGlowSineCFrequency: Double
    let idleGlowSineCAmplitude: CGFloat
    let idleGlowSteppedMultiplier: CGFloat
    let idleGlowSteppedWallFrequency: Double

    // MARK: Lane motion (`lanePhase`)
    let lanePhaseSpeedMin: Double
    let lanePhaseSpeedSpan: Double
    let lanePhaseLaneWeight: Double
    let lanePhaseSeedWeight: Double

    // MARK: Amplitude envelope (`amplitudeEnvelope`)
    let amplitudeCalmBase: CGFloat
    let amplitudeCalmSpan: CGFloat
    let amplitudeBurstBase: CGFloat
    let amplitudeBurstWobble: CGFloat
    let amplitudeChaosBase: CGFloat
    let amplitudeChaosSpan: CGFloat

    // MARK: Secondary passes (counts)
    let helixRunnerCount: Int
    let offAxisRunnerCount: Int
    let coreSpineResampleSteps: Int
    let coreSpineKnotCount: Int

    /// **Current shipped look** — snapshot of all former procedural-beam literals.
    static let endingProduction: EnergyBeamVisualTuning = .init(
        label: "endingProduction",
        timelineInterval: 1.0 / 16.0,
        lanesPerSide: 5,
        sparkCount: 12,
        tendrilSegmentMin: 2,
        tendrilSegmentMax: 5,
        forkProbabilityThreshold: 0.72,
        flowStreakCount: 3,
        flowPacketCount: 4,
        reflectFragmentCount: 1,
        beamOuterHeight: 78,
        referenceFloor: 6000,
        referenceScaleMultiplier: 0.28,
        referenceScaleMinimum: 1800,
        marginMaxHorizontalFraction: 0.36,
        collisionClampMinFraction: 0.11,
        collisionClampMaxFraction: 0.89,
        wDrawIdleMultiplier: 0.24,
        wDrawImpactExtra: 0.24,
        impactBoostWindowSeconds: 0.5,
        impactBoostPeakExponent: 50.15,
        impactBoostShimmerAmplitude: 0.14,
        impactBoostShimmerFrequency: 48,
        useProportionalHorizontalPads: true,
        horizontalBandLeftEdgeFraction: 0,
        horizontalBandRightEdgeFraction: 1,
        leftPadLeadingOffset: -20,
        rightPadTrailingExtra: 10,
        impactVisualScale: 1,
        masterStrokeOpacity: 1,
        globalBrightImpactCoefficient: 0.62,
        flareMulBase: 0.001,
        flareMulImpactCoefficient: 2.25,
        burstScaleBase: 1.2,
        burstScaleImpactCoefficient: 1.1,
        flowMulBase: 1.2,
        flowMulImpactCoefficient: 0.05,
        idleGlowBase: 0.78,
        idleGlowSeedStride: 0.17,
        idleGlowSineAFrequency: 3.1,
        idleGlowSineAAmplitude: 0.1,
        idleGlowSineBFrequency: 7.8,
        idleGlowSineBAmplitude: 0.05,
        idleGlowSineCFrequency: 1.73,
        idleGlowSineCAmplitude: 0.04,
        idleGlowSteppedMultiplier: 0.05,
        idleGlowSteppedWallFrequency: 9.7,
        lanePhaseSpeedMin: 0.48,
        lanePhaseSpeedSpan: 0.95,
        lanePhaseLaneWeight: 1.83,
        lanePhaseSeedWeight: 0.01,
        amplitudeCalmBase: 0.35,
        amplitudeCalmSpan: 0.65,
        amplitudeBurstBase: 5.65,
        amplitudeBurstWobble: 0.35,
        amplitudeChaosBase: 0.55,
        amplitudeChaosSpan: 0.9,
        helixRunnerCount: 6,
        offAxisRunnerCount: 6,
        coreSpineResampleSteps: 32,
        coreSpineKnotCount: 4
    )

    /// **Intro / ghost preset** — near-invisible seed; TimelineView tweens toward `endingProduction` on app open.
    static let beginningIntro: EnergyBeamVisualTuning = .init(
        label: "beginningIntro",
        timelineInterval: 1.0 / 16.0,
        lanesPerSide: 1,
        sparkCount: 0,
        tendrilSegmentMin: 2,
        tendrilSegmentMax: 2,
        forkProbabilityThreshold: 0.98,
        flowStreakCount: 0,
        flowPacketCount: 1,
        reflectFragmentCount: 0,
        beamOuterHeight: 44,
        referenceFloor: 6000,
        referenceScaleMultiplier: 0.28,
        referenceScaleMinimum: 1800,
        marginMaxHorizontalFraction: 0.04,
        collisionClampMinFraction: 0.47,
        collisionClampMaxFraction: 0.53,
        wDrawIdleMultiplier: 0.04,
        wDrawImpactExtra: 0.02,
        impactBoostWindowSeconds: 0.25,
        impactBoostPeakExponent: 10,
        impactBoostShimmerAmplitude: 0.04,
        impactBoostShimmerFrequency: 6,
        useProportionalHorizontalPads: true,
        horizontalBandLeftEdgeFraction: 0.40,
        horizontalBandRightEdgeFraction: 0.60,
        leftPadLeadingOffset: -20,
        rightPadTrailingExtra: 10,
        impactVisualScale: 0.04,
        masterStrokeOpacity: 0.07,
        globalBrightImpactCoefficient: 0.12,
        flareMulBase: 0.001,
        flareMulImpactCoefficient: 0.35,
        burstScaleBase: 0.85,
        burstScaleImpactCoefficient: 0.2,
        flowMulBase: 0.85,
        flowMulImpactCoefficient: 0.01,
        idleGlowBase: 0.18,
        idleGlowSeedStride: 0.17,
        idleGlowSineAFrequency: 4.2,
        idleGlowSineAAmplitude: 0.06,
        idleGlowSineBFrequency: 9.5,
        idleGlowSineBAmplitude: 0.03,
        idleGlowSineCFrequency: 2.1,
        idleGlowSineCAmplitude: 0.02,
        idleGlowSteppedMultiplier: 0.04,
        idleGlowSteppedWallFrequency: 11,
        lanePhaseSpeedMin: 0.18,
        lanePhaseSpeedSpan: 0.25,
        lanePhaseLaneWeight: 1.83,
        lanePhaseSeedWeight: 0.01,
        amplitudeCalmBase: 0.22,
        amplitudeCalmSpan: 0.28,
        amplitudeBurstBase: 1.2,
        amplitudeBurstWobble: 0.12,
        amplitudeChaosBase: 0.22,
        amplitudeChaosSpan: 0.28,
        helixRunnerCount: 1,
        offAxisRunnerCount: 1,
        coreSpineResampleSteps: 16,
        coreSpineKnotCount: 1
    )
}

extension EnergyBeamVisualTuning {
    /// Linear blend of every numeric field (`t` 0 = `from`, 1 = `to`). When pad modes match, they stay on; otherwise flips at `t >= 0.5`. `label` is diagnostic only.
    static func interpolated(from a: EnergyBeamVisualTuning, to b: EnergyBeamVisualTuning, t: CGFloat) -> EnergyBeamVisualTuning {
        let u = Double(min(1, max(0, t)))
        func L(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * CGFloat(u) }
        func D(_ x: Double, _ y: Double) -> Double { x + (y - x) * u }
        func I(_ x: Int, _ y: Int) -> Int { Int((Double(x) + Double(y - x) * u).rounded()) }
        func TI(_ x: TimeInterval, _ y: TimeInterval) -> TimeInterval { x + (y - x) * u }
        let prop: Bool = if a.useProportionalHorizontalPads == b.useProportionalHorizontalPads {
            a.useProportionalHorizontalPads
        } else {
            t >= 0.5 ? b.useProportionalHorizontalPads : a.useProportionalHorizontalPads
        }
        let smin = I(a.tendrilSegmentMin, b.tendrilSegmentMin)
        var smax = I(a.tendrilSegmentMax, b.tendrilSegmentMax)
        if smax < smin { smax = smin }
        return .init(
            label: "interp(\(String(format: "%.2f", u)))",
            timelineInterval: TI(a.timelineInterval, b.timelineInterval),
            lanesPerSide: max(1, I(a.lanesPerSide, b.lanesPerSide)),
            sparkCount: max(0, I(a.sparkCount, b.sparkCount)),
            tendrilSegmentMin: smin,
            tendrilSegmentMax: smax,
            forkProbabilityThreshold: L(a.forkProbabilityThreshold, b.forkProbabilityThreshold),
            flowStreakCount: max(0, I(a.flowStreakCount, b.flowStreakCount)),
            flowPacketCount: max(0, I(a.flowPacketCount, b.flowPacketCount)),
            reflectFragmentCount: max(0, I(a.reflectFragmentCount, b.reflectFragmentCount)),
            beamOuterHeight: max(1, L(a.beamOuterHeight, b.beamOuterHeight)),
            referenceFloor: D(a.referenceFloor, b.referenceFloor),
            referenceScaleMultiplier: D(a.referenceScaleMultiplier, b.referenceScaleMultiplier),
            referenceScaleMinimum: D(a.referenceScaleMinimum, b.referenceScaleMinimum),
            marginMaxHorizontalFraction: L(a.marginMaxHorizontalFraction, b.marginMaxHorizontalFraction),
            collisionClampMinFraction: L(a.collisionClampMinFraction, b.collisionClampMinFraction),
            collisionClampMaxFraction: L(a.collisionClampMaxFraction, b.collisionClampMaxFraction),
            wDrawIdleMultiplier: D(a.wDrawIdleMultiplier, b.wDrawIdleMultiplier),
            wDrawImpactExtra: D(a.wDrawImpactExtra, b.wDrawImpactExtra),
            impactBoostWindowSeconds: L(a.impactBoostWindowSeconds, b.impactBoostWindowSeconds),
            impactBoostPeakExponent: D(a.impactBoostPeakExponent, b.impactBoostPeakExponent),
            impactBoostShimmerAmplitude: D(a.impactBoostShimmerAmplitude, b.impactBoostShimmerAmplitude),
            impactBoostShimmerFrequency: D(a.impactBoostShimmerFrequency, b.impactBoostShimmerFrequency),
            useProportionalHorizontalPads: prop,
            horizontalBandLeftEdgeFraction: L(a.horizontalBandLeftEdgeFraction, b.horizontalBandLeftEdgeFraction),
            horizontalBandRightEdgeFraction: L(a.horizontalBandRightEdgeFraction, b.horizontalBandRightEdgeFraction),
            leftPadLeadingOffset: L(a.leftPadLeadingOffset, b.leftPadLeadingOffset),
            rightPadTrailingExtra: L(a.rightPadTrailingExtra, b.rightPadTrailingExtra),
            impactVisualScale: L(a.impactVisualScale, b.impactVisualScale),
            masterStrokeOpacity: L(a.masterStrokeOpacity, b.masterStrokeOpacity),
            globalBrightImpactCoefficient: L(a.globalBrightImpactCoefficient, b.globalBrightImpactCoefficient),
            flareMulBase: L(a.flareMulBase, b.flareMulBase),
            flareMulImpactCoefficient: L(a.flareMulImpactCoefficient, b.flareMulImpactCoefficient),
            burstScaleBase: L(a.burstScaleBase, b.burstScaleBase),
            burstScaleImpactCoefficient: L(a.burstScaleImpactCoefficient, b.burstScaleImpactCoefficient),
            flowMulBase: L(a.flowMulBase, b.flowMulBase),
            flowMulImpactCoefficient: L(a.flowMulImpactCoefficient, b.flowMulImpactCoefficient),
            idleGlowBase: L(a.idleGlowBase, b.idleGlowBase),
            idleGlowSeedStride: D(a.idleGlowSeedStride, b.idleGlowSeedStride),
            idleGlowSineAFrequency: D(a.idleGlowSineAFrequency, b.idleGlowSineAFrequency),
            idleGlowSineAAmplitude: L(a.idleGlowSineAAmplitude, b.idleGlowSineAAmplitude),
            idleGlowSineBFrequency: D(a.idleGlowSineBFrequency, b.idleGlowSineBFrequency),
            idleGlowSineBAmplitude: L(a.idleGlowSineBAmplitude, b.idleGlowSineBAmplitude),
            idleGlowSineCFrequency: D(a.idleGlowSineCFrequency, b.idleGlowSineCFrequency),
            idleGlowSineCAmplitude: L(a.idleGlowSineCAmplitude, b.idleGlowSineCAmplitude),
            idleGlowSteppedMultiplier: L(a.idleGlowSteppedMultiplier, b.idleGlowSteppedMultiplier),
            idleGlowSteppedWallFrequency: D(a.idleGlowSteppedWallFrequency, b.idleGlowSteppedWallFrequency),
            lanePhaseSpeedMin: D(a.lanePhaseSpeedMin, b.lanePhaseSpeedMin),
            lanePhaseSpeedSpan: D(a.lanePhaseSpeedSpan, b.lanePhaseSpeedSpan),
            lanePhaseLaneWeight: D(a.lanePhaseLaneWeight, b.lanePhaseLaneWeight),
            lanePhaseSeedWeight: D(a.lanePhaseSeedWeight, b.lanePhaseSeedWeight),
            amplitudeCalmBase: L(a.amplitudeCalmBase, b.amplitudeCalmBase),
            amplitudeCalmSpan: L(a.amplitudeCalmSpan, b.amplitudeCalmSpan),
            amplitudeBurstBase: L(a.amplitudeBurstBase, b.amplitudeBurstBase),
            amplitudeBurstWobble: L(a.amplitudeBurstWobble, b.amplitudeBurstWobble),
            amplitudeChaosBase: L(a.amplitudeChaosBase, b.amplitudeChaosBase),
            amplitudeChaosSpan: L(a.amplitudeChaosSpan, b.amplitudeChaosSpan),
            helixRunnerCount: max(1, I(a.helixRunnerCount, b.helixRunnerCount)),
            offAxisRunnerCount: max(1, I(a.offAxisRunnerCount, b.offAxisRunnerCount)),
            coreSpineResampleSteps: max(4, I(a.coreSpineResampleSteps, b.coreSpineResampleSteps)),
            coreSpineKnotCount: max(1, I(a.coreSpineKnotCount, b.coreSpineKnotCount))
        )
    }

    /// Visual birth lerps `visualT`; procedural motion stays at `to` (production) × `motionScale` so particles do not race mid-intro.
    static func interpolatedVisualBirth(
        from a: EnergyBeamVisualTuning,
        to b: EnergyBeamVisualTuning,
        visualT: CGFloat,
        motionScale: Double
    ) -> EnergyBeamVisualTuning {
        let u = Double(min(1, max(0, visualT)))
        let m = max(0, motionScale)
        func L(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * CGFloat(u) }
        func D(_ x: Double, _ y: Double) -> Double { x + (y - x) * u }
        func I(_ x: Int, _ y: Int) -> Int { Int((Double(x) + Double(y - x) * u).rounded()) }
        func TI(_ x: TimeInterval, _ y: TimeInterval) -> TimeInterval { x + (y - x) * u }
        func MS(_ x: Double) -> Double { x * m }
        let prop: Bool = if a.useProportionalHorizontalPads == b.useProportionalHorizontalPads {
            a.useProportionalHorizontalPads
        } else {
            visualT >= 0.5 ? b.useProportionalHorizontalPads : a.useProportionalHorizontalPads
        }
        let smin = I(a.tendrilSegmentMin, b.tendrilSegmentMin)
        var smax = I(a.tendrilSegmentMax, b.tendrilSegmentMax)
        if smax < smin { smax = smin }
        return .init(
            label: "birth(\(String(format: "%.2f", u)),m=\(String(format: "%.2f", m)))",
            timelineInterval: TI(a.timelineInterval, b.timelineInterval),
            lanesPerSide: max(1, I(a.lanesPerSide, b.lanesPerSide)),
            sparkCount: max(0, I(a.sparkCount, b.sparkCount)),
            tendrilSegmentMin: smin,
            tendrilSegmentMax: smax,
            forkProbabilityThreshold: L(a.forkProbabilityThreshold, b.forkProbabilityThreshold),
            flowStreakCount: max(0, I(a.flowStreakCount, b.flowStreakCount)),
            flowPacketCount: max(0, I(a.flowPacketCount, b.flowPacketCount)),
            reflectFragmentCount: max(0, I(a.reflectFragmentCount, b.reflectFragmentCount)),
            beamOuterHeight: max(1, L(a.beamOuterHeight, b.beamOuterHeight)),
            referenceFloor: D(a.referenceFloor, b.referenceFloor),
            referenceScaleMultiplier: D(a.referenceScaleMultiplier, b.referenceScaleMultiplier),
            referenceScaleMinimum: D(a.referenceScaleMinimum, b.referenceScaleMinimum),
            marginMaxHorizontalFraction: L(a.marginMaxHorizontalFraction, b.marginMaxHorizontalFraction),
            collisionClampMinFraction: L(a.collisionClampMinFraction, b.collisionClampMinFraction),
            collisionClampMaxFraction: L(a.collisionClampMaxFraction, b.collisionClampMaxFraction),
            wDrawIdleMultiplier: MS(b.wDrawIdleMultiplier),
            wDrawImpactExtra: MS(b.wDrawImpactExtra),
            impactBoostWindowSeconds: L(a.impactBoostWindowSeconds, b.impactBoostWindowSeconds),
            impactBoostPeakExponent: D(a.impactBoostPeakExponent, b.impactBoostPeakExponent),
            impactBoostShimmerAmplitude: L(a.impactBoostShimmerAmplitude, b.impactBoostShimmerAmplitude),
            impactBoostShimmerFrequency: MS(b.impactBoostShimmerFrequency),
            useProportionalHorizontalPads: prop,
            horizontalBandLeftEdgeFraction: L(a.horizontalBandLeftEdgeFraction, b.horizontalBandLeftEdgeFraction),
            horizontalBandRightEdgeFraction: L(a.horizontalBandRightEdgeFraction, b.horizontalBandRightEdgeFraction),
            leftPadLeadingOffset: L(a.leftPadLeadingOffset, b.leftPadLeadingOffset),
            rightPadTrailingExtra: L(a.rightPadTrailingExtra, b.rightPadTrailingExtra),
            impactVisualScale: L(a.impactVisualScale, b.impactVisualScale),
            masterStrokeOpacity: L(a.masterStrokeOpacity, b.masterStrokeOpacity),
            globalBrightImpactCoefficient: L(a.globalBrightImpactCoefficient, b.globalBrightImpactCoefficient),
            flareMulBase: L(a.flareMulBase, b.flareMulBase),
            flareMulImpactCoefficient: L(a.flareMulImpactCoefficient, b.flareMulImpactCoefficient),
            burstScaleBase: L(a.burstScaleBase, b.burstScaleBase),
            burstScaleImpactCoefficient: L(a.burstScaleImpactCoefficient, b.burstScaleImpactCoefficient),
            flowMulBase: L(a.flowMulBase, b.flowMulBase) * CGFloat(m),
            flowMulImpactCoefficient: L(a.flowMulImpactCoefficient, b.flowMulImpactCoefficient) * CGFloat(m),
            idleGlowBase: L(a.idleGlowBase, b.idleGlowBase),
            idleGlowSeedStride: D(a.idleGlowSeedStride, b.idleGlowSeedStride),
            idleGlowSineAFrequency: MS(b.idleGlowSineAFrequency),
            idleGlowSineAAmplitude: L(a.idleGlowSineAAmplitude, b.idleGlowSineAAmplitude),
            idleGlowSineBFrequency: MS(b.idleGlowSineBFrequency),
            idleGlowSineBAmplitude: L(a.idleGlowSineBAmplitude, b.idleGlowSineBAmplitude),
            idleGlowSineCFrequency: MS(b.idleGlowSineCFrequency),
            idleGlowSineCAmplitude: L(a.idleGlowSineCAmplitude, b.idleGlowSineCAmplitude),
            idleGlowSteppedMultiplier: L(a.idleGlowSteppedMultiplier, b.idleGlowSteppedMultiplier),
            idleGlowSteppedWallFrequency: MS(b.idleGlowSteppedWallFrequency),
            lanePhaseSpeedMin: MS(b.lanePhaseSpeedMin),
            lanePhaseSpeedSpan: MS(b.lanePhaseSpeedSpan),
            lanePhaseLaneWeight: D(a.lanePhaseLaneWeight, b.lanePhaseLaneWeight),
            lanePhaseSeedWeight: D(a.lanePhaseSeedWeight, b.lanePhaseSeedWeight),
            amplitudeCalmBase: L(a.amplitudeCalmBase, b.amplitudeCalmBase) * CGFloat(m),
            amplitudeCalmSpan: L(a.amplitudeCalmSpan, b.amplitudeCalmSpan) * CGFloat(m),
            amplitudeBurstBase: L(a.amplitudeBurstBase, b.amplitudeBurstBase) * CGFloat(m),
            amplitudeBurstWobble: L(a.amplitudeBurstWobble, b.amplitudeBurstWobble) * CGFloat(m),
            amplitudeChaosBase: L(a.amplitudeChaosBase, b.amplitudeChaosBase) * CGFloat(m),
            amplitudeChaosSpan: L(a.amplitudeChaosSpan, b.amplitudeChaosSpan) * CGFloat(m),
            helixRunnerCount: max(1, I(a.helixRunnerCount, b.helixRunnerCount)),
            offAxisRunnerCount: max(1, I(a.offAxisRunnerCount, b.offAxisRunnerCount)),
            coreSpineResampleSteps: max(4, I(a.coreSpineResampleSteps, b.coreSpineResampleSteps)),
            coreSpineKnotCount: max(1, I(a.coreSpineKnotCount, b.coreSpineKnotCount))
        )
    }
}

/// Active tuning for static `ProceduralBeamRenderer` helpers (set around `drawBeam`; restored after). UI-thread Canvas only.
private enum EnergyBeamBeamDrawingActiveTuning {
    nonisolated(unsafe) static var value: EnergyBeamVisualTuning = .endingProduction
}

// MARK: - Layout / timing (shared with Home + DEBUG prototype)

enum EnergyBeamHeroLayout {
    /// Default `referenceBattleValue` for `normalizedBeamOffset` (prototype parity).
    static let defaultBeamReferenceValue: Int = 8_431

    // MARK: - Hero margin transition (Home + DEBUG previews)

    /// Midpoint duration for sliders / presets when not using delta-scaled timing.
    static let marginDrivenAnimationSeconds: Double = 1.85

    /// Minimum duration for margin / score counting and beam collision slide (Home tuning preview).
    static let marginTransitionMinSeconds: Double = 1.85
    static let marginTransitionMaxSeconds: Double = 3.25
    /// Above this magnitude of `target - start` (in margin points), duration reaches `marginTransitionMaxSeconds`.
    private static let marginTransitionDeltaSpan: Double = 7500

    // MARK: - Beam visual intro (app open / foreground)

    /// Duration for `beginningIntro` → `endingProduction` visual birth on session open.
    static let beamIntroAnimationSeconds: Double = 1.0

    /// Particle / lane drift speed during intro (`endingProduction` motion × this). **Lower** = calmer intro.
    static let introProceduralMotionScale: Double = 0.01

    /// Particle / lane drift during margin/score slide (`endingProduction` × this). 2× prior 1.6 so flow keeps up when margin moves.
    static let battleCountProceduralMotionScale: Double = 3.2

    /// Impact flashes during slide (0 = off). Integer margin ticks used to retrigger bursts — keep at 0 for fluid slides.
    static let battleCountImpactStrengthScale: Double = 0

    /// Ease for margin/score lerp during slide (linear = harsh integer cadence feel on the beam).
    static let battleCountSlideUsesEaseInOut: Bool = true

    /// Slow center wobble during intro (`sin(wall × freq) × width × fraction`).
    static let introCenterWobbleFrequency: Double = 0.65
    static let introCenterWobbleWidthFraction: CGFloat = 0.016

    /// Duration for animating from `start` to `target` comparable margin (steps or battle-score points).
    static func marginTransitionDuration(start: Double, target: Double) -> Double {
        let dMag = abs(target - start)
        let span = min(1, dMag / marginTransitionDeltaSpan)
        let scaled = marginTransitionMinSeconds + span * (marginTransitionMaxSeconds - marginTransitionMinSeconds)
        return max(marginTransitionMinSeconds, scaled)
    }

    /// Longest of margin / user / opponent score deltas — keeps counting + beam slide in sync.
    static func heroBattleTransitionDuration(
        startMargin: Double,
        targetMargin: Double,
        startUserBattleScore: Double,
        targetUserBattleScore: Double,
        startOpponentBattleScore: Double,
        targetOpponentBattleScore: Double
    ) -> Double {
        max(
            marginTransitionDuration(start: startMargin, target: targetMargin),
            marginTransitionDuration(start: startUserBattleScore, target: targetUserBattleScore),
            marginTransitionDuration(start: startOpponentBattleScore, target: targetOpponentBattleScore)
        )
    }

    /// Linear cadence so hero margin integers tick at a steady rate during updates.
    static func marginCountingAnimation(duration: Double) -> Animation {
        .linear(duration: duration)
    }

    /// Eased intro for procedural beam materializing on app open.
    static func beamIntroAnimation(duration: Double) -> Animation {
        .easeInOut(duration: duration)
    }

    /// Slow start / fast middle / slow finish — legacy preset / debug sliders.
    static func marginTransitionAnimation(duration: Double) -> Animation {
        .timingCurve(0.42, 0, 0.58, 1, duration: duration)
    }

    /// Opts out of Home's global `disablesAnimations` so hero `withAnimation` blocks actually run.
    static func withEnabledAnimation(_ animation: Animation? = .default, _ body: () -> Void) {
        var t = Transaction()
        t.disablesAnimations = false
        withTransaction(t) {
            withAnimation(animation, body)
        }
    }

    static func withEnabledTransaction(disablesAnimations: Bool, _ body: () -> Void) {
        var t = Transaction()
        t.disablesAnimations = disablesAnimations
        withTransaction(t, body)
    }

    // MARK: - Timeline-driven progress (Canvas-safe; avoids SwiftUI @State animation gaps)

    static func easeInOut01(_ u: Double) -> Double {
        if u <= 0 { return 0 }
        if u >= 1 { return 1 }
        return u < 0.5 ? 2 * u * u : 1 - pow(-2 * u + 2, 2) / 2
    }

    static func linearProgress(elapsed: TimeInterval, duration: TimeInterval) -> Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, elapsed / duration))
    }

    /// `0` = intro ghost, `1` = production. Uses wall clock so TimelineView redraws every tick.
    static func beamIntroProgress(at date: Date, startedAt: Date?, holdGhostBeforeStart: Bool) -> CGFloat {
        if holdGhostBeforeStart, startedAt == nil { return 0 }
        guard let startedAt else { return 1 }
        let elapsed = date.timeIntervalSince(startedAt)
        let u = linearProgress(elapsed: elapsed, duration: beamIntroAnimationSeconds)
        return CGFloat(easeInOut01(u))
    }
}

/// Resting + animated hero battle numbers (margin + column battle scores + beam collision).
struct EnergyBeamHeroAnimatedSnapshot: Equatable {
    var margin: Double
    var userBattleScore: Double
    var opponentBattleScore: Double
    var beamCollisionMargin: Double

    static func lerp(from a: Self, to b: Self, t: Double) -> Self {
        let u = min(1, max(0, t))
        func L(_ x: Double, _ y: Double) -> Double { x + (y - x) * u }
        return .init(
            margin: L(a.margin, b.margin),
            userBattleScore: L(a.userBattleScore, b.userBattleScore),
            opponentBattleScore: L(a.opponentBattleScore, b.opponentBattleScore),
            beamCollisionMargin: L(a.beamCollisionMargin, b.beamCollisionMargin)
        )
    }
}

struct EnergyBeamHeroBattleCountAnimation: Equatable {
    let startedAt: Date
    let duration: TimeInterval
    let from: EnergyBeamHeroAnimatedSnapshot
    let to: EnergyBeamHeroAnimatedSnapshot

    func snapshot(at date: Date) -> EnergyBeamHeroAnimatedSnapshot {
        let linearU = EnergyBeamHeroLayout.linearProgress(
            elapsed: date.timeIntervalSince(startedAt),
            duration: duration
        )
        if linearU >= 1 { return to }
        let u = EnergyBeamHeroLayout.battleCountSlideUsesEaseInOut
            ? EnergyBeamHeroLayout.easeInOut01(linearU)
            : linearU
        return .lerp(from: from, to: to, t: u)
    }
}

// MARK: - Mock sparkline series (Home fallback + DEBUG wiggle)

enum EnergyBeamHeroMockSeries {
    static func cumulativeUser(wiggle: CGFloat) -> [CGFloat] {
        let baseU: [CGFloat] = [
            0.02, 0.08, 0.11, 0.15, 0.19, 0.26, 0.33, 0.37, 0.42,
            0.48, 0.56, 0.62, 0.71, 0.78, 0.82, 0.88, 0.93, 0.97,
        ]
        return baseU.map { min(1, max(0, $0 + wiggle)) }
    }

    static func cumulativeOpponent(wiggle: CGFloat) -> [CGFloat] {
        let baseO: [CGFloat] = [
            0.015, 0.06, 0.085, 0.11, 0.155, 0.19, 0.235, 0.29, 0.335,
            0.392, 0.44, 0.492, 0.54, 0.61, 0.67, 0.74, 0.81, 0.872,
        ]
        return baseO.map { min(1, max(0, $0 + wiggle)) }
    }

    static func mockDomain(
        timeZone: TimeZone = .current,
        myToday: Int = 8_500,
        theirToday: Int = 6_200,
        wiggleUser: CGFloat = 0,
        wiggleOpp: CGFloat = 0
    ) -> HomeHeroSparklineDomain {
        let userNorm = cumulativeUser(wiggle: wiggleUser)
        let oppNorm = cumulativeOpponent(wiggle: wiggleOpp)
        let n = max(userNorm.count, oppNorm.count)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let now = Date()
        let dayStart = cal.startOfDay(for: now)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? now.addingTimeInterval(86_400)
        let spanSeconds = max(now.timeIntervalSince(dayStart), 1)

        var samples: [HomeHeroSparklineSample] = []
        for i in 0 ..< n {
            let fraction = n == 1 ? 1.0 : Double(i) / Double(n - 1)
            let t = dayStart.addingTimeInterval(fraction * spanSeconds)
            let uNorm = userNorm[min(i, userNorm.count - 1)]
            let oNorm = oppNorm[min(i, oppNorm.count - 1)]
            let userSteps = Int((Double(myToday) * Double(uNorm)).rounded())
            let oppSteps = Int((Double(theirToday) * Double(oNorm)).rounded())
            samples.append(HomeHeroSparklineSample(timestamp: t, userSteps: userSteps, opponentSteps: oppSteps))
        }
        if let lastIndex = samples.indices.last {
            samples[lastIndex] = HomeHeroSparklineSample(
                timestamp: samples[lastIndex].timestamp,
                userSteps: myToday,
                opponentSteps: theirToday
            )
        }
        return HomeHeroSparklineDomain(samples: samples, dayStart: dayStart, dayEnd: dayEnd, now: now)
    }
}

// MARK: - Beam offset formula

/// Maps raw `margin` into a horizontal offset factor used by the beam’s collision X (see `EnergyBeamVisualTuning.marginMaxHorizontalFraction`).
private func normalizedBeamOffset(margin: Double, referenceValue: Int, tuning: EnergyBeamVisualTuning) -> CGFloat {
    let reference = max(Double(referenceValue), tuning.referenceFloor)
    let scale = max(reference * tuning.referenceScaleMultiplier, tuning.referenceScaleMinimum)
    let raw = margin / scale
    let eased = tanh(raw)
    return CGFloat(eased) * tuning.marginMaxHorizontalFraction
}

/// `Int` overload; forwards to the `Double` version (same behavior).
private func normalizedBeamOffset(margin: Int, referenceValue: Int, tuning: EnergyBeamVisualTuning) -> CGFloat {
    normalizedBeamOffset(margin: Double(margin), referenceValue: referenceValue, tuning: tuning)
}

private func clampBeam(_ v: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
    Swift.min(Swift.max(v, lo), hi)
}

// MARK: - Collision X + margin copy (beam + sliding headline)

enum EnergyBeamHeroCollisionLayout {
    static func centerX(
        width: CGFloat,
        marginPrecise: Double,
        referenceBattleValue: Int,
        tuning: EnergyBeamVisualTuning,
        pinToCenterDuringIntro: Bool,
        wall: TimeInterval
    ) -> CGFloat {
        if pinToCenterDuringIntro {
            let wobble = sin(wall * EnergyBeamHeroLayout.introCenterWobbleFrequency)
                * width * EnergyBeamHeroLayout.introCenterWobbleWidthFraction
            return clampBeam(
                width * 0.5 + wobble,
                min: width * tuning.collisionClampMinFraction,
                max: width * tuning.collisionClampMaxFraction
            )
        }
        let cx = width * 0.5 + normalizedBeamOffset(
            margin: marginPrecise,
            referenceValue: referenceBattleValue,
            tuning: tuning
        ) * width
        return clampBeam(cx, min: width * tuning.collisionClampMinFraction, max: width * tuning.collisionClampMaxFraction)
    }

    static func eyebrow(margin: Int) -> String {
        if margin == 0 { return "TIED" }
        if margin > 0 { return "AHEAD BY" }
        return "BEHIND BY"
    }

    static func eyebrowColor(margin: Int) -> Color {
        if margin == 0 { return FitUpColors.Text.secondary }
        if margin > 0 { return FitUpColors.Neon.cyan }
        return FitUpColors.Neon.orange.opacity(0.95)
    }

    static func heroNumberText(margin: Int) -> String {
        if margin == 0 { return "0" }
        let nf = EnergyBeamNumberFormatting.score
        let n = nf.string(from: NSNumber(value: abs(margin))) ?? "\(abs(margin))"
        if margin > 0 { return "+\(n)" }
        return "-\(n)"
    }

    /// Battle-status copy for the retro callout above the beam.
    static func statusCallout(margin: Int) -> String {
        if margin == 0 { return "TIED" }
        if margin > 0 { return "AHEAD" }
        return "BEHIND"
    }

    /// Dynamic accent for post-beam margin number — cyan when winning, orange when losing, neutral at center.
    static func marginAccent(margin: Int, referenceValue: Int) -> Color {
        if margin == 0 { return HomePageStyle.offWhite }
        let intensity = min(Double(abs(margin)) / Double(max(referenceValue, 1)), 1)
        if margin > 0 {
            return Color(
                red: 0.12 + (1 - intensity) * 0.88,
                green: 0.72 + (1 - intensity) * 0.28,
                blue: 0.95 + (1 - intensity) * 0.05
            )
        }
        return Color(
            red: 1,
            green: 0.38 + (1 - intensity) * 0.62,
            blue: 0.06 + (1 - intensity) * 0.94
        )
    }

    static func marginGlowOpacity(margin: Int, referenceValue: Int) -> Double {
        if margin == 0 { return 0.25 }
        let intensity = min(Double(abs(margin)) / Double(max(referenceValue, 1)), 1)
        return 0.28 + intensity * 0.55
    }
}

/// Retro arcade status pill (ahead / behind / tied) — fixed above the beam, no motion effects.
private struct EnergyBeamBattleStatusCallout: View {
    let margin: Int

    @Environment(\.homeHeroCompactScale) private var compactScale

    private var accent: Color { EnergyBeamHeroCollisionLayout.eyebrowColor(margin: margin) }
    private var label: String { EnergyBeamHeroCollisionLayout.statusCallout(margin: margin) }

    private static let baseReservedHeight: CGFloat = 34

    var reservedHeight: CGFloat { HomeHeroCompactLayout.scaled(Self.baseReservedHeight, by: compactScale) }

    var body: some View {
        Text(label)
            .font(FitUpFont.mono(HomeHeroCompactLayout.scaled(14, by: compactScale), weight: .heavy))
            .foregroundStyle(accent)
            .tracking(5.2 * compactScale)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .allowsTightening(true)
            .padding(.horizontal, HomeHeroCompactLayout.scaled(22, by: compactScale))
            .padding(.vertical, HomeHeroCompactLayout.scaled(7, by: compactScale))
            .background {
                NeonGlowCapsuleChrome(accent: accent)
            }
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.25), value: margin)
            .accessibilityLabel(label)
    }
}

/// Margin number + unit row below the beam with animated directional arrow.
private struct EnergyBeamPostBeamMarginRow: View {
    let margin: Int
    let unitLabel: String
    let referenceValue: Int

    @Environment(\.homeHeroCompactScale) private var compactScale

    private static let baseReservedHeight: CGFloat = 46

    var reservedHeight: CGFloat { HomeHeroCompactLayout.scaled(Self.baseReservedHeight, by: compactScale) }

    private var accent: Color {
        EnergyBeamHeroCollisionLayout.marginAccent(margin: margin, referenceValue: referenceValue)
    }

    private var glowOpacity: Double {
        EnergyBeamHeroCollisionLayout.marginGlowOpacity(margin: margin, referenceValue: referenceValue)
    }

    var body: some View {
        HStack(alignment: .center, spacing: HomeHeroCompactLayout.scaled(8, by: compactScale)) {
            Text(EnergyBeamHeroCollisionLayout.heroNumberText(margin: margin))
                .font(FitUpFont.display(HomeHeroCompactLayout.scaled(38, by: compactScale), weight: .heavy))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .allowsTightening(true)
                .contentTransition(.numericText())
                .shadow(color: accent.opacity(glowOpacity), radius: HomeHeroCompactLayout.scaled(14, by: compactScale), y: 0)
                .shadow(color: accent.opacity(glowOpacity * 0.55), radius: HomeHeroCompactLayout.scaled(28, by: compactScale), y: 0)

            Text(unitLabel)
                .font(FitUpFont.body(HomeHeroCompactLayout.scaled(13, by: compactScale), weight: .heavy))
                .foregroundStyle(HomePageStyle.muted)
                .tracking(2.4 * compactScale)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, HomeHeroCompactLayout.scaled(6, by: compactScale))
        .frame(height: reservedHeight)
        .animation(.easeInOut(duration: 0.25), value: margin)
        .accessibilityElement(children: .combine)
    }
}

/// Margin number + guide line + unit sit above the beam; only the hero number and unit track collision X.
private struct EnergyBeamCollisionAlignedMarginHeadline: View {
    let collisionX: CGFloat
    let trackWidth: CGFloat
    let margin: Int
    let unitLabel: String

    private var accent: Color { EnergyBeamHeroCollisionLayout.eyebrowColor(margin: margin) }
    static let reservedHeight: CGFloat = 74
    private let blockHeight: CGFloat = reservedHeight
    private let horizontalEdgePadding: CGFloat = 44
    private let lineGapHalf: CGFloat = 40
    private let numberRowY: CGFloat = 22
    private let unitBelowNumberGap: CGFloat = 8
    /// Vertical link from the hero number down toward the beam.
    private let beamConnectorTopY: CGFloat = 30
    private let beamConnectorBottomY: CGFloat = 70
    private let collisionStackMaxWidth: CGFloat = 148

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let markerX = min(max(collisionX, horizontalEdgePadding), w - horizontalEdgePadding)

            ZStack {
                beamCollisionConnector(at: markerX)

                HStack(spacing: 0) {
                    horizontalGuideLine(fadeFromLeading: true)
                        .frame(width: max(0, markerX - lineGapHalf))
                    Color.clear.frame(width: lineGapHalf * 2)
                    horizontalGuideLine(fadeFromLeading: false)
                        .frame(width: max(0, w - markerX - lineGapHalf))
                }
                .frame(width: w, height: 1)
                .position(x: w * 0.5, y: numberRowY)

                VStack(spacing: unitBelowNumberGap) {
                    Text(EnergyBeamHeroCollisionLayout.heroNumberText(margin: margin))
                        .font(FitUpFont.display(34, weight: .heavy))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .allowsTightening(true)
                        .contentTransition(.numericText())
                        .shadow(color: accent.opacity(0.35), radius: 10, y: 0)

                    Text(unitLabel)
                        .font(FitUpFont.body(11, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.secondary.opacity(0.92))
                        .tracking(2.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .allowsTightening(true)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: collisionStackMaxWidth)
                .position(x: markerX, y: numberRowY + 10)
            }
            .clipped()
        }
        .frame(height: blockHeight)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    /// Dim vertical link from the margin number down toward the beam.
    private func beamCollisionConnector(at x: CGFloat) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.06),
                        accent.opacity(0.2),
                        accent.opacity(0.38),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 1, height: beamConnectorBottomY - beamConnectorTopY)
            .position(x: x, y: (beamConnectorTopY + beamConnectorBottomY) * 0.5)
    }

    private func horizontalGuideLine(fadeFromLeading: Bool) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: fadeFromLeading
                        ? [accent.opacity(0.02), accent.opacity(0.28)]
                        : [accent.opacity(0.28), accent.opacity(0.02)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}

// MARK: - Mini logo

/// Tiny FitUp wordmark row for the hero header (purely decorative).
private struct FitUpMiniLogoPreview: View {
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Circle().fill(FitUpColors.Neon.cyan.opacity(0.95)).frame(width: 9, height: 9)
                Circle().fill(FitUpColors.Neon.blue.opacity(0.95)).frame(width: 7, height: 7)
                    .offset(y: -1)
                Circle().fill(FitUpColors.Neon.orange.opacity(0.95)).frame(width: 10, height: 10)
                    .offset(x: -2)
            }
            Text("FitUp")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))
                .tracking(0.35)
                .minimumScaleFactor(0.85)
                .allowsTightening(true)
        }
        .allowsTightening(true)
        .minimumScaleFactor(0.92)
    }
}

// MARK: - Player column

/// Which side of the mock battle a column represents (labels only).
private enum BattlePlayerRolePreview {
    case user
    case opponent
}

/// One player column: glyph, steps, divider, battle score text.
private struct PlayerColumnPreview: View {
    let role: BattlePlayerRolePreview
    let accent: Color
    let name: String
    let stepCount: Int
    let battleScore: Int
    let scoreCaption: String
    let isBalancedStepsBattle: Bool

    @Environment(\.homeHeroCompactScale) private var compactScale
    @State private var showStepsDisclaimer = false

    var body: some View {
        VStack(spacing: HomeHeroCompactLayout.scaled(4, by: compactScale)) {
            HeroProfileAvatarBadge(name: name, accent: accent, role: role)

            Color.clear
                .frame(height: HomeHeroCompactLayout.scaled(NeonHeroVersusLayout.profileNameBelowAvatarReservedHeight, by: compactScale))

            Button {
                showStepsDisclaimer = true
            } label: {
                VStack(spacing: HomeHeroCompactLayout.scaled(3, by: compactScale)) {
                    Text(stepCountLabel)
                        .font(FitUpFont.body(HomeHeroCompactLayout.scaled(13, by: compactScale), weight: .semibold))
                        .foregroundStyle(FitUpColors.Neon.yellow.opacity(0.88))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    FitUpColors.Neon.yellow.opacity(0.55),
                                    FitUpColors.Neon.yellow.opacity(0.18),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: max(1, HomeHeroCompactLayout.scaled(2, by: compactScale)))
                        .frame(maxWidth: HomeHeroCompactLayout.scaled(88, by: compactScale))
                }
            }
            .buttonStyle(.plain)
            .alert("Actual steps vs Battle Score", isPresented: $showStepsDisclaimer) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(stepsDisclaimerMessage)
            }

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)

            Text(scoreCaption)
                .font(FitUpFont.body(HomeHeroCompactLayout.scaled(11, by: compactScale), weight: .semibold))
                .foregroundStyle(accent.opacity(0.85))
                .tracking(0.35 * compactScale)

            Text(EnergyBeamNumberFormatting.score.string(from: NSNumber(value: battleScore)) ?? "\(battleScore)")
                .font(FitUpFont.display(HomeHeroCompactLayout.scaled(28, by: compactScale), weight: .heavy))
                .foregroundStyle(accent.opacity(1))
                .shadow(color: accent.opacity(0.35), radius: HomeHeroCompactLayout.scaled(10, by: compactScale))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .allowsTightening(true)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: role == .user ? .leading : .trailing)
    }

    /// “12,345 steps today” string from `stepCount` using `EnergyBeamNumberFormatting.steps`.
    private var stepCountLabel: String {
        let n = EnergyBeamNumberFormatting.steps.string(from: NSNumber(value: stepCount)) ?? "\(stepCount)"
        return "\(n) steps today"
    }

    private var stepsDisclaimerMessage: String {
        if isBalancedStepsBattle {
            return "These are your real step counts from HealthKit — not the number used to decide the battle. In a Balanced Battle, Battle Score adjusts for fairness, so steps and score won't match."
        }
        return "These are your real step counts from HealthKit. In a Raw Battle, step totals are what count toward your Battle Score."
    }
}

/// Circular avatar with retro slanted name overlay and accent ring.
private struct HeroProfileAvatarBadge: View {
    let name: String
    let accent: Color
    let role: BattlePlayerRolePreview

    @Environment(\.homeHeroCompactScale) private var compactScale

    private var diameter: CGFloat { HomeHeroCompactLayout.scaled(80, by: compactScale) }

    var body: some View {
        ZStack {
            Image(systemName: "person.fill")
                .font(.system(size: HomeHeroCompactLayout.scaled(32, by: compactScale), weight: .semibold))
                .foregroundStyle(accent.opacity(0.42))
                .shadow(color: accent.opacity(0.25), radius: HomeHeroCompactLayout.scaled(8, by: compactScale))
        }
        .frame(width: diameter, height: diameter)
        .background(.black.opacity(0.32))
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [accent.opacity(0.95), accent.opacity(0.45), accent.opacity(0.95)],
                        center: .center
                    ),
                    lineWidth: max(1, HomeHeroCompactLayout.scaled(3, by: compactScale))
                )
        )
        .shadow(color: accent.opacity(0.35), radius: HomeHeroCompactLayout.scaled(14, by: compactScale), y: 5)
        .shadow(color: accent.opacity(0.18), radius: HomeHeroCompactLayout.scaled(22, by: compactScale), y: 8)
    }
}

// MARK: - Procedural energy beam (Canvas + TimelineView)
private enum BeamTeamColors {
    static let userBloom = Color(red: 0.12, green: 0.98, blue: 0.95)
    static let userCore = Color(red: 0.78, green: 1, blue: 1)
    static let userMid = Color(red: 0, green: 0.88, blue: 1)
    static let userDeep = Color(red: 0, green: 0.62, blue: 0.92)

    static let oppBloom = Color(red: 1, green: 0.38, blue: 0.06)
    static let oppCore = Color(red: 1, green: 0.62, blue: 0.12)
    static let oppMid = Color(red: 1, green: 0.48, blue: 0.1)
    static let oppEmber = Color(red: 1, green: 0.22, blue: 0.05)
}

/// `TimelineView` supplies `wall` time for procedural motion; intro tuning is recomputed every tick from `beamIntroStartedAt`.
/// `marginPrecise` collision X interpolates when the caller drives a timeline-based or animated margin.
private struct ProceduralEnergyBeamView: View {
    /// Same as parent `margin`; collision X interpolates when this animates (caller `withAnimation` / transaction).
    let marginPrecise: Double
    /// Passed into `normalizedBeamOffset` alongside `beamVisualTuning`.
    let referenceBattleValue: Int
    /// Same as parent `battleMarginInt`; changes discretely during a fractional margin animation.
    let marginRounded: Int
    /// Target look when intro completes (`endingProduction` in app).
    var beamVisualTuning: EnergyBeamVisualTuning = .endingProduction
    /// When set, intro progress = elapsed / `beamIntroAnimationSeconds` (TimelineView-driven).
    var beamIntroStartedAt: Date? = nil
    /// When true and `beamIntroStartedAt` is nil, draw at intro ghost (`t = 0`).
    var beamIntroHoldGhost: Bool = false
    /// Pin collision to card center with slow wobble while intro runs.
    var pinCollisionToCenterDuringIntro: Bool = false
    /// Scales lane drift / shimmer frequencies (intro ≈ 0.22, production = 1).
    var proceduralMotionScale: Double = 1
    /// Scales impact burst strength when margin integers tick (score catch-up).
    var impactStrengthScale: CGFloat = 1
    /// When set, Canvas noise uses this instead of `marginRounded` so the beam does not re-roll every integer during a slide.
    var proceduralDrawSeed: Int? = nil
    /// When true, integer margin changes do not retrigger impact pulses (fluid score catch-up).
    var suppressImpactBursts: Bool = false

    @Environment(\.homeHeroCompactScale) private var compactScale

    /// Wall-clock time of last integer margin change; drives short `impact` pulse in `drawBeam`.
    @State private var lastImpactAtWall: TimeInterval = -1000

    private var drawSeed: Int { proceduralDrawSeed ?? marginRounded }

    private func scaledBeamHeight(_ base: CGFloat) -> CGFloat {
        HomeHeroCompactLayout.scaled(base, by: compactScale)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let introT = EnergyBeamHeroLayout.beamIntroProgress(
                    at: timeline.date,
                    startedAt: beamIntroStartedAt,
                    holdGhostBeforeStart: beamIntroHoldGhost
                )
                let introActive = introT < 1 && (beamIntroStartedAt != nil || beamIntroHoldGhost)
                let motionScale = introActive
                    ? EnergyBeamHeroLayout.introProceduralMotionScale
                    : max(0, proceduralMotionScale)
                let activeTuning: EnergyBeamVisualTuning = introActive
                    ? .interpolatedVisualBirth(
                        from: .beginningIntro,
                        to: beamVisualTuning,
                        visualT: introT,
                        motionScale: motionScale
                    )
                    : scaledProductionTuning(motionScale: motionScale, impactScale: impactStrengthScale)
                let stripHeight = scaledBeamHeight(activeTuning.beamOuterHeight)
                let midY = stripHeight * 0.5
                let wall = timeline.date.timeIntervalSinceReferenceDate
                let collisionX = resolveCollisionX(
                    width: w,
                    tuning: activeTuning,
                    introActive: introActive,
                    wall: wall
                )
                let impact = impactBoost(atWallTime: wall, tuning: activeTuning) * impactStrengthScale
                Canvas { context, size in
                    ProceduralBeamRenderer.drawBeam(
                        context: &context,
                        size: size,
                        collisionX: collisionX,
                        midY: midY,
                        wall: wall,
                        wDraw: wall * (activeTuning.wDrawIdleMultiplier + Double(impact) * activeTuning.wDrawImpactExtra),
                        rawImpact: impact,
                        seed: drawSeed,
                        tuning: activeTuning
                    )
                }
                .frame(width: w, height: stripHeight)
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(height: scaledBeamHeight(beamVisualTuning.beamOuterHeight))
        .onChange(of: marginRounded) { _, _ in
            guard !suppressImpactBursts else { return }
            lastImpactAtWall = Date().timeIntervalSinceReferenceDate
        }
    }

    private func scaledProductionTuning(motionScale: Double, impactScale: CGFloat) -> EnergyBeamVisualTuning {
        guard motionScale < 0.999 || impactScale < 0.999 else { return beamVisualTuning }
        let m = max(0, motionScale)
        let t = beamVisualTuning
        let i = Double(impactScale)
        return .init(
            label: "scaled(m=\(String(format: "%.2f", m)))",
            timelineInterval: t.timelineInterval,
            lanesPerSide: t.lanesPerSide,
            sparkCount: t.sparkCount,
            tendrilSegmentMin: t.tendrilSegmentMin,
            tendrilSegmentMax: t.tendrilSegmentMax,
            forkProbabilityThreshold: t.forkProbabilityThreshold,
            flowStreakCount: t.flowStreakCount,
            flowPacketCount: t.flowPacketCount,
            reflectFragmentCount: t.reflectFragmentCount,
            beamOuterHeight: t.beamOuterHeight,
            referenceFloor: t.referenceFloor,
            referenceScaleMultiplier: t.referenceScaleMultiplier,
            referenceScaleMinimum: t.referenceScaleMinimum,
            marginMaxHorizontalFraction: t.marginMaxHorizontalFraction,
            collisionClampMinFraction: t.collisionClampMinFraction,
            collisionClampMaxFraction: t.collisionClampMaxFraction,
            wDrawIdleMultiplier: t.wDrawIdleMultiplier * m,
            wDrawImpactExtra: t.wDrawImpactExtra * m,
            impactBoostWindowSeconds: t.impactBoostWindowSeconds,
            impactBoostPeakExponent: t.impactBoostPeakExponent,
            impactBoostShimmerAmplitude: t.impactBoostShimmerAmplitude * i,
            impactBoostShimmerFrequency: t.impactBoostShimmerFrequency * m,
            useProportionalHorizontalPads: t.useProportionalHorizontalPads,
            horizontalBandLeftEdgeFraction: t.horizontalBandLeftEdgeFraction,
            horizontalBandRightEdgeFraction: t.horizontalBandRightEdgeFraction,
            leftPadLeadingOffset: t.leftPadLeadingOffset,
            rightPadTrailingExtra: t.rightPadTrailingExtra,
            impactVisualScale: t.impactVisualScale * CGFloat(i),
            masterStrokeOpacity: t.masterStrokeOpacity,
            globalBrightImpactCoefficient: t.globalBrightImpactCoefficient,
            flareMulBase: t.flareMulBase,
            flareMulImpactCoefficient: t.flareMulImpactCoefficient,
            burstScaleBase: t.burstScaleBase,
            burstScaleImpactCoefficient: t.burstScaleImpactCoefficient,
            flowMulBase: t.flowMulBase * CGFloat(m),
            flowMulImpactCoefficient: t.flowMulImpactCoefficient * CGFloat(m),
            idleGlowBase: t.idleGlowBase,
            idleGlowSeedStride: t.idleGlowSeedStride,
            idleGlowSineAFrequency: t.idleGlowSineAFrequency * m,
            idleGlowSineAAmplitude: t.idleGlowSineAAmplitude,
            idleGlowSineBFrequency: t.idleGlowSineBFrequency * m,
            idleGlowSineBAmplitude: t.idleGlowSineBAmplitude,
            idleGlowSineCFrequency: t.idleGlowSineCFrequency * m,
            idleGlowSineCAmplitude: t.idleGlowSineCAmplitude,
            idleGlowSteppedMultiplier: t.idleGlowSteppedMultiplier,
            idleGlowSteppedWallFrequency: t.idleGlowSteppedWallFrequency * m,
            lanePhaseSpeedMin: t.lanePhaseSpeedMin * m,
            lanePhaseSpeedSpan: t.lanePhaseSpeedSpan * m,
            lanePhaseLaneWeight: t.lanePhaseLaneWeight,
            lanePhaseSeedWeight: t.lanePhaseSeedWeight,
            amplitudeCalmBase: t.amplitudeCalmBase * CGFloat(m),
            amplitudeCalmSpan: t.amplitudeCalmSpan * CGFloat(m),
            amplitudeBurstBase: t.amplitudeBurstBase * CGFloat(m),
            amplitudeBurstWobble: t.amplitudeBurstWobble * CGFloat(m),
            amplitudeChaosBase: t.amplitudeChaosBase * CGFloat(m),
            amplitudeChaosSpan: t.amplitudeChaosSpan * CGFloat(m),
            helixRunnerCount: t.helixRunnerCount,
            offAxisRunnerCount: t.offAxisRunnerCount,
            coreSpineResampleSteps: t.coreSpineResampleSteps,
            coreSpineKnotCount: t.coreSpineKnotCount
        )
    }

    private func resolveCollisionX(
        width w: CGFloat,
        tuning: EnergyBeamVisualTuning,
        introActive: Bool,
        wall: TimeInterval
    ) -> CGFloat {
        EnergyBeamHeroCollisionLayout.centerX(
            width: w,
            marginPrecise: marginPrecise,
            referenceBattleValue: referenceBattleValue,
            tuning: tuning,
            pinToCenterDuringIntro: introActive && pinCollisionToCenterDuringIntro,
            wall: wall
        )
    }

    /// Short intensity pulse after `marginRounded` flips; scales chaos in `drawBeam` (0…~1).
    private func impactBoost(atWallTime wall: TimeInterval, tuning: EnergyBeamVisualTuning) -> CGFloat {
        let elapsed = CGFloat(wall - lastImpactAtWall)
        let window = tuning.impactBoostWindowSeconds
        guard elapsed >= 0, elapsed < window else { return 0 }
        let t = 1 - (elapsed / window)
        let peak = pow(max(0, t), tuning.impactBoostPeakExponent)
        let shimmer = 1 + tuning.impactBoostShimmerAmplitude * sin(Double(elapsed) * tuning.impactBoostShimmerFrequency)
        return CGFloat(peak * shimmer)
    }

}

// MARK: - Deterministic jitter + Canvas renderer

/// All procedural beam **drawing** lives here: deterministic noise, geometry, and `GraphicsContext` strokes.
/// Call flow: `ProceduralEnergyBeamView` → `drawBeam` → helpers (`organicTendrilPoints`, collision draws, etc.).
/// Tuning: shared knobs live in `EnergyBeamVisualTuning`; static helpers read `EnergyBeamBeamDrawingActiveTuning` during `drawBeam`.
private enum ProceduralBeamRenderer {
    /// Stable pseudorandom in [0,1) from lane/step/salt (replaces `random()` for reproducible Canvas).
    private static func deterministic01(lane: Int, step: Int, salt: Int) -> CGFloat {
        let hi = UInt32(bitPattern: Int32(truncatingIfNeeded: lane &* 12_959 + step &* 28_957 + salt &* 48_049))
        let lo = hi &* 2_743_873 &+ UInt32(truncatingIfNeeded: lane ^ step ^ salt)
        let mix = UInt64(hi ^ lo)
        let s = UInt32(truncatingIfNeeded: mix ^ (mix >> 32))
        return CGFloat(Double(s % 982_447) / 982_446)
    }

    /// Per-frame brightness multiplier for idle shimmer (uses `wall` clock + `seed`).
    private static func idleGlowFactor(wall: TimeInterval, seed: Int) -> CGFloat {
        let t = EnergyBeamBeamDrawingActiveTuning.value
        let s = Double(seed % 13) * t.idleGlowSeedStride
        let a = sin(wall * t.idleGlowSineAFrequency + s) * Double(t.idleGlowSineAAmplitude)
        let b = sin(wall * t.idleGlowSineBFrequency + s * 3) * Double(t.idleGlowSineBAmplitude)
        let c = sin(wall * t.idleGlowSineCFrequency + Double((seed / 3) & 7)) * Double(t.idleGlowSineCAmplitude)
        let stepped = (floor(wall * t.idleGlowSteppedWallFrequency + s).truncatingRemainder(dividingBy: 2)) * Double(t.idleGlowSteppedMultiplier)
        return CGFloat(Double(t.idleGlowBase) + a + b + c + stepped)
    }

    /// Phase driver for fork wiggle; higher `wall` speeds spin along auxiliary paths.
    private static func lanePhase(lane: Int, wall: TimeInterval, seed: Int) -> Double {
        let t = EnergyBeamBeamDrawingActiveTuning.value
        let speed = t.lanePhaseSpeedMin + Double(deterministic01(lane: lane, step: 0, salt: seed)) * t.lanePhaseSpeedSpan
        let offset = Double(lane) * t.lanePhaseLaneWeight + Double(seed & 0xff) * t.lanePhaseSeedWeight
        return wall * .pi * 2 * speed + offset
    }

    /// Shapes per-lane vertical “breathing” along the beam; tweak multipliers for calmer vs wild tendrils.
    private static func amplitudeEnvelope(t: CGFloat, lane: Int, salt: Int, phase: Double) -> CGFloat {
        let k = EnergyBeamBeamDrawingActiveTuning.value
        let calm = k.amplitudeCalmBase + k.amplitudeCalmSpan * pow(sin(Double(t) * .pi), 2)
        let burst = k.amplitudeBurstBase + k.amplitudeBurstWobble * abs(sin(phase * 10.35 + Double(t) * 7.1))
        let r = deterministic01(lane: lane, step: 404, salt: salt)
        let chaosW = k.amplitudeChaosBase + CGFloat(r) * k.amplitudeChaosSpan
        return calm * CGFloat(burst) * chaosW
    }

    /// Builds one polyline of “electric tendril” points from `startX`…`endX`; `wDraw` scrolls texture toward collision.
    private static func organicTendrilPoints(
        startX: CGFloat,
        endX: CGFloat,
        midY: CGFloat,
        lane: Int,
        salt: Int,
        wDraw: TimeInterval,
        baseSpread: CGFloat,
        isUserSide: Bool,
        impact: CGFloat
    ) -> [CGPoint] {
        guard endX > startX + 2 else { return [] }
        let segMin = EnergyBeamBeamDrawingActiveTuning.value.tendrilSegmentMin
        let segMax = EnergyBeamBeamDrawingActiveTuning.value.tendrilSegmentMax
        let segN = segMin + Int(deterministic01(lane: lane, step: 3, salt: salt) * CGFloat(segMax - segMin))
        let span = endX - startX

        let early = deterministic01(lane: lane, step: 88, salt: salt)
        let spanScale: CGFloat = early < 0.18 ? (0.35 + early * 1.1) : (0.92 + early * 0.08)
        let effectiveEnd = startX + span * min(1, spanScale)

        let advect = wDraw * (7.2 + Double(impact) * 12.8)
        let laneJ = Double(lane) * 0.73 + Double(salt & 31) * 0.04

        var pts: [CGPoint] = []
        for i in 0 ... segN {
            let t = CGFloat(i) / CGFloat(segN)
            let xi = Double(t)
            let waveCoord = isUserSide ? xi : (1 - xi)
            // Spatial phase travels toward collision as `wDraw` increases (positive x advection on user side).
            let spatial = waveCoord * 26 * Double.pi - advect + laneJ
            let compress = pow(isUserSide ? xi : (1 - xi), 1.35)
            let bunch = 0.7 + 0.7 * (1 - compress)
            let r = deterministic01(lane: lane, step: i, salt: salt)
            let env = (0.36 + 0.48 * pow(sin(xi * .pi), 0.05)) * (0.62 + CGFloat(r) * 0.34) * CGFloat(bunch)
            let spread = baseSpread * env * (0.82 + CGFloat(impact) * 0.16 * CGFloat(1 - compress))

            let xLinear = startX + (effectiveEnd - startX) * t
            let xRipple = CGFloat(sin(spatial * 0.38 + Double(i) * 0.17)) * 30.55 * CGFloat(1 - compress)
            let x = xLinear + xRipple

            let jolt = (r - 0.001) * 0.4 * spread
            let y1 = sin(spatial * 0.9) + 0.35 * sin(spatial * 1.45 + 1.1)
            let y2 = cos(spatial * 1.06 + Double(lane))
            let y = midY + CGFloat(jolt) + CGFloat(y1 * 0.2 + y2 * 0.2) * spread

            pts.append(CGPoint(x: x, y: y))
        }
        return pts
    }

    /// Converts point array to a `Path` mixing straight segments and gentle quad curves (randomized per segment).
    private static func pathFromPointsMixedCurve(_ pts: [CGPoint], lane: Int, salt: Int) -> Path {
        guard pts.count >= 2 else { return Path() }
        var path = Path()
        path.move(to: pts[0])
        for i in 1 ..< pts.count {
            let prev = pts[i - 1]
            let cur = pts[i]
            let r = deterministic01(lane: lane, step: i + 200, salt: salt)
            if r > 0.58 {
                path.addLine(to: cur)
            } else {
                let mx = (prev.x + cur.x) * 0.5
                let my = (prev.y + cur.y) * 0.5
                let ox = CGFloat(sin(Double(r) * 6.2 + Double(i))) * 2.8
                let oy = CGFloat(cos(Double(r) * 4.1 + Double(i * 3))) * 10.0
                path.addQuadCurve(to: cur, control: CGPoint(x: mx + ox, y: my + oy))
            }
        }
        return path
    }

    /// Short branching polyline from a tendril anchor toward the collision edge (optional per lane).
    private static func forkPath(
        from anchor: CGPoint,
        endClampX: CGFloat,
        lane: Int,
        salt: Int,
        wDraw: TimeInterval
    ) -> Path {
        let phase = lanePhase(lane: lane | 0x50, wall: wDraw, seed: salt)
        var p = Path()
        p.move(to: anchor)
        var x = anchor.x
        var y = anchor.y
        for k in 1 ... 5 {
            let t = CGFloat(k) / 5
            let stepX = CGFloat(deterministic01(lane: lane, step: 300 + k, salt: salt)) * 4.2 + 1.4
            x = min(x + stepX, endClampX)
            y += CGFloat(sin(phase + Double(k) * 1.05)) * 3.1 * t
            p.addLine(to: CGPoint(x: x, y: y))
        }
        return p
    }

    /// Master Canvas pass: lanes, cores, helix runners, flow streaks, packets, collision strokes, reflections.
    fileprivate static func drawBeam(
        context: inout GraphicsContext,
        size: CGSize,
        collisionX: CGFloat,
        midY: CGFloat,
        wall: TimeInterval,
        wDraw: TimeInterval,
        rawImpact: CGFloat,
        seed: Int,
        tuning: EnergyBeamVisualTuning
    ) {
        let savedTuning = EnergyBeamBeamDrawingActiveTuning.value
        EnergyBeamBeamDrawingActiveTuning.value = tuning
        defer { EnergyBeamBeamDrawingActiveTuning.value = savedTuning }

        let impact = min(1, max(0, rawImpact * tuning.impactVisualScale))
        let w = size.width
        let globalBright = 1 + impact * tuning.globalBrightImpactCoefficient
        let flicker = idleGlowFactor(wall: wall, seed: seed) * CGFloat(globalBright)
        let flareMul = tuning.flareMulBase + CGFloat(impact) * tuning.flareMulImpactCoefficient
        let burstScale: CGFloat = tuning.burstScaleBase + impact * tuning.burstScaleImpactCoefficient

        let leftPad: CGFloat
        let rightPad: CGFloat
        if tuning.useProportionalHorizontalPads {
            leftPad = w * tuning.horizontalBandLeftEdgeFraction
            rightPad = w * tuning.horizontalBandRightEdgeFraction
        } else {
            leftPad = tuning.leftPadLeadingOffset
            rightPad = w + tuning.rightPadTrailingExtra
        }
        let gap: CGFloat = 0.0001

        let flowMul = tuning.flowMulBase + CGFloat(impact) * tuning.flowMulImpactCoefficient

        // User side (cyan / electric teal)
        for lane in 0 ..< tuning.lanesPerSide {
            let spread: CGFloat = 10.1 + CGFloat(lane % 2) * 6.25
            let pts = organicTendrilPoints(
                startX: leftPad,
                endX: collisionX - gap,
                midY: midY,
                lane: lane,
                salt: seed,
                wDraw: wDraw,
                baseSpread: spread,
                isUserSide: true,
                impact: impact
            )
            let earlyFade = deterministic01(lane: lane, step: 88, salt: seed) < 0.22
            let opacityScale: CGFloat = earlyFade
                ? 0.42 + deterministic01(lane: lane, step: 89, salt: seed) * 0.32
                : 1
            let widthJitter = 0.8 + deterministic01(lane: lane, step: 90, salt: seed) * 0.22
            let mainPath = pathFromPointsMixedCurve(pts, lane: lane, salt: seed)
            layeredTendrilStrokes(
                context: &context,
                path: mainPath,
                wideColor: BeamTeamColors.userBloom,
                midTint: BeamTeamColors.userMid,
                deepTint: BeamTeamColors.userDeep,
                coreHot: BeamTeamColors.userCore,
                flicker: flicker,
                impact: impact,
                plusMode: false,
                opacityScale: opacityScale * CGFloat(globalBright),
                widthScale: widthJitter * burstScale
            )

            if deterministic01(lane: lane, step: 77, salt: seed) > tuning.forkProbabilityThreshold,
               let anchor = pts.dropLast(Swift.max(0, pts.count / 3)).last {
                let fk = forkPath(from: anchor, endClampX: collisionX - 1.5, lane: lane, salt: seed, wDraw: wDraw)
                layeredTendrilStrokes(
                    context: &context,
                    path: fk,
                    wideColor: BeamTeamColors.userBloom,
                    midTint: BeamTeamColors.userMid,
                    deepTint: BeamTeamColors.userDeep,
                    coreHot: BeamTeamColors.userCore,
                    flicker: flicker,
                    impact: impact * 0.85,
                    plusMode: false,
                    opacityScale: opacityScale * 0.42 * CGFloat(globalBright),
                    widthScale: widthJitter * 0.72 * burstScale
                )
            }
        }

        // Opponent side (orange / ember)
        for lane in 0 ..< tuning.lanesPerSide {
            let laneSalt = lane | 0x2000
            let spread: CGFloat = 5.2 + CGFloat(lane % 5) * 2.35
            let pts = organicTendrilPoints(
                startX: collisionX + gap,
                endX: rightPad,
                midY: midY,
                lane: laneSalt,
                salt: seed,
                wDraw: wDraw,
                baseSpread: spread,
                isUserSide: false,
                impact: impact
            )
            let earlyFade = deterministic01(lane: laneSalt, step: 88, salt: seed) < 0.2
            let opacityScale: CGFloat = earlyFade
                ? 0.45 + deterministic01(lane: laneSalt, step: 89, salt: seed) * 0.28
                : 1
            let widthJitter = 0.9 + deterministic01(lane: laneSalt, step: 90, salt: seed) * 0.28
            let mainPath = pathFromPointsMixedCurve(pts, lane: laneSalt, salt: seed)
            layeredTendrilStrokes(
                context: &context,
                path: mainPath,
                wideColor: BeamTeamColors.oppBloom,
                midTint: BeamTeamColors.oppMid,
                deepTint: BeamTeamColors.oppEmber,
                coreHot: BeamTeamColors.oppCore,
                flicker: flicker,
                impact: impact,
                plusMode: true,
                opacityScale: opacityScale * CGFloat(globalBright),
                widthScale: widthJitter * burstScale
            )

            if deterministic01(lane: laneSalt, step: 77, salt: seed) > tuning.forkProbabilityThreshold,
               let anchor = pts.dropLast(Swift.max(0, pts.count / 3)).last {
                let fk = forkPath(from: anchor, endClampX: rightPad, lane: laneSalt, salt: seed, wDraw: wDraw)
                layeredTendrilStrokes(
                    context: &context,
                    path: fk,
                    wideColor: BeamTeamColors.oppBloom,
                    midTint: BeamTeamColors.oppMid,
                    deepTint: BeamTeamColors.oppEmber,
                    coreHot: BeamTeamColors.oppCore,
                    flicker: flicker,
                    impact: impact * 0.82,
                    plusMode: true,
                    opacityScale: opacityScale * 0.4 * CGFloat(globalBright),
                    widthScale: widthJitter * 0.7 * burstScale
                )
            }
        }

        drawBeamHelixAdvection(
            context: &context,
            from: leftPad,
            to: collisionX - 2,
            midY: midY,
            wDraw: wDraw,
            impact: impact,
            tintA: BeamTeamColors.userCore,
            tintB: BeamTeamColors.userBloom,
            isUser: true,
            seed: seed
        )
        drawBeamHelixAdvection(
            context: &context,
            from: collisionX + 2,
            to: rightPad,
            midY: midY,
            wDraw: wDraw,
            impact: impact,
            tintA: BeamTeamColors.oppCore,
            tintB: BeamTeamColors.oppEmber,
            isUser: false,
            seed: seed ^ 0x2f1
        )
        drawOffAxisRunners(
            context: &context,
            from: leftPad,
            to: collisionX - 2,
            midY: midY,
            wDraw: wDraw,
            impact: impact,
            tint: BeamTeamColors.userBloom,
            isUser: true,
            seed: seed
        )
        drawOffAxisRunners(
            context: &context,
            from: collisionX + 2,
            to: rightPad,
            midY: midY,
            wDraw: wDraw,
            impact: impact,
            tint: BeamTeamColors.oppEmber,
            isUser: false,
            seed: seed ^ 0x591
        )

        coreSpineAdvected(
            context: &context,
            from: leftPad,
            to: collisionX - 2,
            midY: midY,
            wDraw: wDraw,
            seed: seed,
            flicker: flicker,
            impact: impact,
            tint: BeamTeamColors.userBloom,
            isUser: true
        )
        coreSpineAdvected(
            context: &context,
            from: collisionX + 2,
            to: rightPad,
            midY: midY,
            wDraw: wDraw,
            seed: seed,
            flicker: flicker,
            impact: impact,
            tint: BeamTeamColors.oppBloom,
            isUser: false
        )

        drawDirectionalFlowStreaks(
            context: &context,
            midY: midY,
            beamH: size.height,
            leftPad: leftPad,
            rightPad: rightPad,
            collisionX: collisionX,
            wDraw: wDraw,
            impact: impact,
            flowMul: flowMul,
            seed: seed
        )
        drawTravelingPackets(
            context: &context,
            midY: midY,
            leftPad: leftPad,
            rightPad: rightPad,
            collisionX: collisionX,
            wDraw: wDraw,
            impact: impact,
            flowMul: flowMul,
            seed: seed
        )

        drawCollisionEnergy(
            context: &context,
            collisionX: collisionX,
            midY: midY,
            beamH: size.height,
            flicker: flicker,
            impact: impact,
            flareMul: flareMul,
            wDraw: wDraw,
            wall: wall,
            sparkBoost: CGFloat(impact * 36 + 14),
            seed: seed
        )
        drawReflectedFragments(
            context: &context,
            collisionX: collisionX,
            midY: midY,
            leftPad: leftPad,
            rightPad: rightPad,
            wDraw: wDraw,
            impact: impact,
            seed: seed
        )
    }

    /// Spiral / fireball-like strokes riding beside the beam core, advecting toward impact (`wDraw`-driven).
    private static func drawBeamHelixAdvection(
        context: inout GraphicsContext,
        from x0: CGFloat,
        to x1: CGFloat,
        midY: CGFloat,
        wDraw: TimeInterval,
        impact: CGFloat,
        tintA: Color,
        tintB: Color,
        isUser: Bool,
        seed: Int
    ) {
        guard x1 > x0 + 8 else { return }
        let n = EnergyBeamBeamDrawingActiveTuning.value.helixRunnerCount
        let span = x1 - x0
        let advect = wDraw * (0.56 + Double(impact) * 0.26)
        let radiusBase: CGFloat = 3.2 + impact * 9.2
        for i in 0 ..< n {
            let frac = (advect + Double(i) * 0.17).truncatingRemainder(dividingBy: 1)
            let t = isUser ? frac : (1 - frac)
            let x = x0 + CGFloat(t) * span
            let helix = sin((Double(t) * 17.5 - wDraw * 9.1) + Double(i) * 1.3)
            let y = midY + CGFloat(helix) * (radiusBase * (0.75 + CGFloat(i % 3) * 0.18))

            var tail = Path()
            let back = isUser ? -1 : 1
            tail.move(to: CGPoint(x: x + CGFloat(back) * 14, y: y))
            tail.addQuadCurve(
                to: CGPoint(x: x, y: y),
                control: CGPoint(x: x + CGFloat(back) * 7, y: y + CGFloat(cos(Double(i) + wDraw * 4.3)) * 3.2)
            )
            context.blendMode = .plusLighter
            context.stroke(tail, with: .color(tintB.opacity(0.26 + Double(impact) * 0.46)), style: StrokeStyle(lineWidth: 2.1 + impact * 2.6, lineCap: .round, lineJoin: .round))
            context.stroke(tail, with: .color(tintA.opacity(0.2 + Double(impact) * 0.34)), style: StrokeStyle(lineWidth: 1.0 + impact * 1.25, lineCap: .round, lineJoin: .round))

            let r: CGFloat = 1.3 + impact * 2.1
            let orb = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            context.fill(orb, with: .color(Color.white.opacity(0.62 + Double(impact) * 0.25)))
            context.fill(orb, with: .color(tintA.opacity(0.54)))

            if deterministic01(lane: 7600 + i, step: seed & 0xff, salt: seed) > 0.66 {
                var spark = Path()
                spark.move(to: CGPoint(x: x, y: y))
                spark.addLine(to: CGPoint(x: x + CGFloat(back) * (4 + impact * 10), y: y + CGFloat(sin(wDraw * 15 + Double(i))) * (2 + impact * 4)))
                context.stroke(spark, with: .color(Color.white.opacity(0.35 + Double(impact) * 0.4)), style: StrokeStyle(lineWidth: 0.9 + impact * 1.1, lineCap: .round))
            }
        }
    }

    /// Off-axis lightning arcs that peel away then curl back toward the beam center before impact.
    private static func drawOffAxisRunners(
        context: inout GraphicsContext,
        from x0: CGFloat,
        to x1: CGFloat,
        midY: CGFloat,
        wDraw: TimeInterval,
        impact: CGFloat,
        tint: Color,
        isUser: Bool,
        seed: Int
    ) {
        guard x1 > x0 + 20 else { return }
        let span = x1 - x0
        let n = EnergyBeamBeamDrawingActiveTuning.value.offAxisRunnerCount
        for i in 0 ..< n {
            let frac = (wDraw * (0.38 + Double(impact) * 0.18) + Double(i) * 0.19).truncatingRemainder(dividingBy: 1)
            let t = isUser ? frac : (1 - frac)
            let x = x0 + CGFloat(t) * span
            let side = deterministic01(lane: 7900 + i, step: seed & 0xff, salt: seed) > 0.5 ? 1 : -1
            let off = (6 + impact * 16) * CGFloat(side)
            let y = midY + off + CGFloat(sin(wDraw * 9.2 + Double(i) * 1.37)) * (3 + impact * 5)

            var p = Path()
            p.move(to: CGPoint(x: x, y: y))
            let dx = isUser ? 18 : -18
            let pullInY = midY + CGFloat(sin(wDraw * 6.1 + Double(i))) * 2.6
            p.addQuadCurve(
                to: CGPoint(x: x + CGFloat(dx), y: pullInY),
                control: CGPoint(x: x + CGFloat(dx) * 0.5, y: y + CGFloat(side) * (4 + impact * 6))
            )
            context.blendMode = .plusLighter
            context.stroke(p, with: .color(tint.opacity(0.24 + Double(impact) * 0.4)), style: StrokeStyle(lineWidth: 1.6 + impact * 2.0, lineCap: .round, lineJoin: .round))
            context.stroke(p, with: .color(Color.white.opacity(0.22 + Double(impact) * 0.25)), style: StrokeStyle(lineWidth: 0.8 + impact, lineCap: .round, lineJoin: .round))

            if deterministic01(lane: 7950 + i, step: seed, salt: seed) > 0.38 {
                var s = Path()
                s.move(to: CGPoint(x: x + CGFloat(dx) * 0.7, y: pullInY))
                s.addLine(to: CGPoint(
                    x: x + CGFloat(dx) * 0.7 + CGFloat(isUser ? -1 : 1) * (7 + impact * 14),
                    y: pullInY + CGFloat(side) * (2 + impact * 8)
                ))
                context.stroke(s, with: .color(Color.white.opacity(0.24 + Double(impact) * 0.4)), style: StrokeStyle(lineWidth: 0.9 + impact * 1.25, lineCap: .round))
            }
        }
    }

    /// Short bright streak segments sliding horizontally toward the collision on each side.
    private static func drawDirectionalFlowStreaks(
        context: inout GraphicsContext,
        midY: CGFloat,
        beamH: CGFloat,
        leftPad: CGFloat,
        rightPad: CGFloat,
        collisionX: CGFloat,
        wDraw: TimeInterval,
        impact: CGFloat,
        flowMul: CGFloat,
        seed: Int
    ) {
        let speed = (38 + Double(impact) * 42) * Double(flowMul)
        let n = EnergyBeamBeamDrawingActiveTuning.value.flowStreakCount
        for i in 0 ..< n {
            let yJ = (deterministic01(lane: 400 + i, step: 0, salt: seed) - 0.5) * beamH * 0.2
            let span = max(12, collisionX - leftPad - 10)
            let frac = (wDraw * speed * 0.085 + Double(i) * 0.17).truncatingRemainder(dividingBy: 1)
            let head = leftPad + CGFloat(frac) * span
            let segLen: CGFloat = 14 + CGFloat(impact) * 18
            let tail = max(leftPad + 2, head - segLen)
            let clipHead = min(head, collisionX - 2)
            guard clipHead > tail + 3 else { continue }
            var lp = Path()
            lp.move(to: CGPoint(x: tail, y: midY + yJ))
            lp.addLine(to: CGPoint(x: clipHead, y: midY + yJ))
            let near = 1 - Double((collisionX - clipHead) / max(40, span))
            let alpha = 0.18 + near * 0.42 + Double(impact) * 0.28
            context.blendMode = .plusLighter
            context.stroke(
                lp,
                with: .color(BeamTeamColors.userCore.opacity(alpha)),
                style: StrokeStyle(lineWidth: 1.8 + CGFloat(impact) * 2.2, lineCap: .round)
            )
        }

        for i in 0 ..< n {
            let yJ = (deterministic01(lane: 500 + i, step: 0, salt: seed) - 0.5) * beamH * 0.2
            let span = max(12, rightPad - collisionX - 10)
            let frac = (wDraw * speed * 0.085 + Double(i + 19) * 0.19).truncatingRemainder(dividingBy: 1)
            let head = rightPad - CGFloat(frac) * span
            let segLen: CGFloat = 14 + CGFloat(impact) * 18
            let tail = min(rightPad - 2, head + segLen)
            let clipHead = max(head, collisionX + 2)
            guard tail > clipHead + 3 else { continue }
            var rp = Path()
            rp.move(to: CGPoint(x: tail, y: midY + yJ))
            rp.addLine(to: CGPoint(x: clipHead, y: midY + yJ))
            let near = 1 - Double((clipHead - collisionX) / max(40, span))
            let alpha = 0.2 + near * 0.45 + Double(impact) * 0.28
            context.blendMode = .plusLighter
            context.stroke(
                rp,
                with: .color(BeamTeamColors.oppCore.opacity(alpha)),
                style: StrokeStyle(lineWidth: 1.8 + CGFloat(impact) * 2.2, lineCap: .round)
            )
        }
    }

    /// “Packets” (lines + small orbs + tails) moving inward; near collision they burst into fragment strokes.
    private static func drawTravelingPackets(
        context: inout GraphicsContext,
        midY: CGFloat,
        leftPad: CGFloat,
        rightPad: CGFloat,
        collisionX: CGFloat,
        wDraw: TimeInterval,
        impact: CGFloat,
        flowMul: CGFloat,
        seed: Int
    ) {
        let n = EnergyBeamBeamDrawingActiveTuning.value.flowPacketCount
        let speedL = (0.34 + Double(impact) * 0.28) * Double(flowMul)
        for i in 0 ..< n {
            let span = max(14, collisionX - leftPad - 12)
            let frac = (wDraw * speedL + Double(i) * 0.31).truncatingRemainder(dividingBy: 1)
            let cx = leftPad + CGFloat(frac) * span
            let helical = sin(wDraw * 8.4 + Double(i) * 1.3 + Double(cx - leftPad) * 0.035)
            let yOff = (deterministic01(lane: 800 + i, step: 1, salt: seed) - 0.5) * 8 + CGFloat(helical) * (2.8 + impact * 2.2)
            let hitZone = collisionX - cx
            if hitZone < 14 {
                let burst = Int(2 + (seed + i) % 3)
                for b in 0 ..< burst {
                    let ang = -.pi * 0.35 + CGFloat(deterministic01(lane: 850 + b, step: i, salt: seed)) * 0.55
                    let L: CGFloat = 5 + CGFloat(impact) * 12
                    var s = Path()
                    s.move(to: CGPoint(x: collisionX - 2, y: midY + yOff))
                    s.addLine(to: CGPoint(x: collisionX - 2 + cos(Double(ang)) * Double(L), y: midY + yOff + sin(Double(ang)) * Double(L)))
                    context.blendMode = .plusLighter
                    context.stroke(s, with: .color(BeamTeamColors.userBloom.opacity(0.35 + Double(impact) * 0.4)), style: StrokeStyle(lineWidth: 1.4 + CGFloat(impact), lineCap: .round))
                }
                continue
            }
            var tail = Path()
            tail.move(to: CGPoint(x: cx - 13, y: midY + yOff))
            tail.addLine(to: CGPoint(x: cx - 2, y: midY + yOff))
            context.blendMode = .plusLighter
            context.stroke(tail, with: .color(BeamTeamColors.userBloom.opacity(0.22 + Double(impact) * 0.24)), style: StrokeStyle(lineWidth: 2.6 + CGFloat(impact) * 1.4, lineCap: .round))

            var ln = Path()
            ln.move(to: CGPoint(x: cx - 5, y: midY + yOff))
            ln.addLine(to: CGPoint(x: cx, y: midY + yOff))
            context.stroke(ln, with: .color(Color.white.opacity(0.45 + Double(impact) * 0.35)), style: StrokeStyle(lineWidth: 2 + CGFloat(impact) * 1.6, lineCap: .round))
            context.stroke(ln, with: .color(BeamTeamColors.userBloom.opacity(0.55)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            let orbR: CGFloat = 1.55 + impact * 1.9
            let orb = Path(ellipseIn: CGRect(x: cx - orbR, y: midY + yOff - orbR, width: orbR * 2, height: orbR * 2))
            context.fill(orb, with: .color(Color.white.opacity(0.78 + Double(impact) * 0.14)))
            context.fill(orb, with: .color(BeamTeamColors.userCore.opacity(0.52)))
        }

        let speedR = (0.35 + Double(impact) * 0.28) * Double(flowMul)
        for i in 0 ..< n {
            let span = max(14, rightPad - collisionX - 12)
            let frac = (wDraw * speedR + Double(i + 5) * 0.33).truncatingRemainder(dividingBy: 1)
            let cx = rightPad - CGFloat(frac) * span
            let helical = sin(wDraw * 8.1 + Double(i + 9) * 1.25 + Double(rightPad - cx) * 0.035)
            let yOff = (deterministic01(lane: 900 + i, step: 1, salt: seed) - 0.5) * 8 + CGFloat(helical) * (2.8 + impact * 2.2)
            let hitZone = cx - collisionX
            if hitZone < 14 {
                let burst = Int(2 + (seed + i * 2) % 3)
                for b in 0 ..< burst {
                    let ang = .pi * 0.35 + CGFloat(deterministic01(lane: 950 + b, step: i, salt: seed)) * 0.55
                    let L: CGFloat = 5 + CGFloat(impact) * 12
                    var s = Path()
                    s.move(to: CGPoint(x: collisionX + 2, y: midY + yOff))
                    s.addLine(to: CGPoint(x: collisionX + 2 + cos(Double(ang)) * Double(L), y: midY + yOff + sin(Double(ang)) * Double(L)))
                    context.blendMode = .plusLighter
                    context.stroke(s, with: .color(BeamTeamColors.oppEmber.opacity(0.38 + Double(impact) * 0.42)), style: StrokeStyle(lineWidth: 1.4 + CGFloat(impact), lineCap: .round))
                }
                continue
            }
            var tail = Path()
            tail.move(to: CGPoint(x: cx + 13, y: midY + yOff))
            tail.addLine(to: CGPoint(x: cx + 2, y: midY + yOff))
            context.blendMode = .plusLighter
            context.stroke(tail, with: .color(BeamTeamColors.oppEmber.opacity(0.24 + Double(impact) * 0.26)), style: StrokeStyle(lineWidth: 2.6 + CGFloat(impact) * 1.4, lineCap: .round))

            var ln = Path()
            ln.move(to: CGPoint(x: cx + 5, y: midY + yOff))
            ln.addLine(to: CGPoint(x: cx, y: midY + yOff))
            context.stroke(ln, with: .color(Color.white.opacity(0.42 + Double(impact) * 0.32)), style: StrokeStyle(lineWidth: 2 + CGFloat(impact) * 1.6, lineCap: .round))
            context.stroke(ln, with: .color(BeamTeamColors.oppCore.opacity(0.52)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            let orbR: CGFloat = 1.55 + impact * 1.9
            let orb = Path(ellipseIn: CGRect(x: cx - orbR, y: midY + yOff - orbR, width: orbR * 2, height: orbR * 2))
            context.fill(orb, with: .color(Color.white.opacity(0.76 + Double(impact) * 0.14)))
            context.fill(orb, with: .color(BeamTeamColors.oppCore.opacity(0.55)))
        }
    }

    /// Stroke-only collision: white-hot threads, cyan back-scatter, orange wisps, diagonal sparks.
    /// No filled plume/seam/rects — impact reads from light only. Scale literals here for “bigger wall.”
    private static func drawCollisionEnergy(
        context: inout GraphicsContext,
        collisionX: CGFloat,
        midY: CGFloat,
        beamH: CGFloat,
        flicker: CGFloat,
        impact: CGFloat,
        flareMul: CGFloat,
        wDraw: TimeInterval,
        wall: TimeInterval,
        sparkBoost: CGFloat,
        seed: Int
    ) {
        let idlePhase = wDraw * .pi * 2.6 + wall * .pi * 0.28
        let flashPulse = sin(wall * 24 + Double(seed & 63)) > 0.94 ? 1.28 : 1.0
        context.blendMode = .plusLighter

        let wallHalfH = beamH * (0.26 + impact * 0.17)
        for side in 0 ... 1 {
            let isUser = side == 0
            let sign: CGFloat = isUser ? -1 : 1
            let tintA = isUser ? BeamTeamColors.userBloom : BeamTeamColors.oppEmber
            let tintB = isUser ? BeamTeamColors.userCore : BeamTeamColors.oppCore
            for i in 0 ..< 10 {
                let u = CGFloat(deterministic01(lane: 4700 + side * 20 + i, step: seed, salt: seed))
                let reach: CGFloat = 16 + CGFloat(i) * 7 + impact * 34
                let ySpan = wallHalfH * (0.25 + u * 0.65)
                var shell = Path()
                shell.move(to: CGPoint(x: collisionX + sign * 0.5, y: midY - ySpan))
                shell.addQuadCurve(
                    to: CGPoint(x: collisionX + sign * (reach + 2), y: midY),
                    control: CGPoint(x: collisionX + sign * (reach * 0.48), y: midY - ySpan * 1.05)
                )
                shell.addQuadCurve(
                    to: CGPoint(x: collisionX + sign * 0.5, y: midY + ySpan),
                    control: CGPoint(x: collisionX + sign * (reach * 0.52), y: midY + ySpan * 1.05)
                )
                context.stroke(shell, with: .color(tintA.opacity(0.3 + Double(impact) * 0.44)), style: StrokeStyle(lineWidth: 1.8 + impact * 2.4, lineCap: .round, lineJoin: .round))
                context.stroke(shell, with: .color(tintB.opacity(0.2 + Double(impact) * 0.28)), style: StrokeStyle(lineWidth: 0.9 + impact * 0.8, lineCap: .round, lineJoin: .round))
            }
        }

        let threadN = 20 + Int(impact * 20)
        for ti in 0 ..< threadN {
            let u = deterministic01(lane: 4100 + ti, step: seed, salt: seed)
            let v = deterministic01(lane: 4200 + ti, step: seed, salt: seed)
            let ang = -.pi * 0.94 + CGFloat(u) * CGFloat.pi * 0.94 + CGFloat(sin(idlePhase + Double(ti) * 0.37)) * 0.2
            let r0: CGFloat = 8 + CGFloat(impact) * 16 + CGFloat(v) * (30 + CGFloat(impact) * 32) * CGFloat(flashPulse)
            var p = Path()
            p.move(to: CGPoint(x: collisionX, y: midY))
            let x1 = collisionX + CGFloat(cos(Double(ang))) * r0
            let y1 = midY + CGFloat(sin(Double(ang))) * r0
            p.addLine(to: CGPoint(x: x1, y: y1))
            let hot = (0.32 + Double(impact) * 0.52 + Double(flareMul) * 0.08) * Double(flicker) * flashPulse
            context.stroke(p, with: .color(Color.white.opacity(min(1, hot))), style: StrokeStyle(lineWidth: 1.6 + CGFloat(impact) * 3.8, lineCap: .round))
        }

        // Intentionally no explicit center seam line; collision reads from surrounding plasma/sparks only.

        let cyanN = 16 + Int(impact * 16)
        for ci in 0 ..< cyanN {
            let yOff = (deterministic01(lane: 4300 + ci, step: seed, salt: seed) - 0.5) * beamH * 0.34
            let len: CGFloat = 16 + CGFloat(impact) * 36 + CGFloat(flareMul) * 8
            let skew = (deterministic01(lane: 4350 + ci, step: seed, salt: seed) - 0.5) * 0.62
            var p = Path()
            let sx = collisionX - 1.5
            p.move(to: CGPoint(x: sx, y: midY + yOff))
            let ex = sx - len * CGFloat(cos(0.12 + skew))
            let ey = midY + yOff - len * CGFloat(sin(0.45 + abs(skew)))
            p.addLine(to: CGPoint(x: ex, y: ey))
            context.stroke(p, with: .color(BeamTeamColors.userBloom.opacity(0.34 + Double(impact) * 0.5)), style: StrokeStyle(lineWidth: 1.8 + CGFloat(impact) * 2.1, lineCap: .round))
            context.stroke(p, with: .color(BeamTeamColors.userCore.opacity(0.24 + Double(impact) * 0.38)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        }

        let emberN = 16 + Int(impact * 16)
        for oi in 0 ..< emberN {
            let yOff = (deterministic01(lane: 4500 + oi, step: seed, salt: seed) - 0.5) * beamH * 0.34
            var wp = Path()
            let ax = collisionX + 2
            wp.move(to: CGPoint(x: ax, y: midY + yOff))
            let curl = CGFloat(sin(wDraw * 4.1 + Double(oi))) * (8 + impact * 8)
            let reach: CGFloat = 16 + CGFloat(impact) * 34 + CGFloat(flareMul) * 8
            let ex = ax + reach
            let ey = midY + yOff + curl + CGFloat(impact) * 4 * (deterministic01(lane: 4550 + oi, step: seed, salt: seed) - 0.5)
            let cx = ax + reach * 0.45 + CGFloat(sin(idlePhase + Double(oi))) * 3
            let cy = midY + yOff + curl * 0.5
            wp.addQuadCurve(to: CGPoint(x: ex, y: ey), control: CGPoint(x: cx, y: cy))
            context.stroke(wp, with: .color(BeamTeamColors.oppEmber.opacity(0.35 + Double(impact) * 0.52)), style: StrokeStyle(lineWidth: 1.9 + CGFloat(impact) * 2.2, lineCap: .round))
            context.stroke(wp, with: .color(BeamTeamColors.oppBloom.opacity(0.28 + Double(impact) * 0.34)), style: StrokeStyle(lineWidth: 0.95, lineCap: .round))
        }

        let count = EnergyBeamBeamDrawingActiveTuning.value.sparkCount
        let sparkIdleBoost = sin(wall * 16.2 + Double(seed & 31)) > 0.88 ? 1.22 : 1.0
        for si in 0 ..< count {
            let fu = deterministic01(lane: 6000 + si, step: seed & 0xffff, salt: seed)
            let fv = deterministic01(lane: 7000 + si, step: seed & 0xffff, salt: seed ^ (seed &* 50_069) ^ (si &* 9_743))
            let slot = (fu + fv) * 0.5
            let angBase: CGFloat
            if slot < 0.25 {
                angBase = -.pi * 0.82 + fu * 0.35
            } else if slot < 0.5 {
                angBase = -.pi * 0.38 + fv * 0.28
            } else if slot < 0.75 {
                angBase = .pi * 0.38 + fu * 0.28
            } else {
                angBase = .pi * 0.82 - fv * 0.35
            }
            var ang = angBase + CGFloat(sin(idlePhase + Double(si) * 0.31)) * 0.12
            ang += CGFloat(impact * 0.35 * sin(Double(si) * 1.7))

            let baseLen: CGFloat = 5 + fv * CGFloat(16 + sparkBoost + impact * 36) * CGFloat(sparkIdleBoost)
            let len = baseLen + CGFloat(Double(impact) * 34)
            let sx = collisionX + CGFloat(sin(idlePhase * 0.8 + Double(si))) * (0.8 + CGFloat(impact) * 0.9)
            let sy = midY + (fv - 0.5) * 10 + CGFloat(sin(wall * 9 + Double(si))) * 2.8

            var sp = Path()
            sp.move(to: CGPoint(x: sx, y: sy))
            let x1 = sx + CGFloat(cos(Double(ang))) * len
            let y1 = sy + CGFloat(sin(Double(ang))) * len
            let midx = sx + CGFloat(cos(Double(ang + 0.08))) * len * 0.52 + CGFloat(sin(idlePhase * 2.1 + Double(si))) * 2.2
            let midy = sy + CGFloat(sin(Double(ang + 0.08))) * len * 0.52
            sp.addQuadCurve(to: CGPoint(x: x1, y: y1), control: CGPoint(x: midx, y: midy))

            let hotLine = CGFloat(0.75 + fu * CGFloat(impact) * 3.6)
            let alpha = min(0.98, max(0.1, 0.18 + Double(fv) * Double(impact) * 0.95 + Double(flicker) * Double(impact) * 0.35 + Double(impact) * 0.4))
            context.stroke(
                sp,
                with: .color(Color.white.opacity(alpha)),
                style: StrokeStyle(lineWidth: hotLine + CGFloat(impact) * 3.2, lineCap: .round)
            )
            let tintSpark = slot < 0.5 ? BeamTeamColors.userCore : BeamTeamColors.oppCore
            context.stroke(sp, with: .color(tintSpark.opacity(0.32 + Double(impact) * 0.28)), style: StrokeStyle(lineWidth: 0.55, lineCap: .round))
        }

        context.blendMode = .normal
    }

    /// Jagged polylines ejected away from the impact on each side (bounce-off read).
    private static func drawReflectedFragments(
        context: inout GraphicsContext,
        collisionX: CGFloat,
        midY: CGFloat,
        leftPad: CGFloat,
        rightPad: CGFloat,
        wDraw: TimeInterval,
        impact: CGFloat,
        seed: Int
    ) {
        let n = EnergyBeamBeamDrawingActiveTuning.value.reflectFragmentCount + Int(impact * 8)
        context.blendMode = .plusLighter
        for r in 0 ..< n {
            let y0 = (deterministic01(lane: 2100 + r, step: seed, salt: seed) - 0.5) * (18 + impact * 32)
            var p = Path()
            p.move(to: CGPoint(x: collisionX - 3, y: midY + y0))
            var x = collisionX - 3
            for k in 1 ... 4 {
                x = max(leftPad + 4, x - CGFloat(12 + k * 3 + r))
                let y = midY + y0 + CGFloat(sin(wDraw * 6.2 + Double(k + r * 3))) * (4 + impact * 7)
                p.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(
                p,
                with: .color(BeamTeamColors.userBloom.opacity(0.22 + Double(impact) * 0.36)),
                style: StrokeStyle(lineWidth: 1.6 + CGFloat(impact) * 1.9, lineCap: .round)
            )
            context.stroke(
                p,
                with: .color(Color.white.opacity(0.16 + Double(impact) * 0.24)),
                style: StrokeStyle(lineWidth: 0.8 + CGFloat(impact) * 1.0, lineCap: .round)
            )
        }
        for r in 0 ..< n {
            let y0 = (deterministic01(lane: 2200 + r, step: seed, salt: seed) - 0.5) * (18 + impact * 32)
            var p = Path()
            p.move(to: CGPoint(x: collisionX + 3, y: midY + y0))
            var x = collisionX + 3
            for k in 1 ... 4 {
                x = min(rightPad - 4, x + CGFloat(12 + k * 3 + r))
                let y = midY + y0 + CGFloat(cos(wDraw * 6.5 + Double(k + r * 2))) * (4 + impact * 7)
                p.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(
                p,
                with: .color(BeamTeamColors.oppEmber.opacity(0.24 + Double(impact) * 0.38)),
                style: StrokeStyle(lineWidth: 1.6 + CGFloat(impact) * 1.9, lineCap: .round)
            )
            context.stroke(
                p,
                with: .color(Color.white.opacity(0.16 + Double(impact) * 0.24)),
                style: StrokeStyle(lineWidth: 0.8 + CGFloat(impact) * 1.0, lineCap: .round)
            )
        }
    }

    /// Five nested strokes for one tendril path (wide bloom → hot core → white hairline).
    private static func layeredTendrilStrokes(
        context: inout GraphicsContext,
        path: Path,
        wideColor: Color,
        midTint: Color,
        deepTint: Color,
        coreHot: Color,
        flicker: CGFloat,
        impact: CGFloat,
        plusMode: Bool,
        opacityScale: CGFloat,
        widthScale: CGFloat
    ) {
        let widen = CGFloat(impact * 12)
        let op = Double(opacityScale) * Double(EnergyBeamBeamDrawingActiveTuning.value.masterStrokeOpacity)
        let fk = Double(flicker)
        context.blendMode = plusMode ? .plusLighter : .screen
        context.stroke(
            path,
            with: .color(wideColor.opacity((0.16 + Double(widen) * 0.018) * fk * op)),
            style: StrokeStyle(lineWidth: (15.5 + widen * 0.48) * widthScale, lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            path,
            with: .color(midTint.opacity((0.26 + Double(widen) * 0.026) * fk * op)),
            style: StrokeStyle(lineWidth: (7.2 + widen * 0.28) * widthScale, lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            path,
            with: .color(deepTint.opacity((0.2 + Double(widen) * 0.022) * fk * op)),
            style: StrokeStyle(lineWidth: (4.2 + widen * 0.16) * widthScale, lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            path,
            with: .color(coreHot.opacity((0.68 + Double(widen) * 0.062) * fk * op)),
            style: StrokeStyle(lineWidth: (2.85 + widen * 0.14) * widthScale, lineCap: .round, lineJoin: .round)
        )
        context.blendMode = .plusLighter
        context.stroke(
            path,
            with: .color(Color.white.opacity((0.88 + Double(widen) * 0.16) * fk * op)),
            style: StrokeStyle(lineWidth: (1.05 + widen * 0.07) * widthScale, lineCap: .round, lineJoin: .round)
        )
    }

    /// Center spine polyline with advecting phase + glowing knots traveling toward collision.
    private static func coreSpineAdvected(
        context: inout GraphicsContext,
        from x0: CGFloat,
        to x1: CGFloat,
        midY: CGFloat,
        wDraw: TimeInterval,
        seed: Int,
        flicker: CGFloat,
        impact: CGFloat,
        tint: Color,
        isUser: Bool
    ) {
        guard x1 > x0 + 2 else { return }
        let steps = EnergyBeamBeamDrawingActiveTuning.value.coreSpineResampleSteps
        let advect = wDraw * (6.8 + Double(impact) * 10.3)
        var p = Path()
        for i in 0 ... steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = x0 + (x1 - x0) * t
            let xi = Double(t)
            let waveCoord = isUser ? xi : (1 - xi)
            let spatial = waveCoord * 18 * Double.pi - advect + Double(seed & 15) * 0.03
            let compress = pow(isUser ? xi : (1 - xi), 1.22)
            let pinch: CGFloat = 0.38 + 0.62 * CGFloat(1 - compress)
            let yOff = sin(spatial * 0.9) * 0.42 + sin(spatial * 1.48 + 0.7) * 0.24 + cos(spatial * 0.64) * 0.16
            let y = midY + CGFloat(yOff) * (2.2 + CGFloat(impact) * 2.1) * pinch
            if i == 0 {
                p.move(to: CGPoint(x: x, y: y))
            } else {
                p.addLine(to: CGPoint(x: x, y: y))
            }
        }
        let iw = CGFloat(2.2 + impact * 3.85) * CGFloat(0.95 + deterministic01(lane: isUser ? 31 : 32, step: 0, salt: seed) * 0.22)
        context.blendMode = .normal
        context.stroke(p, with: .color(Color.white.opacity(Double(0.12 * flicker))), style: StrokeStyle(lineWidth: iw + 5.2, lineCap: .round, lineJoin: .round))
        context.blendMode = .plusLighter
        context.stroke(p, with: .color(Color.white.opacity(Double((0.62 + Double(impact) * 0.58) * Double(flicker)))), style: StrokeStyle(lineWidth: iw + 2.05, lineCap: .round, lineJoin: .round))
        context.stroke(p, with: .color(tint.opacity(Double((0.46 + Double(impact) * 0.52) * Double(flicker)))), style: StrokeStyle(lineWidth: iw + 1.15, lineCap: .round, lineJoin: .round))
        context.stroke(p, with: .color(Color.white.opacity(Double((0.96 + Double(impact) * 0.62) * Double(flicker)))), style: StrokeStyle(lineWidth: iw * 0.78, lineCap: .round, lineJoin: .round))

        let dashPhase = CGFloat(wDraw * (isUser ? 118 : -118) * (1 + Double(impact) * 0.52))
        context.blendMode = .plusLighter
        context.stroke(
            p,
            with: .color(Color.white.opacity(Double(0.38 + Double(impact) * 0.48))),
            style: StrokeStyle(lineWidth: max(1, iw * 0.46), lineCap: .round, lineJoin: .round, dash: [3, 8, 2, 6], dashPhase: dashPhase)
        )

        // Glowing knots advect along beam center to read as moving plasma mass.
        let knotN = EnergyBeamBeamDrawingActiveTuning.value.coreSpineKnotCount
        for k in 0 ..< knotN {
            let frac = (wDraw * (0.72 + Double(impact) * 0.32) + Double(k) * 0.24).truncatingRemainder(dividingBy: 1)
            let t = isUser ? frac : (1 - frac)
            let x = x0 + CGFloat(t) * (x1 - x0)
            let localSpatial = (isUser ? t : (1 - t)) * 18 * Double.pi - advect
            let y = midY + CGFloat(sin(localSpatial * 0.84) * 0.9)
            let r = CGFloat(1.25 + impact * 1.7)
            let knot = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            context.blendMode = .plusLighter
            context.fill(knot, with: .color(Color.white.opacity(0.62 + Double(impact) * 0.22)))
            context.fill(knot, with: .color(tint.opacity(0.48)))
        }
    }

}

// MARK: - Momentum chip

/// Buckets the integer margin into a coarse UX label (thresholds: 420 and 1500). Client-side UX only — not server momentum.
private enum MomentumState: Equatable {
    case leadGrowing
    case leadShrinking
    case closeBattle
    case needsPush

    /// Maps integer margin to chip enum; change `420` / `1500` thresholds to alter when labels flip.
    static func inferred(fromMargin margin: Int) -> MomentumState {
        let mag = abs(margin)
        if mag <= 420 { return .closeBattle }
        if margin > 420 {
            return mag >= 1500 ? .leadGrowing : .closeBattle
        }
        return mag >= 1500 ? .needsPush : .leadShrinking
    }

    var label: String {
        switch self {
        case .leadGrowing: return "LEAD GROWING"
        case .leadShrinking: return "LEAD SHRINKING"
        case .closeBattle: return "CLOSE BATTLE"
        case .needsPush: return "NEEDS PUSH"
        }
    }

    var symbolName: String {
        switch self {
        case .leadGrowing: return "arrow.up.forward"
        case .leadShrinking: return "arrow.down.forward"
        case .closeBattle: return "arrow.left.arrow.right.circle"
        case .needsPush: return "bolt.fill"
        }
    }

    var borderAndForeground: Color {
        switch self {
        case .leadGrowing, .closeBattle:
            return FitUpColors.Neon.cyan.opacity(0.95)
        case .leadShrinking:
            return FitUpColors.Neon.orange.opacity(0.92)
        case .needsPush:
            return FitUpColors.Neon.yellow.opacity(0.92)
        }
    }
}

/// Capsule UI for `MomentumState` (symbol + label + accent stroke).
private struct MomentumChipView: View {
    let state: MomentumState

    var body: some View {
        let accent = state.borderAndForeground

        HStack(spacing: 8) {
            Image(systemName: state.symbolName)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 12, weight: .bold))
                .allowsTightening(true)
                .minimumScaleFactor(0.9)

            Text(state.label)
                .font(FitUpFont.body(11, weight: .heavy))
                .tracking(2.1)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .allowsTightening(true)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.52))
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(accent.opacity(0.55), lineWidth: 1)
        )
        .foregroundStyle(accent)
        .shadow(color: accent.opacity(0.18), radius: 14, y: 5)
        .minimumScaleFactor(0.94)
        .allowsTightening(true)
    }
}

// MARK: - Sparkline chart

/// Full-calendar-day intraday chart with time-accurate *Now markers and finger scrubbing.
private struct DayBattleSparklinePreview: View {
    let domain: HomeHeroSparklineDomain
    var showMockTimelineLabel: Bool = false

    @Environment(\.homeHeroCompactScale) private var compactScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrubbedFraction: CGFloat?
    @State private var isScrubbing = false

    private var chartHeight: CGFloat { HomeHeroCompactLayout.scaled(68, by: compactScale) }
    private var chartPad: CGPoint { CGPoint(x: 14, y: 14) }

    private var nowFraction: CGFloat { domain.nowFraction }

    private var effectiveFraction: CGFloat {
        min(nowFraction, max(0, scrubbedFraction ?? nowFraction))
    }

    var body: some View {
        VStack(spacing: HomeHeroCompactLayout.scaled(6, by: compactScale)) {
            scrubCallout

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let size = CGSize(width: w, height: h)
                let ptsU = timeSampledPoints(role: .user, in: size, pad: chartPad)
                let ptsO = timeSampledPoints(role: .opponent, in: size, pad: chartPad)
                let markerX = chartPad.x + effectiveFraction * max(w - chartPad.x * 2, 1)
                let nowX = chartPad.x + nowFraction * max(w - chartPad.x * 2, 1)

                ZStack {
                    roundedChartBackground()

                    chartTextureOverlay(rect: CGRect(origin: .zero, size: geo.size))

                    fadedDistanceGrid(rect: CGRect(origin: .zero, size: geo.size))

                    if nowFraction > 0.01 {
                        Path { path in
                            path.move(to: CGPoint(x: nowX, y: chartPad.y))
                            path.addLine(to: CGPoint(x: nowX, y: h - chartPad.y))
                        }
                        .stroke(FitUpColors.Neon.cyan.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }

                    if isScrubbing || scrubbedFraction != nil {
                        Path { path in
                            path.move(to: CGPoint(x: markerX, y: chartPad.y))
                            path.addLine(to: CGPoint(x: markerX, y: h - chartPad.y))
                        }
                        .stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 1.2))
                    }

                    sparkline(points: ptsO, color: FitUpColors.Neon.orange.opacity(0.92), glowMultiplier: 0.85)
                    sparkline(points: ptsU, color: FitUpColors.Neon.cyan.opacity(0.95), glowMultiplier: 1.0)

                    endpointDots(ptsU: ptsU, ptsO: ptsO)
                }
                .contentShape(Rectangle())
                .gesture(scrubGesture(width: w))
            }
            .frame(height: chartHeight)

            axisRow

            #if DEBUG
            if showMockTimelineLabel {
                Text("Mock timeline")
                    .font(FitUpFont.body(11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            #endif
        }
        .padding(HomeHeroCompactLayout.scaled(10, by: compactScale))
        .allowsTightening(true)
        .minimumScaleFactor(0.94)
        .background {
            RoundedRectangle(cornerRadius: HomeHeroCompactLayout.scaled(18, by: compactScale), style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.09),
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.08),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: HomeHeroCompactLayout.scaled(18, by: compactScale), style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    FitUpColors.Neon.cyan.opacity(0.14),
                                    Color.white.opacity(0.1),
                                    FitUpColors.Neon.orange.opacity(0.12),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                }
        }
    }

    @ViewBuilder
    private var scrubCallout: some View {
        if isScrubbing || scrubbedFraction != nil {
            let time = time(at: effectiveFraction)
            let steps = domain.steps(at: time)
            Text("You: \(steps.user.formatted()) · Them: \(steps.opponent.formatted()) · \(shortTime(time))")
                .font(FitUpFont.mono(HomeHeroCompactLayout.scaled(10, by: compactScale), weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.62))
                        .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                }
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var axisRow: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let innerW = max(w - chartPad.x * 2, 1)
            let nowLabelX = chartPad.x + nowFraction * innerW

            ZStack(alignment: .topLeading) {
                HStack {
                    chartAxisLabel("12 AM")
                    Spacer()
                    chartAxisLabel("NOON")
                    Spacer()
                }

                chartAxisLabel("*NOW")
                    .fixedSize()
                    .position(x: nowLabelX, y: geo.size.height * 0.5)
            }
        }
        .frame(height: HomeHeroCompactLayout.scaled(18, by: compactScale))
        .allowsHitTesting(false)
    }

    private enum SeriesRole {
        case user
        case opponent
    }

    private func scrubGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isScrubbing = true
                let innerW = max(width - chartPad.x * 2, 1)
                let raw = (value.location.x - chartPad.x) / innerW
                scrubbedFraction = min(nowFraction, max(0, raw))
            }
            .onEnded { _ in
                isScrubbing = false
                if reduceMotion {
                    scrubbedFraction = nil
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        scrubbedFraction = nil
                    }
                }
            }
    }

    private func time(at fraction: CGFloat) -> Date {
        let span = domain.dayEnd.timeIntervalSince(domain.dayStart)
        return domain.dayStart.addingTimeInterval(Double(fraction) * span)
    }

    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func timeSampledPoints(role: SeriesRole, in size: CGSize, pad: CGPoint) -> [CGPoint] {
        let samples = domain.samples.filter { $0.timestamp <= domain.now }
        guard samples.count >= 2 else { return [] }

        let maxVal = max(
            1,
            samples.map(\.userSteps).max() ?? 0,
            samples.map(\.opponentSteps).max() ?? 0
        )
        let daySpan = domain.dayEnd.timeIntervalSince(domain.dayStart)
        guard daySpan > 0 else { return [] }

        let minX = pad.x
        let maxX = size.width - pad.x
        let minY = pad.y
        let maxY = size.height - pad.y

        func mapY(_ steps: Int) -> CGFloat {
            let normalized = CGFloat(min(1, max(0, Double(steps) / Double(maxVal))))
            return maxY - normalized * (maxY - minY)
        }

        return samples.map { sample in
            let fraction = CGFloat(sample.timestamp.timeIntervalSince(domain.dayStart) / daySpan)
            let x = minX + fraction * (maxX - minX)
            let y = mapY(role == .user ? sample.userSteps : sample.opponentSteps)
            return CGPoint(x: x, y: y)
        }
    }

    /// Faint diagonal scan texture for chart sub-card depth.
    @ViewBuilder
    private func chartTextureOverlay(rect: CGRect) -> some View {
        NeonCardTexture.diagonalScanLines(in: rect)
            .stroke(Color.white.opacity(0.025), lineWidth: 1)
            .blendMode(.plusLighter)
    }

    /// Dark rounded plate behind chart paths.
    private func roundedChartBackground() -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.black.opacity(0.22))
    }

    /// Wide-spaced faint mesh: few divisions + dim cyan/blue/orange gradient (neon wash, not white graph paper).
    @ViewBuilder
    private func fadedDistanceGrid(rect: CGRect) -> some View {
        let inset: CGFloat = 16
        let inner = rect.insetBy(dx: inset, dy: inset)
        if inner.width > 4 && inner.height > 4 {
            let nx = 4
            let ny = 3
            let mesh = distanceMeshPath(inner: inner, nx: nx, ny: ny)
            let neonWash = LinearGradient(
                colors: [
                    FitUpColors.Neon.cyan.opacity(0.055),
                    FitUpColors.Neon.blue.opacity(0.04),
                    FitUpColors.Neon.orange.opacity(0.048),
                    FitUpColors.Neon.cyan.opacity(0.038),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            mesh
                .stroke(neonWash, style: StrokeStyle(lineWidth: 0.55, lineCap: .round))
                .blendMode(.plusLighter)
                .opacity(0.85)
        }
    }

    private func distanceMeshPath(inner: CGRect, nx: Int, ny: Int) -> Path {
        var mesh = Path()
        for i in 0 ... nx {
            let t = CGFloat(i) / CGFloat(nx)
            let x = inner.minX + t * inner.width
            mesh.move(to: CGPoint(x: x, y: inner.minY))
            mesh.addLine(to: CGPoint(x: x, y: inner.maxY))
        }
        for j in 0 ... ny {
            let t = CGFloat(j) / CGFloat(ny)
            let y = inner.minY + t * inner.height
            mesh.move(to: CGPoint(x: inner.minX, y: y))
            mesh.addLine(to: CGPoint(x: inner.maxX, y: y))
        }
        return mesh
    }

    /// One sparkline: thick blurred stroke + sharp overlay stroke.
    private func sparkline(points: [CGPoint], color: Color, glowMultiplier: CGFloat) -> some View {
        let path = smoothPath(for: points)
        return path
            .stroke(color.opacity(0.72 * Double(glowMultiplier)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            .blur(radius: 4.5 + glowMultiplier)
            .overlay(
                path.stroke(color.opacity(0.94), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            )
    }

    /// Last-point markers for user (cyan) and opponent (orange) curves at *Now.
    private func endpointDots(ptsU: [CGPoint], ptsO: [CGPoint]) -> some View {
        ZStack {
            if let lu = ptsU.last {
                dot(at: lu, color: FitUpColors.Neon.cyan)
            }
            if let lo = ptsO.last {
                dot(at: lo, color: FitUpColors.Neon.orange)
            }
        }
    }

    /// Glowing endpoint disc used by `endpointDots`.
    private func dot(at point: CGPoint, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.52))
                .frame(width: 18, height: 18)
                .blur(radius: 5)
                .position(point)

            Circle()
                .fill(Color.white.opacity(0.94))
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.55), radius: 14)
                .position(point)
                .foregroundStyle(Color.white.opacity(0.94))
                .blendMode(.plusLighter)
        }
        .minimumScaleFactor(0.94)
        .allowsTightening(true)
    }

    /// Simple quadratic smoothing between sampled sparkline points.
    private func smoothPath(for points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count >= 2 else { return path }
        path.move(to: points[0])
        for i in 1 ..< points.count {
            let p0 = points[i - 1]
            let p1 = points[i]
            let mx = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)
            path.addQuadCurve(to: mx, control: p0)
            path.addQuadCurve(to: p1, control: mx)
        }
        return path
    }

    /// Axis caption under the chart (12 AM / NOON / *NOW).
    private func chartAxisLabel(_ text: String) -> some View {
        Text(text)
            .lineLimit(1)
            .allowsTightening(true)
            .minimumScaleFactor(0.85)
            .foregroundStyle(Color.white.opacity(0.6))
            .font(FitUpFont.body(HomeHeroCompactLayout.scaled(14, by: compactScale), weight: .heavy))
            .tracking(3.2 * compactScale)
    }
}

// MARK: - Day progress bar

/// Day elapsed capsule with gradient fill and a caption supplied by the host (Home or DEBUG preview).
private struct DayElapsedProgressPreview: View {
    let fractionElapsed: CGFloat
    let caption: String

    @Environment(\.homeHeroCompactScale) private var compactScale

    private var barHeight: CGFloat { HomeHeroCompactLayout.scaled(22, by: compactScale) }
    private var thumbDiameter: CGFloat { HomeHeroCompactLayout.scaled(17, by: compactScale) }

    var body: some View {
        HStack(alignment: .center, spacing: HomeHeroCompactLayout.scaled(10, by: compactScale)) {
            GeometryReader { geo in
                let w = geo.size.width
                let clamped = CGFloat.minimum(CGFloat.maximum(fractionElapsed, 0), 1)
                let x = clamped * w
                let thumbX = max(thumbDiameter * 0.5 + 2, min(w - thumbDiameter * 0.5 - 2, x))

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.35))
                        .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [FitUpColors.Neon.cyan.opacity(0.95), FitUpColors.Neon.orange.opacity(0.95)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(HomeHeroCompactLayout.scaled(22, by: compactScale), x), alignment: .leading)
                        .mask(Capsule(style: .continuous))

                    Circle()
                        .fill(Color.white.opacity(0.98))
                        .frame(width: thumbDiameter, height: thumbDiameter)
                        .shadow(color: FitUpColors.Neon.orange.opacity(0.65), radius: HomeHeroCompactLayout.scaled(12, by: compactScale))
                        .shadow(color: Color.white.opacity(0.35), radius: HomeHeroCompactLayout.scaled(10, by: compactScale))
                        .position(x: thumbX, y: geo.size.height * 0.5)
                        .blendMode(.plusLighter)

                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                        .blendMode(.plusLighter)
                }
                .frame(height: barHeight)
                .allowsHitTesting(false)
            }
            .frame(height: barHeight)

            Text(caption)
                .font(FitUpFont.mono(HomeHeroCompactLayout.scaled(16, by: compactScale), weight: .heavy))
                .foregroundStyle(HomePageStyle.offWhite.opacity(0.92))
                .tracking(1.2 * compactScale)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity)
    }

}

// MARK: - Formatters

/// Shared `NumberFormatter`s for battle score and step strings.
enum EnergyBeamNumberFormatting {
    static let score: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = ","
        nf.usesGroupingSeparator = true
        return nf
    }()

    static let steps: NumberFormatter = score
}

// MARK: - Intraday sync caption (Slice 6)

/// Single-line HealthKit recency under the hero sparkline.
private struct EnergyBeamIntradaySyncCaption: View {
    let viewerHealthKitAt: Date?

    @Environment(\.homeHeroCompactScale) private var compactScale

    var body: some View {
        if let viewerHealthKitAt {
            TimelineView(.periodic(from: .now, by: 45)) { timeline in
                Text("HealthKit synced \(relativeString(for: viewerHealthKitAt, relativeTo: timeline.date))")
                    .font(FitUpFont.body(HomeHeroCompactLayout.scaled(12, by: compactScale), weight: .medium))
                    .foregroundStyle(HomePageStyle.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("HealthKit synced \(relativeString(for: viewerHealthKitAt, relativeTo: timeline.date))")
            }
        }
    }

    private func relativeString(for date: Date, relativeTo now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: now)
    }
}

// MARK: - Intraday freshness (Slice 6)

/// Subtle “last synced” row under the sparkline: viewer HealthKit read vs opponent tick recency.
private struct EnergyBeamIntradayFreshnessRow: View {
    let viewerHealthKitAt: Date?
    let opponentTickAt: Date?

    @Environment(\.homeHeroCompactScale) private var compactScale

    var body: some View {
        if viewerHealthKitAt == nil, opponentTickAt == nil {
            EmptyView()
        } else {
            TimelineView(.periodic(from: .now, by: 45)) { timeline in
                HStack(alignment: .center, spacing: HomeHeroCompactLayout.scaled(8, by: compactScale)) {
                    freshnessColumn(
                        title: "YOU",
                        caption: "HealthKit",
                        at: viewerHealthKitAt,
                        now: timeline.date,
                        accent: FitUpColors.Neon.cyan,
                        alignment: .leading
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("SYNC")
                        .font(FitUpFont.display(HomeHeroCompactLayout.scaled(24, by: compactScale), weight: .black))
                        .foregroundStyle(Color.white.opacity(0.96))
                        .tracking(2.4 * compactScale)
                        .shadow(color: Color.white.opacity(0.25), radius: HomeHeroCompactLayout.scaled(10, by: compactScale), y: 0)
                        .shadow(color: FitUpColors.Neon.cyan.opacity(0.18), radius: HomeHeroCompactLayout.scaled(16, by: compactScale), y: 0)
                        .layoutPriority(1)

                    freshnessColumn(
                        title: "THEM",
                        caption: "Their day",
                        at: opponentTickAt,
                        now: timeline.date,
                        accent: FitUpColors.Neon.orange.opacity(0.95),
                        alignment: .trailing
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, HomeHeroCompactLayout.scaled(8, by: compactScale))
                .padding(.horizontal, HomeHeroCompactLayout.scaled(10, by: compactScale))
                .background {
                    RoundedRectangle(cornerRadius: HomeHeroCompactLayout.scaled(14, by: compactScale), style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay {
                            RoundedRectangle(cornerRadius: HomeHeroCompactLayout.scaled(14, by: compactScale), style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabel(now: timeline.date))
            }
        }
    }

    private func freshnessColumn(
        title: String,
        caption: String,
        at: Date?,
        now: Date,
        accent: Color,
        alignment: HorizontalAlignment
    ) -> some View {
        let frameAlign: Alignment = alignment == .leading ? .leading : .trailing
        return VStack(alignment: alignment, spacing: HomeHeroCompactLayout.scaled(4, by: compactScale)) {
            Text(title)
                .font(FitUpFont.body(HomeHeroCompactLayout.scaled(12, by: compactScale), weight: .heavy))
                .foregroundStyle(Color.white.opacity(0.55))
                .tracking(2 * compactScale)
            Text(caption)
                .font(FitUpFont.body(HomeHeroCompactLayout.scaled(14, by: compactScale), weight: .heavy))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.35), radius: HomeHeroCompactLayout.scaled(8, by: compactScale), y: 0)
            if let at {
                Text(Self.relativeString(for: at, relativeTo: now))
                    .font(FitUpFont.body(HomeHeroCompactLayout.scaled(15, by: compactScale), weight: .semibold))
                    .foregroundStyle(HomePageStyle.muted)
            } else {
                Text("—")
                    .font(FitUpFont.body(HomeHeroCompactLayout.scaled(15, by: compactScale), weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlign)
    }

    private static func relativeString(for date: Date, relativeTo now: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: now)
    }

    private func accessibilityLabel(now: Date) -> String {
        let you = viewerHealthKitAt.map { "You, HealthKit \(Self.relativeString(for: $0, relativeTo: now))" } ?? "You, no HealthKit sync time"
        let them = opponentTickAt.map { "Them, last tick \(Self.relativeString(for: $0, relativeTo: now))" } ?? "Them, no tick time"
        return "\(you). \(them)."
    }
}

// MARK: - Composable glass hero card

/// Shared “Today's Battle” glass card: header, players, procedural beam, headline, momentum, sparkline, day bar.
struct EnergyBeamHeroGlassCardView: View {
    let margin: Double
    let referenceBattleValue: Int
    let userName: String
    let opponentName: String
    let userSteps: Int
    let opponentSteps: Int
    let userBattleScore: Int
    let opponentBattleScore: Int
    let battleScoreColumnTitle: String
    let resultEyebrow: String
    let resultEyebrowColor: Color
    let resultHeroNumberText: String
    let unitLabel: String
    let sparklineUserValues: [CGFloat]
    let sparklineOpponentValues: [CGFloat]
    let sparklineDomain: HomeHeroSparklineDomain
    let dayElapsedFraction: CGFloat
    let dayProgressCaption: String
    var showMockTimelineDebugLabel: Bool = false
    /// Last successful HealthKit **steps** read for “You” (Slice 6); `nil` hides that side until known.
    var viewerIntradayHealthKitSyncedAt: Date? = nil
    /// Latest opponent intraday tick timestamp from server (Slice 6).
    var opponentIntradayLatestTickAt: Date? = nil
    /// When non-nil, only the procedural beam uses this collision margin; momentum and headline inputs stay tied to `margin` / caller-passed copy.
    var collisionMarginOverride: Int? = nil
    /// Fractional beam collision override (smooth animation); takes precedence over `collisionMarginOverride` when set.
    var beamCollisionMarginPreciseOverride: Double? = nil
    /// Mini wordmark + “TODAY’S BATTLE” strip at top of card. Home hides this for a tighter hero; prototypes keep it.
    var showTopBrandHeader: Bool = true
    /// Procedural beam look + cost; intro tween runs inside `ProceduralEnergyBeamView` when `beamIntroStartedAt` is set.
    var beamVisualTuning: EnergyBeamVisualTuning = .endingProduction
    var beamIntroStartedAt: Date? = nil
    var beamIntroHoldGhost: Bool = false
    var pinCollisionToCenterDuringIntro: Bool = false
    var proceduralMotionScale: Double = 1
    var impactStrengthScale: CGFloat = 1
    var proceduralDrawSeed: Int? = nil
    var suppressImpactBursts: Bool = false
    /// Slice 7 handoff: 0 = opponent column fully blacked out, 1 = fully revealed.
    var opponentRevealProgress: CGFloat = 1
    /// When true, opponent profile/scores are not rendered — solid black placeholder only (prevents first-frame flash).
    var opponentContentSuppressed: Bool = false
    /// Hides the ahead/behind headline under the beam (Slice 7 handoff reveal).
    var hideMarginHeadline: Bool = false
    /// Retro VS banner, meta pills, and centered day progress at the top of the card (Home featured match).
    var matchHeaderContent: NeonHeroMatchHeaderContent? = nil
    /// When true, step-count tap disclaimer mentions Balanced Battle scoring.
    var isBalancedStepsBattle: Bool = false
    /// Active step battles for the hero opponent picker (shown when count > 1).
    var heroOpponentPickerMatches: [HomeActiveMatch] = []
    var selectedHeroMatchId: UUID? = nil
    var onSelectHeroMatch: ((HomeActiveMatch) -> Void)? = nil

    @Environment(\.homeHeroCompactScale) private var compactScale

    private func scaled(_ value: CGFloat) -> CGFloat {
        HomeHeroCompactLayout.scaled(value, by: compactScale)
    }

    private var cardCornerRadius: CGFloat { scaled(28) }

    private var statusCalloutReservedHeight: CGFloat { scaled(34) }
    private var postBeamMarginReservedHeight: CGFloat { scaled(46) }
    private var statusToBeamSpacing: CGFloat { scaled(5) }
    private var beamToMarginSpacing: CGFloat { scaled(2) }

    private var aboveBeamStackReservedHeight: CGFloat {
        statusCalloutReservedHeight + statusToBeamSpacing
    }

    private var belowBeamStackReservedHeight: CGFloat {
        postBeamMarginReservedHeight + beamToMarginSpacing
    }

    private var narrativeMarginInt: Int { Int(margin.rounded(.towardZero)) }
    private var beamCollisionMarginPrecise: Double {
        if let precise = beamCollisionMarginPreciseOverride { return precise }
        if let override = collisionMarginOverride { return Double(override) }
        return margin
    }

    private var beamCollisionMarginRounded: Int {
        if beamCollisionMarginPreciseOverride != nil || collisionMarginOverride != nil {
            return Int(beamCollisionMarginPrecise.rounded(.towardZero))
        }
        return narrativeMarginInt
    }

    var body: some View {
        VStack(spacing: 0) {
            if showTopBrandHeader {
                headerBlock
                    .padding(.top, scaled(18))
                    .padding(.bottom, scaled(8))
            }

            if let matchHeaderContent {
                VStack(spacing: scaled(8)) {
                    HStack(alignment: .center) {
                        NeonHeroDayProgressBanner(label: matchHeaderContent.dayProgressLabel)
                    }
                    if !matchHeaderContent.battleDateRangeLabel.isEmpty {
                        Text(matchHeaderContent.battleDateRangeLabel)
                            .font(FitUpFont.mono(scaled(11), weight: .semibold))
                            .foregroundStyle(HomePageStyle.muted)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .multilineTextAlignment(.center)
                    }
                    if !matchHeaderContent.pills.isEmpty {
                        NeonHeroMetaPillsRow(pills: matchHeaderContent.pills)
                    }
                }
                .padding(.horizontal, scaled(16))
                .padding(.top, showTopBrandHeader ? scaled(8) : scaled(14))
                .padding(.bottom, scaled(10))
            }

            if let matchHeaderContent {
                NeonRetroVersusBanner(
                    userName: matchHeaderContent.userDisplayName,
                    opponentName: matchHeaderContent.opponentDisplayName,
                    matchStatusLabel: matchHeaderContent.matchStatusLabel,
                    matchScoreText: matchHeaderContent.matchScoreText,
                    matchStatusColor: matchHeaderContent.matchStatusColor
                )
                .padding(.horizontal, scaled(10))
                .padding(.top, scaled(12))
                .padding(.bottom, scaled(6))
            }

            playersRow
                .padding(.horizontal, scaled(10))
                .padding(.top, scaled(heroPlayersRowTopPadding))
                .padding(.bottom, scaled(12))

            beamBattleZone
                .padding(.horizontal, scaled(18))
                .padding(.bottom, scaled(10))

            DayBattleSparklinePreview(
                domain: sparklineDomain,
                showMockTimelineLabel: showMockTimelineDebugLabel
            )
            .padding(.horizontal, scaled(14))
            .padding(.bottom, scaled(4))

            EnergyBeamIntradaySyncCaption(viewerHealthKitAt: viewerIntradayHealthKitSyncedAt)
                .padding(.horizontal, scaled(14))
                .padding(.bottom, scaled(12))
        }
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(FitUpColors.Bg.base.opacity(0.78))

                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.clear,
                                FitUpColors.Bg.base.opacity(0.22),
                                FitUpColors.Bg.base.opacity(0.72),
                                FitUpColors.Bg.base.opacity(0.94),
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: 320
                        )
                    )

                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.22),
                                FitUpColors.Neon.cyan.opacity(0.18),
                                FitUpColors.Neon.orange.opacity(0.15),
                                Color.white.opacity(0.12),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .shadow(color: FitUpColors.Neon.cyan.opacity(0.12), radius: scaled(28), y: scaled(10))
        .shadow(color: .black.opacity(0.65), radius: scaled(18), y: scaled(10))
        .animation(
            EnergyBeamHeroLayout.marginTransitionAnimation(duration: EnergyBeamHeroLayout.marginDrivenAnimationSeconds),
            value: beamCollisionMarginPrecise
        )
    }

    private var heroPlayersRowTopPadding: CGFloat {
        if matchHeaderContent != nil { return 8 }
        return showTopBrandHeader ? 0 : 8
    }

    private func scaledBeamOuterHeight(_ tuning: EnergyBeamVisualTuning) -> CGFloat {
        scaled(tuning.beamOuterHeight)
    }

    private var headerBlock: some View {
        VStack(spacing: 5) {
            FitUpMiniLogoPreview()
            Text("TODAY'S BATTLE")
                .font(FitUpFont.body(11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.42))
                .tracking(2.6)
                .minimumScaleFactor(0.85)
                .allowsTightening(true)
        }
    }

    /// Solid black stand-in so rival name/scores never paint before the handoff reveal.
    private var opponentColumnBlackPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.black)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var playersRow: some View {
        HStack(alignment: .top, spacing: NeonHeroVersusLayout.playerColumnSpacing) {
            PlayerColumnPreview(
                role: .user,
                accent: FitUpColors.Neon.cyan,
                name: userName,
                stepCount: userSteps,
                battleScore: userBattleScore,
                scoreCaption: battleScoreColumnTitle,
                isBalancedStepsBattle: isBalancedStepsBattle
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, scaled(NeonHeroVersusLayout.playerColumnEdgeInset))

            ZStack(alignment: .topTrailing) {
                if opponentContentSuppressed {
                    opponentColumnBlackPlaceholder
                } else {
                    PlayerColumnPreview(
                        role: .opponent,
                        accent: FitUpColors.Neon.orange,
                        name: opponentName,
                        stepCount: opponentSteps,
                        battleScore: opponentBattleScore,
                        scoreCaption: battleScoreColumnTitle,
                        isBalancedStepsBattle: isBalancedStepsBattle
                    )
                    .scaleEffect(0.88 + 0.12 * opponentRevealProgress, anchor: .topTrailing)
                    .opacity(opponentRevealProgress)

                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black)
                        .opacity(1 - opponentRevealProgress)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topTrailing)
            .padding(.trailing, scaled(NeonHeroVersusLayout.playerColumnEdgeInset))
            .frame(minHeight: scaled(148))
            .accessibilityHidden(opponentContentSuppressed || opponentRevealProgress < 0.04)
        }
    }

    private var beamMarginDisplayInt: Int { Int(beamCollisionMarginPrecise.rounded(.towardZero)) }

    /// Status pill, procedural beam, and post-beam margin row.
    private var beamBattleZone: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let introT = EnergyBeamHeroLayout.beamIntroProgress(
                at: timeline.date,
                startedAt: beamIntroStartedAt,
                holdGhostBeforeStart: beamIntroHoldGhost
            )
            let introActive = introT < 1 && (beamIntroStartedAt != nil || beamIntroHoldGhost)
            let layoutTuning = introActive
                ? .interpolatedVisualBirth(
                    from: .beginningIntro,
                    to: beamVisualTuning,
                    visualT: introT,
                    motionScale: EnergyBeamHeroLayout.introProceduralMotionScale
                )
                : beamVisualTuning

            VStack(spacing: 0) {
                if !hideMarginHeadline {
                    EnergyBeamBattleStatusCallout(margin: beamMarginDisplayInt)
                        .padding(.bottom, statusToBeamSpacing)
                } else {
                    Color.clear
                        .frame(height: aboveBeamStackReservedHeight)
                }

                ProceduralEnergyBeamView(
                    marginPrecise: beamCollisionMarginPrecise,
                    referenceBattleValue: referenceBattleValue,
                    marginRounded: beamCollisionMarginRounded,
                    beamVisualTuning: beamVisualTuning,
                    beamIntroStartedAt: beamIntroStartedAt,
                    beamIntroHoldGhost: beamIntroHoldGhost,
                    pinCollisionToCenterDuringIntro: introActive && pinCollisionToCenterDuringIntro,
                    proceduralMotionScale: proceduralMotionScale,
                    impactStrengthScale: impactStrengthScale,
                    proceduralDrawSeed: proceduralDrawSeed,
                    suppressImpactBursts: suppressImpactBursts
                )
                .frame(height: scaledBeamOuterHeight(layoutTuning))

                if !hideMarginHeadline {
                    EnergyBeamPostBeamMarginRow(
                        margin: beamMarginDisplayInt,
                        unitLabel: unitLabel,
                        referenceValue: referenceBattleValue
                    )
                    .padding(.top, beamToMarginSpacing)
                } else {
                    Color.clear
                        .frame(height: belowBeamStackReservedHeight)
                }
            }
            .clipped()
            .frame(
                height: scaledBeamOuterHeight(layoutTuning)
                    + (hideMarginHeadline ? 0 : aboveBeamStackReservedHeight + belowBeamStackReservedHeight)
            )
        }
    }
}
