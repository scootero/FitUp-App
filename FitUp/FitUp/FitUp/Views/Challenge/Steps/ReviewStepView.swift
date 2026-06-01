//
//  ReviewStepView.swift
//  FitUp
//
//  Slice 4: battle difficulty, VS card theming, directed-opponent rules.
//

import SwiftUI

struct ReviewStepView: View {
    let profile: Profile?
    let selectedMetric: ChallengeMetricType
    let selectedFormat: ChallengeFormatType
    let selectedOpponent: ChallengeOpponent?
    let isQuickMatch: Bool
    let isDirectedOpponent: Bool
    let isSending: Bool
    @Binding var scoringMode: MatchScoringModePreference
    @Binding var difficulty: MatchDifficultyPreference
    var onSend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            vsCard

            if selectedMetric == .steps {
                battleDifficultySection
            }

            Button {
                onSend()
            } label: {
                HStack(spacing: 8) {
                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.black)
                        Text("Sending...")
                            .font(FitUpFont.body(16, weight: .heavy))
                            .foregroundStyle(.black)
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Send Battle!")
                            .font(FitUpFont.body(16, weight: .heavy))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .solidButton(color: FitUpColors.Neon.cyan)
            .disabled(isSending)
            .opacity(isSending ? 0.8 : 1)
        }
        .onAppear {
            enforceDirectedDifficultyIfNeeded()
        }
        .onChange(of: scoringMode) { _, _ in
            enforceDirectedDifficultyIfNeeded()
        }
    }

    private var vsCard: some View {
        VStack(spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                vsCombatantColumn(
                    initials: profile?.initials ?? "YOU",
                    label: "You",
                    accent: FitUpColors.Neon.cyan,
                    glow: true
                )

                vsCenterMark

                vsCombatantColumn(
                    initials: opponentInitials,
                    label: opponentName,
                    accent: FitUpColors.Neon.orange,
                    glow: true
                )
            }

            HStack(spacing: 8) {
                NeonBadge(label: selectedMetric.displayName, color: FitUpColors.Neon.cyan)
                NeonBadge(label: selectedFormat.displayName, color: FitUpColors.Neon.orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 22)
        .homeLiquidGlassCard(.win)
        .overlay {
            RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            FitUpColors.Neon.cyan.opacity(0.55),
                            FitUpColors.Neon.orange.opacity(0.45),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1.5
                )
        }
        .shadow(color: FitUpColors.Neon.cyan.opacity(0.10), radius: 16, x: -4, y: 0)
        .shadow(color: FitUpColors.Neon.orange.opacity(0.10), radius: 16, x: 4, y: 0)
    }

    private func vsCombatantColumn(
        initials: String,
        label: String,
        accent: Color,
        glow: Bool
    ) -> some View {
        VStack(spacing: 8) {
            AvatarView(
                initials: initials,
                color: accent,
                size: 54,
                glow: glow
            )
            Text(label)
                .font(FitUpFont.body(12, weight: .bold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var vsCenterMark: some View {
        VStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("VS")
                .font(FitUpFont.display(22, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .frame(minWidth: 52)
    }

    private var battleDifficultySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Battle difficulty")
                .font(FitUpFont.body(12, weight: .heavy))
                .foregroundStyle(FitUpColors.Text.secondary)
                .tracking(0.6)

            VStack(alignment: .leading, spacing: 8) {
                Text("Scoring")
                    .font(FitUpFont.mono(10, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.tertiary)

                ChallengeNeonSegmentControl(
                    options: MatchScoringModePreference.allCases,
                    selection: $scoringMode,
                    title: { $0.title }
                )

                Text(scoringMode.subtitle)
                    .font(FitUpFont.body(13, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.primary.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)

                if scoringMode == .balanced {
                    Text("Difficulty is not used for Balanced Battle.")
                        .font(FitUpFont.body(12, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if scoringMode == .raw {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Difficulty")
                        .font(FitUpFont.mono(10, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.tertiary)

                    ChallengeNeonSegmentControl(
                        options: MatchDifficultyPreference.allCases,
                        selection: $difficulty,
                        title: { $0.title },
                        isOptionEnabled: { level in
                            !isDirectedOpponent || level == .fair
                        }
                    )

                    Text(difficulty.subtitle)
                        .font(FitUpFont.body(13, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.primary.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)

                    if isDirectedOpponent {
                        Text(MatchDifficultyPreference.directedOpponentFootnote)
                            .font(FitUpFont.body(12, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("If no close opponent is found, the search may widen to find a battle faster.")
                            .font(FitUpFont.body(11, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeLiquidGlassCard(.pending)
        .overlay {
            RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            FitUpColors.Neon.cyan.opacity(0.4),
                            FitUpColors.Neon.purple.opacity(0.28),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    private var opponentName: String {
        if isQuickMatch {
            return "Random Opponent"
        }
        return selectedOpponent?.displayName ?? "Opponent"
    }

    private var opponentInitials: String {
        if isQuickMatch {
            return "??"
        }
        return selectedOpponent?.initials ?? "OP"
    }

    private func enforceDirectedDifficultyIfNeeded() {
        guard isDirectedOpponent, scoringMode == .raw else { return }
        difficulty = .fair
    }
}

// MARK: - Neon segment control

private struct ChallengeNeonSegmentControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    var isOptionEnabled: (Option) -> Bool = { _ in true }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                segmentButton(for: option)
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
    }

    private func segmentButton(for option: Option) -> some View {
        let enabled = isOptionEnabled(option)
        let isSelected = selection == option

        return Button {
            guard enabled else { return }
            selection = option
        } label: {
            Text(title(option))
                .font(FitUpFont.body(12, weight: isSelected ? .heavy : .semibold))
                .foregroundStyle(segmentForeground(isSelected: isSelected, enabled: enabled))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: FitUpRadius.sm - 2, style: .continuous)
                            .fill(FitUpColors.Neon.cyan.opacity(0.18))
                            .overlay {
                                RoundedRectangle(cornerRadius: FitUpRadius.sm - 2, style: .continuous)
                                    .strokeBorder(FitUpColors.Neon.cyan.opacity(0.35), lineWidth: 1)
                            }
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.38)
    }

    private func segmentForeground(isSelected: Bool, enabled: Bool) -> Color {
        if !enabled { return FitUpColors.Text.tertiary }
        if isSelected { return FitUpColors.Neon.cyan }
        return FitUpColors.Text.secondary
    }
}
