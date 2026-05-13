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
    static let beamReferenceBattleValue: Int =  EnergyBeamHeroLayout.defaultBeamReferenceValue

    /// Opening slider / state value for battle margin (same units as Home: battle-score points for balanced preview). Directly drives starting **collision X** via the core’s `tanh` mapping. CPU: unchanged.
    static let initialBattleMargin: Double = 100

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

    private var battleMarginInt: Int { Int(margin.rounded(.towardZero)) }
    private var opponentBattleScore: Int { EnergyBeamHeroPrototypeKnobs.mockMidpointBattleScore - battleMarginInt / 2 }
    private var userBattleScore: Int { opponentBattleScore + battleMarginInt }

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

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: EnergyBeamHeroPrototypeKnobs.rootStackSpacing) {
                EnergyBeamHeroGlassCardView(
                    margin: margin,
                    referenceBattleValue: EnergyBeamHeroPrototypeKnobs.beamReferenceBattleValue,
                    userName: EnergyBeamHeroPrototypeKnobs.previewUserName,
                    opponentName: EnergyBeamHeroPrototypeKnobs.previewOpponentName,
                    userSteps: userSteps,
                    opponentSteps: opponentSteps,
                    userBattleScore: userBattleScore,
                    opponentBattleScore: opponentBattleScore,
                    battleScoreColumnTitle: EnergyBeamHeroPrototypeKnobs.previewBattleScoreColumnTitle,
                    resultEyebrow: resultEyebrow,
                    resultEyebrowColor: resultEyebrowColor,
                    resultHeroNumberText: resultHeroNumberText,
                    unitLabel: EnergyBeamHeroPrototypeKnobs.previewUnitLabel,
                    sparklineUserValues: EnergyBeamHeroMockSeries.cumulativeUser(wiggle: chartWiggleUser),
                    sparklineOpponentValues: EnergyBeamHeroMockSeries.cumulativeOpponent(wiggle: chartWiggleOpp),
                    dayElapsedFraction: EnergyBeamHeroPrototypeKnobs.mockDayElapsedFraction,
                    dayProgressCaption: EnergyBeamHeroPrototypeKnobs.mockDayProgressCaption,
                    showMockTimelineDebugLabel: EnergyBeamHeroPrototypeKnobs.showMockTimelineDebugLabel
                )

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
    }

    private var previewControlsSection: some View {
        VStack(alignment: .leading, spacing: EnergyBeamHeroPrototypeKnobs.controlsSectionSpacing) {
            Text("PREVIEW CONTROLS (DEBUG)")
                .font(FitUpFont.body(11, weight: .heavy))
                .foregroundStyle(Color.white.opacity(0.35))
                .tracking(1.8)

            VStack(alignment: .leading, spacing: EnergyBeamHeroPrototypeKnobs.controlsInnerStackSpacing) {
                HStack {
                    Text("Battle margin (\(battleMarginInt))")
                        .font(FitUpFont.body(13, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.secondary)
                    Spacer()
                }

                Slider(
                    value: $margin.animation(EnergyBeamHeroLayout.marginTransitionAnimation(duration: EnergyBeamPreviewTiming.marginDrivenAnimationSeconds)),
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

    private func snapMargin(_ m: Int) {
        let next = Double(m)
        withAnimation(EnergyBeamPreviewTiming.marginAnimation(from: margin, to: next)) {
            margin = next
        }
    }

    private func simulateHealthBump() {
        let start = margin
        var next = start + Double.random(in: EnergyBeamHeroPrototypeKnobs.simulateMarginDeltaRange)
        next = min(
            max(next, EnergyBeamHeroPrototypeKnobs.marginSliderMinimum),
            EnergyBeamHeroPrototypeKnobs.marginSliderMaximum
        )
        withAnimation(EnergyBeamPreviewTiming.marginAnimation(from: start, to: next)) {
            userSteps += Int.random(in: EnergyBeamHeroPrototypeKnobs.simulateUserStepsIncreaseRange)
            opponentSteps += Int.random(in: EnergyBeamHeroPrototypeKnobs.simulateOpponentStepsIncreaseRange)
            chartWiggleUser += CGFloat(Double.random(in: EnergyBeamHeroPrototypeKnobs.simulateSparklineWiggleUserRange))
            chartWiggleOpp += CGFloat(Double.random(in: EnergyBeamHeroPrototypeKnobs.simulateSparklineWiggleOpponentRange))
            margin = next
        }
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
