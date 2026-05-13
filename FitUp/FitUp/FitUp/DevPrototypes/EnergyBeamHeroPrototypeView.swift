//
//  EnergyBeamHeroPrototypeView.swift
//  FitUp
//
//  DEBUG-only preview harness for the energy beam hero. Shared visuals live in EnergyBeamHeroCore.swift.
//

#if DEBUG

import SwiftUI

// MARK: - Mock constants & preview timing

private enum EnergyBeamHeroMock {
    static let midpointBattleScore = 7_234
    static let baselineMargin = 2_431
    static let beamReferenceValue = EnergyBeamHeroLayout.defaultBeamReferenceValue
}

/// Single place to tune preview-driven transitions (seconds); mirrors core layout constant.
private enum EnergyBeamPreviewTiming {
    static var marginDrivenAnimationSeconds: Double { EnergyBeamHeroLayout.marginDrivenAnimationSeconds }
}

// MARK: - Root (DEBUG hero + preview controls)

struct EnergyBeamHeroPrototypeView: View {
    @State private var margin: Double = Double(EnergyBeamHeroMock.baselineMargin)
    @State private var userSteps = 9_125
    @State private var opponentSteps = 6_530
    @State private var chartWiggleUser: CGFloat = 0
    @State private var chartWiggleOpp: CGFloat = 0

    private var battleMarginInt: Int { Int(margin.rounded(.towardZero)) }
    private var opponentBattleScore: Int { EnergyBeamHeroMock.midpointBattleScore - battleMarginInt / 2 }
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
            VStack(spacing: 20) {
                EnergyBeamHeroGlassCardView(
                    margin: margin,
                    referenceBattleValue: EnergyBeamHeroMock.beamReferenceValue,
                    userName: "Scott",
                    opponentName: "Mike",
                    userSteps: userSteps,
                    opponentSteps: opponentSteps,
                    userBattleScore: userBattleScore,
                    opponentBattleScore: opponentBattleScore,
                    battleScoreColumnTitle: "Battle Score",
                    resultEyebrow: resultEyebrow,
                    resultEyebrowColor: resultEyebrowColor,
                    resultHeroNumberText: resultHeroNumberText,
                    unitLabel: "BATTLE SCORE",
                    sparklineUserValues: EnergyBeamHeroMockSeries.cumulativeUser(wiggle: chartWiggleUser),
                    sparklineOpponentValues: EnergyBeamHeroMockSeries.cumulativeOpponent(wiggle: chartWiggleOpp),
                    dayElapsedFraction: 0.62,
                    dayProgressCaption: "3 PM · 62% of day elapsed",
                    showMockTimelineDebugLabel: true
                )

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

                Slider(
                    value: $margin.animation(.easeInOut(duration: EnergyBeamPreviewTiming.marginDrivenAnimationSeconds)),
                    in: -10_000 ... 10_000,
                    step: 1
                )
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
        withAnimation(.easeInOut(duration: EnergyBeamPreviewTiming.marginDrivenAnimationSeconds)) {
            margin = Double(m)
        }
    }

    private func simulateHealthBump() {
        withAnimation(.easeInOut(duration: EnergyBeamPreviewTiming.marginDrivenAnimationSeconds)) {
            userSteps += Int.random(in: 150 ... 780)
            opponentSteps += Int.random(in: 40 ... 420)
            chartWiggleUser += CGFloat(Double.random(in: 0.04 ... 0.11))
            chartWiggleOpp += CGFloat(Double.random(in: -0.09 ... 0.07))
            margin += Double.random(in: -180 ... 220)
            margin = min(max(margin, -10_000), 10_000)
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
