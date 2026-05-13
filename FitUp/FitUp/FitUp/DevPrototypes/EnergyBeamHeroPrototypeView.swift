//
//  EnergyBeamHeroPrototypeView.swift
//  FitUp
//
//  Dev-only hero mock — energy beam, glass card, preview controls. Not wired into Home or production data.
//

#if DEBUG

import SwiftUI

private enum EnergyBeamHeroMock {
    /// `(8_450 + 6_019) / 2` truncated — keeps default margin `2_431` landing on the reference scores.
    static let midpointBattleScore = 7_234
    static let baselineMargin = 2_431
    static let beamReferenceValue = 8_431
}

// MARK: - Root

struct EnergyBeamHeroPrototypeView: View {
    @State private var margin: Double = Double(EnergyBeamHeroMock.baselineMargin)
    @State private var userSteps = 9_125
    @State private var opponentSteps = 6_530
    /// Small chart boost so “Simulate Health Update” visibly tweaks endpoints.
    @State private var chartWiggleUser: CGFloat = 0
    @State private var chartWiggleOpp: CGFloat = 0
    private var battleMarginInt: Int { Int(margin.rounded(.towardZero)) }
    private var opponentBattleScore: Int { EnergyBeamHeroMock.midpointBattleScore - battleMarginInt / 2 }
    private var userBattleScore: Int { opponentBattleScore + battleMarginInt }

    private var momentum: MomentumState { MomentumState.inferred(fromMargin: battleMarginInt) }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                heroCard

                previewControlsSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 14)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .background(FitUpColors.Bg.base.ignoresSafeArea())
    }

    private var heroCard: some View {
        VStack(spacing: 0) {
            headerBlock
                .padding(.top, 18)
                .padding(.bottom, 8)

            playersRow
                .padding(.horizontal, 18)
                .padding(.bottom, 14)

            ProceduralEnergyBeamView(
                marginPrecise: margin,
                referenceBattleValue: EnergyBeamHeroMock.beamReferenceValue,
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
                userValues: cumulativeUserSeries(wiggle: chartWiggleUser),
                opponentValues: cumulativeOpponentSeries(wiggle: chartWiggleOpp)
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 14)

            DayElapsedProgressPreview(fractionElapsed: dayElapsedFraction)
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

                // Subtle vignette corners
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
        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: margin)
        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: battleMarginInt)
        .animation(.spring(response: 0.52, dampingFraction: 0.82), value: userBattleScore)
        .animation(.spring(response: 0.52, dampingFraction: 0.82), value: opponentBattleScore)
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
                name: "Scott",
                stepCount: userSteps,
                battleScore: userBattleScore
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            PlayerColumnPreview(
                role: .opponent,
                accent: FitUpColors.Neon.orange,
                name: "Mike",
                stepCount: opponentSteps,
                battleScore: opponentBattleScore
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

            Text("BATTLE SCORE")
                .font(FitUpFont.body(12, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.secondary)
                .tracking(3.2)
        }
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.82)
        .allowsTightening(true)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .animation(.easeInOut(duration: 0.22), value: battleMarginInt)
    }

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

    private var momentumChip: some View {
        MomentumChipView(state: momentum)
            .transition(.opacity.combined(with: .scale(scale: 0.94)))
            .animation(.easeInOut(duration: 0.25), value: momentum)
    }

    private var previewControlsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PREVIEW CONTROLS (DEBUG)")
                .font(FitUpFont.body(11, weight: .heavy))
                .foregroundStyle(Color.white.opacity(0.35))
                .tracking(1.8)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Battle margin (\(battleMarginInt))")
                        .font(FitUpFont.body(13, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.secondary)
                    Spacer()
                }

                Slider(value: $margin, in: -10_000 ... 10_000, step: 1)
                    .tint(FitUpColors.Neon.cyan)
                    .foregroundStyle(Color.white)

                HStack(spacing: 8) {
                    controlButton(title: "Tie") {
                        snapMargin(0)
                    }
                    controlButton(title: "User Ahead") {
                        snapMargin(2_431)
                    }
                    controlButton(title: "Opponent Ahead") {
                        snapMargin(-1_120)
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
            .padding(16)
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

    private func snapMargin(_ m: Int) {
        Task { @MainActor in
            margin = Double(m)
        }
    }

    private func simulateHealthBump() {
        Task { @MainActor in
            withAnimation(.spring(response: 0.52, dampingFraction: 0.78)) {
                userSteps += Int.random(in: 150 ... 780)
                opponentSteps += Int.random(in: 40 ... 420)
                chartWiggleUser += CGFloat(Double.random(in: 0.04 ... 0.11))
                chartWiggleOpp += CGFloat(Double.random(in: -0.09 ... 0.07))
                margin += Double.random(in: -180 ... 220)
                margin = min(max(margin, -10_000), 10_000)
            }
        }
    }

    private func cumulativeUserSeries(wiggle: CGFloat) -> [CGFloat] {
        let baseU: [CGFloat] = [
            0.02, 0.08, 0.11, 0.15, 0.19, 0.26, 0.33, 0.37, 0.42,
            0.48, 0.56, 0.62, 0.71, 0.78, 0.82, 0.88, 0.93, 0.97,
        ]
        return baseU.map { min(1, max(0, $0 + wiggle)) }
    }

    private func cumulativeOpponentSeries(wiggle: CGFloat) -> [CGFloat] {
        let baseO: [CGFloat] = [
            0.015, 0.06, 0.085, 0.11, 0.155, 0.19, 0.235, 0.29, 0.335,
            0.392, 0.44, 0.492, 0.54, 0.61, 0.67, 0.74, 0.81, 0.872,
        ]
        return baseO.map { min(1, max(0, $0 + wiggle)) }
    }

    /// Mock % of weekday elapsed anchored to “62% at 15:00” for realism in preview.
    private var dayElapsedFraction: CGFloat { 0.62 }

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

// MARK: - Beam offset formula

private func normalizedBeamOffset(margin: Double, referenceValue: Int) -> CGFloat {
    let reference = max(Double(referenceValue), 6000)
    let scale = max(reference * 0.28, 1800)
    let raw = margin / scale
    let eased = tanh(raw)
    return CGFloat(eased) * 0.36
}

private func normalizedBeamOffset(margin: Int, referenceValue: Int) -> CGFloat {
    normalizedBeamOffset(margin: Double(margin), referenceValue: referenceValue)
}

// MARK: - Mini logo

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

private struct PlayerColumnPreview: View {
    let role: BattlePlayerRolePreview
    let accent: Color
    let name: String
    let stepCount: Int
    let battleScore: Int

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

            Text("Battle Score")
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

    private var stepCountLabel: String {
        let n = EnergyBeamNumberFormatting.steps.string(from: NSNumber(value: stepCount)) ?? "\(stepCount)"
        return "\(n) steps"
    }
}

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

private enum ProceduralEnergyBeamConfig {
    static let timelineInterval: TimeInterval = 1.0 / 16.0
    static let lanesPerSide = 8
    static let sparkCount = 14
    static let tendrilSegmentMax = 19
    static let tendrilSegmentMin = 13
    /// Short fork arcs (not every lane); keeps total path count low.
    static let forkProbabilityThreshold: CGFloat = 0.68
}

/// Electric-plasma palette (saturated, game-UI).
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

/// `#if DEBUG` prototype-only electric battle beam. Designed so the drawing closure can later be swapped for a Metal-backed layer without changing callers.
private struct ProceduralEnergyBeamView: View {
    let marginPrecise: Double
    let referenceBattleValue: Int
    let marginRounded: Int

    @State private var lastImpactAtWall: TimeInterval = -1000

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let midY = h * 0.5
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
                            impact: impact,
                            seed: marginRounded
                        )
                    }
                }

                ProceduralBeamMarkerOverlay(centerX: collisionX, beamHeight: h)
            }
        }
        .frame(height: ProceduralBeamRenderer.beamOuterHeight)
        .animation(.spring(response: 0.48, dampingFraction: 0.78), value: marginPrecise)
        .onChange(of: marginRounded) { _, _ in
            lastImpactAtWall = Date().timeIntervalSinceReferenceDate
        }
    }

    private func computeCollisionX(width w: CGFloat) -> CGFloat {
        let cx = w * 0.5 + normalizedBeamOffset(margin: marginPrecise, referenceValue: referenceBattleValue) * w
        return clampBeam(cx, min: w * 0.11, max: w * 0.89)
    }

    private func impactBoost(atWallTime wall: TimeInterval) -> CGFloat {
        let elapsed = CGFloat(wall - lastImpactAtWall)
        guard elapsed >= 0, elapsed < 0.5 else { return 0 }
        let t = 1 - (elapsed / 0.5)
        // Quick bright spike, satisfying settle (not a long explosion).
        let peak = pow(max(0, t), 2.15)
        let shimmer = 1 + 0.14 * sin(Double(elapsed) * 48)
        return CGFloat(peak * shimmer)
    }

    private func clampBeam(_ v: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        Swift.min(Swift.max(v, lo), hi)
    }
}

