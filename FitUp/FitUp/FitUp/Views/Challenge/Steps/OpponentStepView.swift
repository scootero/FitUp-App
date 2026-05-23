//
//  OpponentStepView.swift
//  FitUp
//
//  Slice 3: choose quick match or a specific opponent.
//

import SwiftUI

struct OpponentStepView: View {
    @Binding var query: String
    let opponents: [ChallengeOpponent]
    let isLoading: Bool
    var onQuickMatch: () -> Void
    var onSelectOpponent: (ChallengeOpponent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            quickMatchCard

            Text("Who do you want to battle?")
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)

            searchField

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
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Text("DEFAULT")
                        .font(FitUpFont.mono(10, weight: .black))
                        .foregroundStyle(FitUpColors.Neon.purple)
                        .tracking(1.4)
                    Spacer(minLength: 0)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(FitUpColors.Neon.purple)
                }

                HStack(spacing: 14) {
                    Circle()
                        .fill(FitUpColors.Neon.purple.opacity(0.18))
                        .frame(width: 52, height: 52)
                        .overlay {
                            Circle()
                                .strokeBorder(FitUpColors.Neon.purple.opacity(0.45), lineWidth: 1.5)
                        }
                        .overlay {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(FitUpColors.Neon.purple)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quick Battle")
                            .font(FitUpFont.display(18, weight: .black))
                            .foregroundStyle(FitUpColors.Text.primary)
                        Text("Find the best available opponent instantly")
                            .font(FitUpFont.body(12, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                FitUpColors.Neon.purple.opacity(0.14),
                                FitUpColors.Neon.blue.opacity(0.06),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.35)
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                FitUpColors.Neon.purple.opacity(0.85),
                                FitUpColors.Neon.cyan.opacity(0.45),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
            }
            .shadow(color: FitUpColors.Neon.purple.opacity(0.22), radius: 18, x: 0, y: 6)
            .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(QuickBattleCardButtonStyle())
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

private struct QuickBattleCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .offset(y: configuration.isPressed ? 2 : 0)
            .shadow(
                color: FitUpColors.Neon.purple.opacity(configuration.isPressed ? 0.10 : 0.22),
                radius: configuration.isPressed ? 8 : 18,
                x: 0,
                y: configuration.isPressed ? 2 : 6
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
