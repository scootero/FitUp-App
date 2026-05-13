//
//  EnergyBeamHeroCore.swift
//  FitUp
//
//  Always-compiled energy beam hero visuals (beam, sparkline, momentum, glass chrome).
//  DEBUG-only preview harness lives in EnergyBeamHeroPrototypeView.swift.
//

import SwiftUI

// MARK: - Layout / timing (shared with Home + DEBUG prototype)

enum EnergyBeamHeroLayout {
    /// Seconds for margin-driven beam collision slide and related eased UI.
    static let marginDrivenAnimationSeconds: Double = 6.0
    /// Default `referenceBattleValue` for `normalizedBeamOffset` (prototype parity).
    static let defaultBeamReferenceValue: Int = 8_431
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
}

// MARK: - Beam offset formula

/// Maps raw `margin` into a horizontal offset factor in ~[-0.36, 0.36] used by the beam’s collision X.
/// - `referenceValue`: larger ⇒ same `margin` produces smaller offset (beam moves less); tied to `beamReferenceValue`.
/// - `scale`: clamps how fast `tanh` saturates; affects how “touchy” the slider feels near extremes.
/// - Final `* 0.36`: max fraction of card width the collision can shift from center; raise for wider sweep.
private func normalizedBeamOffset(margin: Double, referenceValue: Int) -> CGFloat {
    let reference = max(Double(referenceValue), 6000)
    let scale = max(reference * 0.28, 1800)
    let raw = margin / scale
    let eased = tanh(raw)
    return CGFloat(eased) * 0.36
}

/// `Int` overload; forwards to the `Double` version (same behavior).
private func normalizedBeamOffset(margin: Int, referenceValue: Int) -> CGFloat {
    normalizedBeamOffset(margin: Double(margin), referenceValue: referenceValue)
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

    var labelText: String {
        switch self {
        case .user: return "YOU"
        case .opponent: return "OPPONENT"
        }
    }
}

/// One player column: glyph, name, steps, divider, battle score text.
private struct PlayerColumnPreview: View {
    let role: BattlePlayerRolePreview
    let accent: Color
    let name: String
    let stepCount: Int
    let battleScore: Int
    let scoreCaption: String

    var body: some View {
        VStack(spacing: 8) {
            // TODO(dev): Swap `ProfileGlyphPreview` with real avatar vectors / Photos when wired to prod.
            ProfileGlyphPreview(accent: accent)

            Text(role.labelText)
                .font(FitUpFont.body(10, weight: .heavy))
                .foregroundStyle(accent)
                .tracking(2)

            Text(name)
                .font(FitUpFont.display(17, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)

            Text(stepCountLabel)
                .font(FitUpFont.body(12, weight: .regular))
                .foregroundStyle(FitUpColors.Text.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)

            Text(scoreCaption)
                .font(FitUpFont.body(11, weight: .semibold))
                .foregroundStyle(accent.opacity(0.85))
                .tracking(0.35)

            Text(EnergyBeamNumberFormatting.score.string(from: NSNumber(value: battleScore)) ?? "\(battleScore)")
                .font(FitUpFont.display(31, weight: .heavy))
                .foregroundStyle(accent.opacity(1))
                .shadow(color: accent.opacity(0.35), radius: 10)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity, alignment: role == .user ? .leading : .trailing)
    }

    /// “12,345 steps” string from `stepCount` using `EnergyBeamNumberFormatting.steps`.
    private var stepCountLabel: String {
        let n = EnergyBeamNumberFormatting.steps.string(from: NSNumber(value: stepCount)) ?? "\(stepCount)"
        return "\(n) steps"
    }
}

/// Circular avatar placeholder with accent ring (mock).
private struct ProfileGlyphPreview: View {
    let accent: Color

    var body: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 21, weight: .semibold))
            .foregroundStyle(accent.opacity(0.92))
            .shadow(color: accent.opacity(0.45), radius: 10)
            .frame(width: 56, height: 56)
            .background(.black.opacity(0.25))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(
                        AngularGradient(colors: [accent.opacity(0.92), accent.opacity(0.5), accent.opacity(0.92)], center: .center),
                        lineWidth: 3
                    )
            )
            .shadow(color: accent.opacity(0.22), radius: 14, y: 6)
            .minimumScaleFactor(0.92)
            .allowsTightening(true)
    }
}

// MARK: - Procedural energy beam (Canvas + TimelineView)

