//
//  ReviewStepView.swift
//  FitUp
//
//  Slice 4 step 3: review and send.
//

import SwiftUI

struct ReviewStepView: View {
    let profile: Profile?
    let selectedMetric: ChallengeMetricType
    let selectedFormat: ChallengeFormatType
    let selectedOpponent: ChallengeOpponent?
    let isQuickMatch: Bool
    let isSending: Bool
    var onSend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            vsCard

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
                        Text("Send Challenge!")
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
    }

    private var vsCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                VStack(spacing: 6) {
                    AvatarView(
                        initials: profile?.initials ?? "YOU",
                        color: FitUpColors.Neon.cyan,
                        size: 50,
                        glow: true
                    )
                    Text("You")
                        .font(FitUpFont.body(12, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.primary)
                }

                Text("VS")
                    .font(FitUpFont.display(20, weight: .black))
                    .foregroundStyle(FitUpColors.Neon.cyan)

                VStack(spacing: 6) {
                    AvatarView(
                        initials: opponentInitials,
                        color: opponentColor,
                        size: 50
                    )
                    Text(opponentName)
                        .font(FitUpFont.body(12, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.primary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 8) {
                NeonBadge(label: selectedMetric.displayName, color: FitUpColors.Neon.cyan)
                NeonBadge(label: selectedFormat.displayName, color: FitUpColors.Neon.blue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .glassCard(.win)
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

    private var opponentColor: Color {
        if isQuickMatch {
            return FitUpColors.Neon.purple
        }
        if let selectedOpponent, let value = UInt32(selectedOpponent.colorHex, radix: 16) {
            return Color(rgb: value)
        }
        return FitUpColors.Neon.purple
    }
}