// MARK: - Beam marker overlay (outside Canvas — crisp dashed line / chevron)

private struct ProceduralBeamMarkerOverlay: View {
    let centerX: CGFloat
    let beamHeight: CGFloat

    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: centerX, y: beamHeight * 0.06))
                p.addLine(to: CGPoint(x: centerX, y: beamHeight * 0.92))
            }
            .stroke(
                Color.white.opacity(0.32),
                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
            )

            CollisionChevron(centerX: centerX, beamBottomY: beamHeight * 0.62)
        }
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
    }
}

private struct CollisionChevron: View {
    let centerX: CGFloat
    let beamBottomY: CGFloat

    var body: some View {
        Path { path in
            let y = beamBottomY + 4
            let wtip: CGFloat = 9
            let hh: CGFloat = 6
            path.move(to: CGPoint(x: centerX - wtip, y: y))
            path.addLine(to: CGPoint(x: centerX + wtip, y: y))
            path.addLine(to: CGPoint(x: centerX, y: y + hh))
            path.closeSubpath()
        }
        .fill(Color.white.opacity(0.92))
        .shadow(color: .white.opacity(0.22), radius: 6)
    }
}

// MARK: - Deterministic jitter + Canvas renderer

private enum ProceduralBeamRenderer {
    static let beamOuterHeight: CGFloat = 58

    private static func ellipsePath(_ rect: CGRect) -> Path {
        var p = Path()
        p.addEllipse(in: rect)
        return p
    }

    private static func deterministic01(lane: Int, step: Int, salt: Int) -> CGFloat {
        let hi = UInt32(bitPattern: Int32(truncatingIfNeeded: lane &* 12_959 + step &* 28_957 + salt &* 48_049))
        let lo = hi &* 2_743_873 &+ UInt32(truncatingIfNeeded: lane ^ step ^ salt)
        let mix = UInt64(hi ^ lo)
        let s = UInt32(truncatingIfNeeded: mix ^ (mix >> 32))
        return CGFloat(Double(s % 982_447) / 982_446)
    }

    /// Desynced idle: breathing + stepped flicker (not one global sine).
    private static func idleGlowFactor(wall: TimeInterval, seed: Int) -> CGFloat {
        let s = Double(seed % 13) * 0.17
        let a = sin(wall * 3.1 + s) * 0.055
        let b = sin(wall * 7.8 + s * 3) * 0.028
        let c = sin(wall * 1.73 + Double((seed / 3) & 7)) * 0.04
        let stepped = (floor(wall * 9.7 + s).truncatingRemainder(dividingBy: 2)) * 0.05
        return CGFloat(0.78 + a + b + c + stepped)
    }

    private static func lanePhase(lane: Int, wall: TimeInterval, seed: Int) -> Double {
        let speed = 0.48 + Double(deterministic01(lane: lane, step: 0, salt: seed)) * 0.95
        let offset = Double(lane) * 1.83 + Double(seed & 0xff) * 0.01
        return wall * .pi * 2 * speed + offset
    }