/// Tunables for Canvas cost vs richness. Raising counts costs more GPU each frame.
private enum ProceduralEnergyBeamConfig {
    /// `TimelineView` minimum interval (seconds). **Smaller** ⇒ more redraws (smoother plasma, more CPU). `2.0/16` ≈ 8 Hz vs `1.0/16` ≈ 16 Hz.
    static let timelineInterval: TimeInterval = 1.0 / 16.0
    /// Main lightning lanes drawn per side (cyan / orange); more ⇒ denser beam.
    static let lanesPerSide = 5
    /// Collision sparkle strokes; more ⇒ busier impact.
    static let sparkCount = 12
    /// Upper bound on tendril polyline segments (per lane); higher ⇒ smoother curves, costlier. Must be ≥ `tendrilSegmentMin`.
    static let tendrilSegmentMax = 5
    /// Lower bound on tendril segments (randomized per lane between min…max).
    static let tendrilSegmentMin = 2
    /// If deterministic lane random exceeds this, a short fork branch is drawn (0…1).
    static let forkProbabilityThreshold: CGFloat = 0.72
    /// Count of fast “flow streak” segments per side toward collision.
    static let flowStreakCount = 3
    /// Count of traveling packets / fireball sprites per side.
    static let flowPacketCount = 4
    /// Base count of reflected fragment polylines per side (scaled up with impact in renderer).
    static let reflectFragmentCount = 1
}

/// Electric-plasma palette for Canvas strokes/fills (RGB constants); tweak for different hue reads.
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

/// DEBUG-only beam: `GeometryReader` supplies width; `collisionX` follows `marginPrecise` (animated by parent `heroCard`).
/// `TimelineView` supplies `wall` time for procedural motion; **that** motion stays fast—only `margin` changes slide the impact slowly.
/// `marginRounded` reseeds deterministic noise and triggers `impactBoost` flashes via `onChange`.
private struct ProceduralEnergyBeamView: View {
    /// Same as parent `margin`; collision X interpolates when this animates (parent `.animation(..., value: margin)`).
    let marginPrecise: Double
    /// Same as `EnergyBeamHeroMock.beamReferenceValue`; passed into `normalizedBeamOffset`.
    let referenceBattleValue: Int
    /// Same as parent `battleMarginInt`; changes discretely during a fractional margin animation.
    let marginRounded: Int

    /// Wall-clock time of last integer margin change; drives short `impact` pulse in `drawBeam`.
    @State private var lastImpactAtWall: TimeInterval = -1000

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let midY = h * 0.5
            // Computed outside TimelineView so layout can follow animated `marginPrecise` every frame.
            let collisionX = computeCollisionX(width: w)

            ZStack {
                TimelineView(.animation(minimumInterval: ProceduralEnergyBeamConfig.timelineInterval)) { timeline in
                    let wall = timeline.date.timeIntervalSinceReferenceDate
                    let impact = impactBoost(atWallTime: wall)
                    Canvas { context, size in
                        ProceduralBeamRenderer.drawBeam(
                            context: &context,
                            size: size,
                            collisionX: collisionX,
                            midY: midY,
                            wall: wall,
                            // Idle transport intentionally slower; update burst ramps motion and chaos.
                            wDraw: wall * (0.24 + Double(impact) * 0.24),
                            impact: impact,
                            seed: marginRounded
                        )
                    }
                }
            }
        }
        .frame(height: ProceduralBeamRenderer.beamOuterHeight)
        // Collision slide is animated by ancestor `heroCard` (do not add a second conflicting `.animation` here).
        .onChange(of: marginRounded) { _, _ in
            lastImpactAtWall = Date().timeIntervalSinceReferenceDate
        }
    }

    /// Converts current `marginPrecise` + width into collision center X (clamped to card edges).
    private func computeCollisionX(width w: CGFloat) -> CGFloat {
        let cx = w * 0.5 + normalizedBeamOffset(margin: marginPrecise, referenceValue: referenceBattleValue) * w
        return clampBeam(cx, min: w * 0.11, max: w * 0.89)
    }

    /// Short intensity pulse after `marginRounded` flips; scales chaos in `drawBeam` (0…~1).
    private func impactBoost(atWallTime wall: TimeInterval) -> CGFloat {
        let elapsed = CGFloat(wall - lastImpactAtWall)
        guard elapsed >= 0, elapsed < 0.5 else { return 0 }
        let t = 1 - (elapsed / 0.5)
        // Quick bright spike, satisfying settle (not a long explosion).
        let peak = pow(max(0, t), 50.15)
        let shimmer = 1 + 0.14 * sin(Double(elapsed) * 48)
        return CGFloat(peak * shimmer)
    }

    /// Keeps collision X inside horizontal padding so the beam never clips the card edge.
    private func clampBeam(_ v: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        Swift.min(Swift.max(v, lo), hi)
    }
}

