//
//  OpponentStepView.swift
//  FitUp
//
//  Slice 4 step 2: choose quick match or a specific opponent.
//

import SwiftUI

struct OpponentStepView: View {
    @Binding var query: String
    let opponents: [ChallengeOpponent]
    let isLoading: Bool
    var onQuickMatch: () -> Void
    var onSelectOpponent: (ChallengeOpponent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who do you want to challenge?")
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)

            searchField
            quickMatchCard

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .tint(FitUpColors.Neon.cyan)
            } else if opponents.isEmpty {
                Text("No players found.")
                    .font(FitUpFont.body(12, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.tertiary)
                    .padding(.top, 2)
            } else {
                VStack(spacing: 8) {
                    ForEach(opponents) { opponent in
                        Button {
                            onSelectOpponent(opponent)
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(
                                    initials: opponent.initials,
                                    color: color(from: opponent.colorHex),
                                    size: 38
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(opponent.displayName)
                                        .font(FitUpFont.display(13, weight: .bold))
                                        .foregroundStyle(FitUpColors.Text.primary)
                                    Text(statLine(for: opponent))
                                        .font(FitUpFont.body(11, weight: .medium))
                                        .foregroundStyle(FitUpColors.Text.secondary)
                                }

                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(FitUpColors.Text.tertiary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .glassCard(.base)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.tertiary)
            TextField("Search players...", text: $query)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .font(FitUpFont.body(14, weight: .regular))
                .foregroundStyle(FitUpColors.Text.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassCard(.base)
        .clipShape(Capsule(style: .continuous))
    }

    private var quickMatchCard: some View {
        Button {
            onQuickMatch()
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(FitUpColors.Neon.purple.opacity(0.14))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Circle()
                            .strokeBorder(FitUpColors.Neon.purple.opacity(0.28), lineWidth: 1)
                    }
                    .overlay {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(FitUpColors.Neon.purple)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick Match")
                        .font(FitUpFont.display(13, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.primary)
                    Text("Find best available opponent")
                        .font(FitUpFont.body(11, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }

                Spacer(minLength: 0)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(FitUpColors.Neon.purple)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassCard(.pending)
        }
        .buttonStyle(.plain)
    }

    private func statLine(for opponent: ChallengeOpponent) -> String {
        let winsLosses: String
        if let wins = opponent.wins, let losses = opponent.losses {
            winsLosses = "\(wins)W · \(losses)L"
        } else {
            winsLosses = "--W · --L"
        }
        let steps = opponent.todaySteps.map { "\($0.formatted()) today" } ?? "-- today"
        return "\(winsLosses) · \(steps)"
    }

    private func color(from hex: String) -> Color {
        guard let value = UInt32(hex, radix: 16) else {
            return FitUpColors.Neon.blue
        }
        return Color(rgb: value)
    }
}