    private static func amplitudeEnvelope(t: CGFloat, lane: Int, salt: Int, phase: Double) -> CGFloat {
        let calm = 0.35 + 0.65 * pow(sin(Double(t) * .pi), 2)
        let burst = 0.65 + 0.35 * abs(sin(phase * 0.35 + Double(t) * 7.1))
        let r = deterministic01(lane: lane, step: 404, salt: salt)
        let chaosW = 0.55 + CGFloat(r) * 0.9
        return calm * CGFloat(burst) * chaosW
    }

    private static func organicTendrilPoints(
        startX: CGFloat,
        endX: CGFloat,
        midY: CGFloat,
        lane: Int,
        salt: Int,
        wall: TimeInterval,
        baseSpread: CGFloat
    ) -> [CGPoint] {
        guard endX > startX + 2 else { return [] }
        let segMin = ProceduralEnergyBeamConfig.tendrilSegmentMin
        let segMax = ProceduralEnergyBeamConfig.tendrilSegmentMax
        let segN = segMin + Int(deterministic01(lane: lane, step: 3, salt: salt) * CGFloat(segMax - segMin))
        let span = endX - startX

        let early = deterministic01(lane: lane, step: 88, salt: salt)
        let spanScale: CGFloat = early < 0.26 ? (0.42 + early * 1.15) : (0.88 + early * 0.12)
        let effectiveEnd = startX + span * min(1, spanScale)

        let phase = lanePhase(lane: lane, wall: wall, seed: salt)
        let turb = wall * 1.9 + Double(lane) * 0.31

        var pts: [CGPoint] = []
        for i in 0 ... segN {
            let t = CGFloat(i) / CGFloat(segN)
            let u = Double(t)
            let env = amplitudeEnvelope(t: t, lane: lane, salt: salt, phase: phase)
            let spread = baseSpread * env

            let xLinear = startX + (effectiveEnd - startX) * t
            let driftX = CGFloat(sin(phase * 1.05 + u * 5.2 + turb)) * 3.2 * t * (1 - t) * 10
            let x = xLinear + driftX

            let h = deterministic01(lane: lane, step: i, salt: salt)
            let jolt = (h - 0.48) * 2 * spread
            let w1 = sin(phase * 0.92 + u * 8.4 + Double(lane))
            let w2 = cos(phase * 0.61 + u * 11.2)
            let y = midY + CGFloat(jolt) + CGFloat(w1 * 0.52 + w2 * 0.31) * spread

            pts.append(CGPoint(x: x, y: y))
        }
        return pts
    }

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
                let oy = CGFloat(cos(Double(r) * 4.1 + Double(i * 3))) * 2.2
                path.addQuadCurve(to: cur, control: CGPoint(x: mx + ox, y: my + oy))
            }
        }
        return path
    }

    private static func forkPath(
        from anchor: CGPoint,
        endClampX: CGFloat,
        lane: Int,
        salt: Int,
        wall: TimeInterval
    ) -> Path {
        let phase = lanePhase(lane: lane | 0x50, wall: wall, seed: salt)
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

    fileprivate static func drawBeam(
        context: inout GraphicsContext,
        size: CGSize,
        collisionX: CGFloat,
        midY: CGFloat,
        wall: TimeInterval,
        impact: CGFloat,
        seed: Int
    ) {
        let w = size.width
        let globalBright = 1 + impact * 0.62
        let flicker = idleGlowFactor(wall: wall, seed: seed) * CGFloat(globalBright)
        let flareMul = CGFloat(1 + impact * 2.25)

        var trackPath = Path()
        trackPath.move(to: CGPoint(x: 10, y: midY))
        trackPath.addLine(to: CGPoint(x: w - 10, y: midY))
        context.blendMode = .normal
        context.stroke(trackPath, with: .color(Color.white.opacity(Double(0.038 * flicker))), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        let leftPad: CGFloat = 8
        let rightPad: CGFloat = w - 8
        let gap: CGFloat = 5

        // User side (cyan / electric teal)
        for lane in 0 ..< ProceduralEnergyBeamConfig.lanesPerSide {
            let spread: CGFloat = 5.5 + CGFloat(lane % 5) * 3.2
            let pts = organicTendrilPoints(
                startX: leftPad,
                endX: collisionX - gap,
                midY: midY,
                lane: lane,
                salt: seed,
                wall: wall,
                baseSpread: spread
            )
            let earlyFade = deterministic01(lane: lane, step: 88, salt: seed) < 0.26
            let opacityScale: CGFloat = earlyFade
                ? 0.45 + deterministic01(lane: lane, step: 89, salt: seed) * 0.35
                : 1
            let widthJitter = 0.88 + deterministic01(lane: lane, step: 90, salt: seed) * 0.28
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
                widthScale: widthJitter
            )

            if deterministic01(lane: lane, step: 77, salt: seed) > ProceduralEnergyBeamConfig.forkProbabilityThreshold,
               let anchor = pts.dropLast(Swift.max(0, pts.count / 3)).last {
                let fk = forkPath(from: anchor, endClampX: collisionX - 1.5, lane: lane, salt: seed, wall: wall)
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
                    widthScale: widthJitter * 0.72
                )
            }
        }

        // Opponent side (orange / ember)
        for lane in 0 ..< ProceduralEnergyBeamConfig.lanesPerSide {
            let laneSalt = lane | 0x2000
            let spread: CGFloat = 5.5 + CGFloat(lane % 5) * 3.4
            let pts = organicTendrilPoints(
                startX: collisionX + gap,
                endX: rightPad,
                midY: midY,
                lane: laneSalt,
                salt: seed,
                wall: wall,
                baseSpread: spread
            )
            let earlyFade = deterministic01(lane: laneSalt, step: 88, salt: seed) < 0.24
            let opacityScale: CGFloat = earlyFade
                ? 0.48 + deterministic01(lane: laneSalt, step: 89, salt: seed) * 0.3
                : 1
            let widthJitter = 0.9 + deterministic01(lane: laneSalt, step: 90, salt: seed) * 0.26
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
                widthScale: widthJitter
            )

            if deterministic01(lane: laneSalt, step: 77, salt: seed) > ProceduralEnergyBeamConfig.forkProbabilityThreshold,
               let anchor = pts.dropLast(Swift.max(0, pts.count / 3)).last {
                let fk = forkPath(from: anchor, endClampX: rightPad, lane: laneSalt, salt: seed, wall: wall)
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
                    widthScale: widthJitter * 0.7
                )
            }
        }

        coreSpine(context: &context, from: leftPad, to: collisionX - 2.5, midY: midY, wall: wall, seed: seed, flicker: flicker, impact: impact, tint: BeamTeamColors.userBloom, isUser: true)
        coreSpine(context: &context, from: collisionX + 2.5, to: rightPad, midY: midY, wall: wall, seed: seed, flicker: flicker, impact: impact, tint: BeamTeamColors.oppBloom, isUser: false)

        drawCollisionBurst(
            context: &context,
            collisionX: collisionX,
            midY: midY,
            flicker: flicker,
            impact: impact,
            flareMul: flareMul,
            wall: wall,
            sparkBoost: CGFloat(impact * 28 + 10),
            seed: seed
        )
    }

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
            with: .color(wideColor.opacity((0.14 + Double(widen) * 0.014) * fk * op)),
            style: StrokeStyle(lineWidth: (12 + widen * 0.4) * widthScale, lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            path,
            with: .color(midTint.opacity((0.22 + Double(widen) * 0.022) * fk * op)),
            style: StrokeStyle(lineWidth: (5.5 + widen * 0.22) * widthScale, lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            path,
            with: .color(deepTint.opacity((0.16 + Double(widen) * 0.018) * fk * op)),
            style: StrokeStyle(lineWidth: (3.2 + widen * 0.12) * widthScale, lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            path,
            with: .color(coreHot.opacity((0.62 + Double(widen) * 0.055) * fk * op)),
            style: StrokeStyle(lineWidth: (2 + widen * 0.12) * widthScale, lineCap: .round, lineJoin: .round)
        )
        context.blendMode = .plusLighter
        context.stroke(
            path,
            with: .color(Color.white.opacity((0.82 + Double(widen) * 0.14) * fk * op)),
            style: StrokeStyle(lineWidth: (0.9 + widen * 0.06) * widthScale, lineCap: .round, lineJoin: .round)
        )
    }

    private static func coreSpine(
        context: inout GraphicsContext,
        from x0: CGFloat,
        to x1: CGFloat,
        midY: CGFloat,
        wall: TimeInterval,
        seed: Int,
        flicker: CGFloat,
        impact: CGFloat,
        tint: Color,
        isUser: Bool
    ) {
        guard x1 > x0 + 2 else { return }
        let ph = wall * .pi * 2 * (isUser ? 0.62 : 0.71) + Double(seed & 31) * 0.05
        let wobbleA = CGFloat(sin(ph * 1.9)) * 1.25
        let wobbleB = CGFloat(cos(ph * 3.1 + 0.7)) * 0.55
        var p = Path()
        p.move(to: CGPoint(x: x0, y: midY + wobbleA))
        p.addQuadCurve(
            to: CGPoint(x: x1, y: midY - wobbleB * 0.45),
            control: CGPoint(x: (x0 + x1) * 0.5, y: midY + wobbleB * 1.1)
        )
        let iw = CGFloat(1.05 + impact * 2.15) * CGFloat(0.95 + deterministic01(lane: isUser ? 31 : 32, step: 0, salt: seed) * 0.22)
        context.blendMode = .normal
        context.stroke(p, with: .color(Color.white.opacity(Double(0.1 * flicker))), style: StrokeStyle(lineWidth: iw + 3.4, lineCap: .round))
        context.blendMode = .plusLighter
        context.stroke(p, with: .color(Color.white.opacity(Double((0.55 + Double(impact) * 0.5) * Double(flicker)))), style: StrokeStyle(lineWidth: iw + 1.3, lineCap: .round))
        context.stroke(p, with: .color(tint.opacity(Double((0.38 + Double(impact) * 0.42) * Double(flicker)))), style: StrokeStyle(lineWidth: iw + 0.75, lineCap: .round))
        context.stroke(p, with: .color(Color.white.opacity(Double((0.92 + Double(impact) * 0.55) * Double(flicker)))), style: StrokeStyle(lineWidth: iw * 0.55, lineCap: .round))
    }

    private static func drawCollisionBurst(
        context: inout GraphicsContext,
        collisionX: CGFloat,
        midY: CGFloat,
        flicker: CGFloat,
        impact: CGFloat,
        flareMul: CGFloat,
        wall: TimeInterval,
        sparkBoost: CGFloat,
        seed: Int
    ) {
        let idlePhase = wall * .pi * 2.1

        context.blendMode = .normal
        let baseR: CGFloat = 8 + flareMul * 7
        let outer = CGRect(x: collisionX - baseR - 16, y: midY - baseR - 16, width: (baseR + 16) * 2, height: (baseR + 16) * 2)
        context.fill(
            ellipsePath(outer),
            with: .radialGradient(
                Gradient(colors: [Color.white.opacity(Double(0.18 + Double(flicker) * 0.12 + Double(impact) * 0.55)), Color.clear]),
                center: CGPoint(x: collisionX, y: midY),
                startRadius: 0,
                endRadius: baseR + 20 + flareMul * 11
            )
        )

        let heatCenter = CGPoint(x: collisionX + 4 + CGFloat(impact) * 3, y: midY + CGFloat(sin(idlePhase * 1.2)) * 1.5)
        let heatR = CGRect(x: heatCenter.x - 18, y: heatCenter.y - 12, width: 36, height: 24)
        context.fill(
            ellipsePath(heatR),
            with: .radialGradient(
                Gradient(colors: [BeamTeamColors.oppEmber.opacity(0.45 + Double(impact) * 0.25), BeamTeamColors.oppBloom.opacity(0.12), Color.clear]),
                center: heatCenter,
                startRadius: 0,
                endRadius: 16 + CGFloat(impact) * 12
            )
        )

        context.blendMode = .plusLighter
        let hot = CGRect(x: collisionX - 6 - flareMul * 2, y: midY - 6 - flareMul * 2, width: 12 + flareMul * 4, height: 12 + flareMul * 4)
        context.fill(
            ellipsePath(hot),
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(Double(0.98 + Double(impact) * 0.04)),
                    BeamTeamColors.userMid.opacity(0.35),
                    BeamTeamColors.oppMid.opacity(0.28),
                    Color.clear,
                ]),
                center: CGPoint(x: collisionX, y: midY),
                startRadius: 0,
                endRadius: 5 + flareMul * 5
            )
        )

        let ringPulse = 0.55 + 0.45 * sin(wall * 6.2 + Double(seed & 7))
        for ri in 0 ..< 2 {
            let rr: CGFloat = 10 + CGFloat(ri) * 9 + CGFloat(impact) * 14 + CGFloat(ringPulse) * 2.5
            let rect = CGRect(x: collisionX - rr, y: midY - rr * 0.72, width: rr * 2, height: rr * 1.44)
            let ring = ellipsePath(rect)
            context.stroke(
                ring,
                with: .color(Color.white.opacity(Double(0.08 + Double(impact) * 0.22 + Double(flicker) * 0.06 - Double(ri) * 0.025))),
                style: StrokeStyle(lineWidth: 1.1 + CGFloat(impact) * 1.2, lineCap: .round)
            )
        }

        context.blendMode = .plusLighter
        let count = ProceduralEnergyBeamConfig.sparkCount
        let sparkIdlePop = sin(wall * 13.7 + Double(seed)) > 0.92 ? 1.15 : 1.0
        for si in 0 ..< count {
            let fu = deterministic01(lane: 6000 + si, step: seed & 0xffff, salt: seed)
            let fv = deterministic01(lane: 7000 + si, step: seed & 0xffff, salt: seed ^ (seed &* 50_069) ^ (si &* 9_743))
            var ang = fu * CGFloat.pi * 2 + CGFloat(idlePhase * 0.38 * (fv > 0.5 ? 1 : -1))
            ang += CGFloat(impact * 2.45 * sin(Double(si) + Double(impact) * Double.pi))
            let drift = CGFloat(sin(wall * 8.1 + Double(si) * 1.7)) * 2.2

            let baseLen: CGFloat = 4 + fv * CGFloat(14 + sparkBoost + impact * 34) * CGFloat(sparkIdlePop)
            let len = baseLen + CGFloat(Double(impact) * 32)
            let cx = collisionX + CGFloat(cos(Double(ang))) * (2 + CGFloat(fu * 12 * impact)) + drift * 0.4
            let cy = midY + CGFloat(sin(Double(ang))) * (2 + CGFloat(fv * 9 * impact))

            var sp = Path()
            let x1 = cx + CGFloat(cos(Double(ang))) * len * 1.1
            let y1 = cy + CGFloat(sin(Double(ang))) * len * 1.1
            sp.move(to: CGPoint(x: cx, y: cy))
            let kink = CGFloat(sin(idlePhase * 3.4 + Double(si))) * 3.4
            let angD = Double(ang)
            sp.addQuadCurve(
                to: CGPoint(x: x1 + kink * 0.35, y: y1),
                control: CGPoint(x: cx + CGFloat(cos(angD + 0.6)) * len * 0.45 + kink, y: cy + CGFloat(sin(angD + 0.55)) * len * 0.45)
            )

            let hotLine = CGFloat(0.85 + fu * CGFloat(impact) * 3.45)
            let alpha = 0.22 + Double(fv) * Double(impact) * 0.95 + Double(flicker) * Double(impact) * 0.48 + sin(wall * 15 + Double(si)) * 0.06
            let aClamped = min(0.98, max(0.12, alpha + Double(impact) * 0.42))
            context.stroke(
                sp,
                with: .color(Color.white.opacity(aClamped)),
                style: StrokeStyle(lineWidth: hotLine + CGFloat(impact) * 3.5, lineCap: .round)
            )
            context.stroke(sp, with: .color(Color.white.opacity(0.92)), style: StrokeStyle(lineWidth: 0.55 + CGFloat(impact) * 1.05, lineCap: .round))
        }

        context.blendMode = .normal
        let microCount = Swift.min(Int(6 + CGFloat(impact * 24)), 8)
        for mi in 0 ..< microCount {
            let u = deterministic01(lane: mi, step: seed, salt: seed ^ mi)
            let dx = CGFloat(cos(u * CGFloat.pi * 2 + CGFloat(idlePhase + wall * 0.7)))
            let dy = CGFloat(sin(u * CGFloat.pi * 2 + CGFloat(idlePhase * 0.85)))
            let rr: CGFloat = 0.9 + CGFloat(impact) * 3.1
            let flick = sin(wall * 19 + Double(mi)) > 0.85 ? CGFloat(1.4) : 1
            let spot = CGRect(
                x: collisionX + dx * CGFloat(3 + CGFloat(impact) * 26) + CGFloat(sin(Double(mi) + idlePhase)),
                y: midY + dy * CGFloat(2 + CGFloat(impact) * 20),
                width: rr * flick,
                height: rr * flick
            )
            context.fill(
                ellipsePath(spot),
                with: .color(Color.white.opacity(Double(min(1, 0.1 + Double(impact) * 0.95 + Double(flicker) * 0.03))))
            )
        }
    }
}