// MARK: - Deterministic jitter + Canvas renderer

/// All procedural beam **drawing** lives here: deterministic noise, geometry, and `GraphicsContext` strokes.
/// Call flow: `ProceduralEnergyBeamView` → `drawBeam` → helpers (`organicTendrilPoints`, collision draws, etc.).
/// Tuning: most “look” knobs are literals inside helpers; cost knobs are mostly `ProceduralEnergyBeamConfig`.
private enum ProceduralBeamRenderer {
    /// Fixed height of the beam strip in the hero card (layout + hit testing).
    static let beamOuterHeight: CGFloat = 78

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
        let s = Double(seed % 13) * 0.17
        let a = sin(wall * 3.1 + s) * 0.1
        let b = sin(wall * 7.8 + s * 3) * 0.05
        let c = sin(wall * 1.73 + Double((seed / 3) & 7)) * 0.04
        let stepped = (floor(wall * 9.7 + s).truncatingRemainder(dividingBy: 2)) * 0.05
        return CGFloat(0.78 + a + b + c + stepped)
    }

    /// Phase driver for fork wiggle; higher `wall` speeds spin along auxiliary paths.
    private static func lanePhase(lane: Int, wall: TimeInterval, seed: Int) -> Double {
        let speed = 0.48 + Double(deterministic01(lane: lane, step: 0, salt: seed)) * 0.95
        let offset = Double(lane) * 1.83 + Double(seed & 0xff) * 0.01
        return wall * .pi * 2 * speed + offset
    }

    /// Shapes per-lane vertical “breathing” along the beam; tweak multipliers for calmer vs wild tendrils.
    private static func amplitudeEnvelope(t: CGFloat, lane: Int, salt: Int, phase: Double) -> CGFloat {
        let calm = 0.35 + 0.65 * pow(sin(Double(t) * .pi), 2)
        let burst = 5.65 + 0.35 * abs(sin(phase * 10.35 + Double(t) * 7.1))
        let r = deterministic01(lane: lane, step: 404, salt: salt)
        let chaosW = 0.55 + CGFloat(r) * 0.9
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
        let segMin = ProceduralEnergyBeamConfig.tendrilSegmentMin
        let segMax = ProceduralEnergyBeamConfig.tendrilSegmentMax
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
        impact: CGFloat,
        seed: Int
    ) {
        let w = size.width
        let globalBright = 1 + impact * 0.62
        let flicker = idleGlowFactor(wall: wall, seed: seed) * CGFloat(globalBright)
        let flareMul = CGFloat(0.001 + impact * 2.25)
        let burstScale: CGFloat = 1.2 + impact * 1.1

        let leftPad: CGFloat = -20
        let rightPad: CGFloat = w + 10
        let gap: CGFloat = 0.0001

        let flowMul = 1.2 + CGFloat(impact) * 0.05

        // User side (cyan / electric teal)
        for lane in 0 ..< ProceduralEnergyBeamConfig.lanesPerSide {
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

            if deterministic01(lane: lane, step: 77, salt: seed) > ProceduralEnergyBeamConfig.forkProbabilityThreshold,
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
        for lane in 0 ..< ProceduralEnergyBeamConfig.lanesPerSide {
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

            if deterministic01(lane: laneSalt, step: 77, salt: seed) > ProceduralEnergyBeamConfig.forkProbabilityThreshold,
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
        let n = 6
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
        let n = 6
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
        let n = ProceduralEnergyBeamConfig.flowStreakCount
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
        let n = ProceduralEnergyBeamConfig.flowPacketCount
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

        let count = ProceduralEnergyBeamConfig.sparkCount
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
        let n = ProceduralEnergyBeamConfig.reflectFragmentCount + Int(impact * 8)
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
        let op = Double(opacityScale)
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
        let steps = 32
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
        let knotN = 4
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

/// Fake day chart: two smooth polylines + grid + endpoint dots (inputs are mock `[0…1]` series).
private struct DayBattleSparklinePreview: View {
    let userValues: [CGFloat]
    let opponentValues: [CGFloat]
    var showMockTimelineLabel: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let ptsU = sampledPoints(for: userValues, in: CGSize(width: w, height: h), pad: CGPoint(x: 14, y: 14))
                let ptsO = sampledPoints(for: opponentValues, in: CGSize(width: w, height: h), pad: CGPoint(x: 14, y: 14))

                ZStack {
                    roundedChartBackground()

                    fadedDistanceGrid(rect: CGRect(origin: .zero, size: geo.size))

                    subtleGrid(rect: CGRect(origin: .zero, size: geo.size))

                    sparkline(points: ptsO, color: FitUpColors.Neon.orange.opacity(0.92), glowMultiplier: 0.85)

                    sparkline(points: ptsU, color: FitUpColors.Neon.cyan.opacity(0.95), glowMultiplier: 1.0)

                    endpointDots(ptsU: ptsU, ptsO: ptsO)
                }
            }
            .frame(height: 112)

            HStack {
                chartAxisLabel("12 AM")
                Spacer()
                chartAxisLabel("NOON")
                Spacer()
                chartAxisLabel("NOW")
            }
            .foregroundStyle(Color.white.opacity(0.34))
            .tracking(2.8)
            .allowsTightening(true)
            .minimumScaleFactor(0.94)
            .allowsHitTesting(false)

            #if DEBUG
            if showMockTimelineLabel {
                Text("Mock timeline")
                    .font(FitUpFont.body(9, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.32))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            #endif
        }
        .padding(14)
        .allowsTightening(true)
        .minimumScaleFactor(0.94)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    /// Dark rounded plate behind chart paths.
    private func roundedChartBackground() -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.black.opacity(0.32))
    }

    /// Wide-spaced faint mesh: few divisions + dim cyan/blue/orange gradient (neon wash, not white graph paper).
    @ViewBuilder
    private func fadedDistanceGrid(rect: CGRect) -> some View {
        let inset: CGFloat = 16
        let inner = rect.insetBy(dx: inset, dy: inset)
        if inner.width > 4 && inner.height > 4 {
            // Fewer lines ⇒ larger cells; lower counts if you want even airier spacing.
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

    /// Sparse dashed guides on top of the mesh (thirds + mid band); gradient keeps the neon “chart” read subtle.
    private func subtleGrid(rect: CGRect) -> some View {
        let pad: CGFloat = 16
        return Path { p in
            let cols = [rect.minX + rect.width * (1.0 / 3.0), rect.minX + rect.width * (2.0 / 3.0)]
            for x in cols {
                p.move(to: CGPoint(x: x, y: rect.minY + pad))
                p.addLine(to: CGPoint(x: x, y: rect.maxY - pad))
            }
            let midY = rect.minY + rect.height * 0.5
            p.move(to: CGPoint(x: rect.minX + pad, y: midY))
            p.addLine(to: CGPoint(x: rect.maxX - pad, y: midY))
        }
        .stroke(
            LinearGradient(
                colors: [
                    FitUpColors.Neon.cyan.opacity(0.09),
                    FitUpColors.Neon.orange.opacity(0.075),
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: 0.85, lineCap: .round, dash: [4, 12])
        )
        .blendMode(.plusLighter)
    }

    /// Maps normalized series values into pixel points with padding.
    private func sampledPoints(for values: [CGFloat], in size: CGSize, pad: CGPoint) -> [CGPoint] {
        guard values.count >= 2 else { return [] }
        let minX = pad.x
        let maxX = size.width - pad.x
        let minY = pad.y
        let maxY = size.height - pad.y

        let minV = CGFloat(0)
        let maxV = CGFloat(1)

        func mapY(_ t: CGFloat) -> CGFloat {
            let tn = CGFloat((Double(t - minV)) / Double(max(maxV - minV, CGFloat(1e-4))))
            return maxY - tn * (maxY - minY)
        }

        let stepCount = CGFloat(max(values.count - 1, 1))
        return values.enumerated().map { i, value in
            let x = minX + (CGFloat(i) / stepCount) * (maxX - minX)
            let y = mapY(CGFloat.minimum(CGFloat.maximum(value, minV), maxV))
            return CGPoint(x: x, y: y)
        }
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

    /// Last-point markers for user (cyan) and opponent (orange) curves.
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

    /// Small axis caption under the chart (12 AM / NOON / NOW mock).
    private func chartAxisLabel(_ text: String) -> some View {
        Text(text)
            .lineLimit(1)
            .allowsTightening(true)
            .minimumScaleFactor(0.85)
            .foregroundStyle(Color.white.opacity(0.34))
            .font(FitUpFont.body(10, weight: .semibold))
            .tracking(2.8)
    }
}

// MARK: - Day progress bar

/// Day elapsed capsule with gradient fill and a caption supplied by the host (Home or DEBUG preview).
private struct DayElapsedProgressPreview: View {
    let fractionElapsed: CGFloat
    let caption: String

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                let w = geo.size.width
                let x = CGFloat.minimum(CGFloat.maximum(fractionElapsed, 0), 1) * w

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
                        .frame(width: max(22, x), alignment: .leading)
                        .mask(Capsule(style: .continuous))

                    Circle()
                        .fill(Color.white.opacity(0.98))
                        .frame(width: 15, height: 15)
                        .shadow(color: FitUpColors.Neon.orange.opacity(0.65), radius: 12)
                        .shadow(color: Color.white.opacity(0.35), radius: 10)
                        .position(x: max(13, CGFloat.minimum(CGFloat.maximum(fractionElapsed, 0), 1) * w), y: geo.size.height * 0.5)
                        .blendMode(.plusLighter)

                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                        .blendMode(.plusLighter)
                }
                .frame(height: 18)
                .allowsHitTesting(false)
            }
            .frame(height: 18)

            Text(caption)
                .font(FitUpFont.body(12, weight: .regular))
                .foregroundStyle(FitUpColors.Text.secondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.94)
                .allowsTightening(true)
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
    let dayElapsedFraction: CGFloat
    let dayProgressCaption: String
    var showMockTimelineDebugLabel: Bool = false

    private var battleMarginInt: Int { Int(margin.rounded(.towardZero)) }
    private var momentum: MomentumState { MomentumState.inferred(fromMargin: battleMarginInt) }

    var body: some View {
        VStack(spacing: 0) {
            headerBlock
                .padding(.top, 18)
                .padding(.bottom, 8)

            playersRow
                .padding(.horizontal, 18)
                .padding(.bottom, 14)

            ProceduralEnergyBeamView(
                marginPrecise: margin,
                referenceBattleValue: referenceBattleValue,
                marginRounded: battleMarginInt
            )
            .padding(.horizontal, 18)
            .padding(.bottom, 12)

            mainResultSection
                .padding(.horizontal, 18)
                .padding(.bottom, 14)

            momentumChip
                .padding(.bottom, 16)

            DayBattleSparklinePreview(
                userValues: sparklineUserValues,
                opponentValues: sparklineOpponentValues,
                showMockTimelineLabel: showMockTimelineDebugLabel
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 14)

            DayElapsedProgressPreview(fractionElapsed: dayElapsedFraction, caption: dayProgressCaption)
                .padding(.horizontal, 18)
                .padding(.bottom, 22)
        }
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(FitUpColors.Bg.base.opacity(0.92))

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white.opacity(0.04))

                RoundedRectangle(cornerRadius: 28, style: .continuous)
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

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [.clear, .black.opacity(0.42)],
                            center: .center,
                            startRadius: 40,
                            endRadius: 280
                        )
                    )
                    .blendMode(.multiply)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: FitUpColors.Neon.cyan.opacity(0.12), radius: 28, y: 10)
        .shadow(color: .black.opacity(0.65), radius: 18, y: 10)
        .animation(.easeInOut(duration: EnergyBeamHeroLayout.marginDrivenAnimationSeconds), value: margin)
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

    private var playersRow: some View {
        HStack(alignment: .top, spacing: 14) {
            PlayerColumnPreview(
                role: .user,
                accent: FitUpColors.Neon.cyan,
                name: userName,
                stepCount: userSteps,
                battleScore: userBattleScore,
                scoreCaption: battleScoreColumnTitle
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            PlayerColumnPreview(
                role: .opponent,
                accent: FitUpColors.Neon.orange,
                name: opponentName,
                stepCount: opponentSteps,
                battleScore: opponentBattleScore,
                scoreCaption: battleScoreColumnTitle
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var mainResultSection: some View {
        VStack(spacing: 8) {
            Text(resultEyebrow)
                .font(FitUpFont.body(11, weight: .heavy))
                .foregroundStyle(resultEyebrowColor)
                .tracking(2.4)

            Text(resultHeroNumberText)
                .font(FitUpFont.display(41, weight: .heavy))
                .foregroundStyle(Color.white)

            Text(unitLabel)
                .font(FitUpFont.body(12, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.secondary)
                .tracking(3.2)
        }
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.82)
        .allowsTightening(true)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var momentumChip: some View {
        MomentumChipView(state: momentum)
            .transition(.opacity.combined(with: .scale(scale: 0.94)))
            .animation(.easeInOut(duration: 0.25), value: momentum)
    }
}
