//
//  ChallengeBattleSetupDock.swift
//  FitUp
//
//  Slice 2 — live summary of the battle being built during the challenge flow.
//

import SwiftUI

struct ChallengeBattleSetupDock: View {
    let currentStepIndex: Int
    let isQuickMatch: Bool
    let opponentDisplayName: String?
    let selectedFormat: ChallengeFormatType?
    let scoringMode: MatchScoringModePreference
    let difficulty: MatchDifficultyPreference

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Battle Setup")
                .font(FitUpFont.body(11, weight: .heavy))
                .foregroundStyle(FitUpColors.Text.secondary)
                .tracking(1.2)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            FitUpColors.Neon.cyan.opacity(0.35),
                            FitUpColors.Neon.purple.opacity(0.2),
                            Color.white.opacity(0.08),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            Text("STEPS BATTLE")
                .font(FitUpFont.mono(11, weight: .bold))
                .foregroundStyle(FitUpColors.Neon.cyan)

            VStack(alignment: .leading, spacing: 6) {
                opponentLine
                durationLine
                difficultyLine
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                .fill(Color(rgb: 0x0A1020).opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    FitUpColors.Neon.cyan.opacity(0.28),
                                    FitUpColors.Neon.orange.opacity(0.18),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var opponentLine: some View {
        let isCurrent = currentStepIndex == 0
        let label: String = {
            if isQuickMatch { return "Random opponent" }
            if let opponentDisplayName, !opponentDisplayName.isEmpty { return opponentDisplayName }
            return "Select Opponent"
        }()
        let showOpponentPrefix = !isQuickMatch && opponentDisplayName != nil && !opponentDisplayName!.isEmpty

        return setupLine(
            prefix: showOpponentPrefix ? "Opponent:" : nil,
            label: label,
            isCurrent: isCurrent,
            isPending: !isQuickMatch && opponentDisplayName == nil,
            accentOpponentName: showOpponentPrefix
        )
    }

    private var durationLine: some View {
        let isCurrent = currentStepIndex == 1
        let label = selectedFormat?.displayName ?? "Select Duration"
        return setupLine(
            prefix: nil,
            label: label,
            isCurrent: isCurrent,
            isPending: selectedFormat == nil,
            accentOpponentName: false
        )
    }

    private var difficultyLine: some View {
        let isCurrent = currentStepIndex == 2
        let label: String = {
            if currentStepIndex < 2 { return "—" }
            switch scoringMode {
            case .balanced: return "Balanced Battle"
            case .raw: return "Raw · \(difficulty.title)"
            }
        }()
        return setupLine(
            prefix: nil,
            label: label,
            isCurrent: isCurrent,
            isPending: currentStepIndex < 2,
            accentOpponentName: false
        )
    }

    private var accessibilitySummary: String {
        let opponent = isQuickMatch ? "Random opponent" : (opponentDisplayName ?? "not selected")
        let duration = selectedFormat?.displayName ?? "not selected"
        let diff = currentStepIndex < 2 ? "pending" : difficultyLineLabel
        return "Battle setup. Steps battle. Opponent \(opponent). Duration \(duration). \(diff)."
    }

    private var difficultyLineLabel: String {
        switch scoringMode {
        case .balanced: return "Balanced battle"
        case .raw: return "Raw \(difficulty.title)"
        }
    }

    private func setupLine(
        prefix: String?,
        label: String,
        isCurrent: Bool,
        isPending: Bool,
        accentOpponentName: Bool
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if isCurrent {
                chevronMarker(">>")
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if let prefix {
                    Text(prefix)
                        .font(FitUpFont.body(12, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }
                Text(label)
                    .font(FitUpFont.body(12, weight: isCurrent ? .bold : .medium))
                    .foregroundStyle(lineColor(isCurrent: isCurrent, isPending: isPending, accentOpponent: accentOpponentName))
            }

            if isCurrent {
                chevronMarker("<<")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chevronMarker(_ text: String) -> some View {
        Text(text)
            .font(FitUpFont.mono(11, weight: .bold))
            .foregroundStyle(FitUpColors.Neon.cyan)
    }

    private func lineColor(isCurrent: Bool, isPending: Bool, accentOpponent: Bool) -> Color {
        if isCurrent { return FitUpColors.Neon.cyan }
        if accentOpponent { return FitUpColors.Neon.orange }
        if isPending { return FitUpColors.Text.tertiary }
        return FitUpColors.Text.primary
    }
}

#Preview("Opponent step") {
    ChallengeBattleSetupDock(
        currentStepIndex: 0,
        isQuickMatch: false,
        opponentDisplayName: nil,
        selectedFormat: nil,
        scoringMode: .raw,
        difficulty: .fair
    )
    .padding()
    .background { BackgroundGradientView() }
}