// MARK: - Momentum chip

private enum MomentumState: Equatable {
    case leadGrowing
    case leadShrinking
    case closeBattle
    case needsPush

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

private struct DayBattleSparklinePreview: View {
    let userValues: [CGFloat]
    let opponentValues: [CGFloat]

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let ptsU = sampledPoints(for: userValues, in: CGSize(width: w, height: h), pad: CGPoint(x: 10, y: 10))
                let ptsO = sampledPoints(for: opponentValues, in: CGSize(width: w, height: h), pad: CGPoint(x: 10, y: 10))

                ZStack {
                    roundedChartBackground()

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

    private func roundedChartBackground() -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.black.opacity(0.32))
    }

    private func subtleGrid(rect: CGRect) -> some View {
        Path { p in
            let cols = [rect.minX + rect.width * 0.25, rect.minX + rect.width * 0.5, rect.minX + rect.width * 0.75]
            for x in cols {
                p.move(to: CGPoint(x: x, y: rect.minY + 12))
                p.addLine(to: CGPoint(x: x, y: rect.maxY - 12))
            }
            let rows = [rect.minY + rect.height * 0.34, rect.minY + rect.height * 0.66]
            for y in rows {
                p.move(to: CGPoint(x: rect.minX + 12, y: y))
                p.addLine(to: CGPoint(x: rect.maxX - 12, y: y))
            }
        }
        .stroke(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: 1, dash: [2, 6]))
        .blur(radius: 0)
    }

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

    private func sparkline(points: [CGPoint], color: Color, glowMultiplier: CGFloat) -> some View {
        let path = smoothPath(for: points)
        return path
            .stroke(color.opacity(0.72 * Double(glowMultiplier)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            .blur(radius: 4.5 + glowMultiplier)
            .overlay(
                path.stroke(color.opacity(0.94), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            )
    }

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

private struct DayElapsedProgressPreview: View {
    let fractionElapsed: CGFloat

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

            Text(dayProgressLabelMock)
                .font(FitUpFont.body(12, weight: .regular))
                .foregroundStyle(FitUpColors.Text.secondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.94)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity)
    }

    /// Fixed mock caption per spec visuals.
    private var dayProgressLabelMock: String {
        "3 PM · 62% of day elapsed"
    }
}

// MARK: - Formatters

private enum EnergyBeamNumberFormatting {
    static let score: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = ","
        nf.usesGroupingSeparator = true
        return nf
    }()

    static let steps: NumberFormatter = score
}

#Preview {
    EnergyBeamHeroPrototypeView()
}

#endif
