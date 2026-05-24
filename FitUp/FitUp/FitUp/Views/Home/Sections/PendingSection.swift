//
//  PendingSection.swift
//  FitUp
//
//  Slice 3 pending challenges section.
//

import SwiftUI

struct PendingSection: View {
    enum Mode {
        case actionRequired
        case waitingOnOpponent
    }

    let title: String
    let matches: [HomePendingMatch]
    let mode: Mode
    let activeActionMatchID: UUID?
    var onOpenMatch: (HomePendingMatch) -> Void
    var onAccept: (HomePendingMatch) -> Void
    var onDecline: (HomePendingMatch) -> Void

    @State private var declineConfirmMatch: HomePendingMatch?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title, actionTitle: sectionCountLabel)

            ForEach(matches) { match in
                PendingMatchRow(
                    match: match,
                    mode: mode,
                    activeActionMatchID: activeActionMatchID,
                    onOpenMatch: onOpenMatch,
                    onAccept: onAccept,
                    onDeclineRequested: { m in
                        if m.hasAcceptedByMe {
                            declineConfirmMatch = m
                        } else {
                            onDecline(m)
                        }
                    }
                )
            }
        }
        .confirmationDialog(
            "Are you sure you want to decline?",
            isPresented: Binding(
                get: { declineConfirmMatch != nil },
                set: { if !$0 { declineConfirmMatch = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Decline", role: .destructive) {
                if let m = declineConfirmMatch {
                    onDecline(m)
                }
                declineConfirmMatch = nil
            }
            Button("Cancel", role: .cancel) {
                declineConfirmMatch = nil
            }
        }
    }

    private var sectionCountLabel: String {
        switch mode {
        case .actionRequired:
            return matches.count == 1 ? "1 invite" : "\(matches.count) invites"
        case .waitingOnOpponent:
            return matches.count == 1 ? "1 waiting" : "\(matches.count) waiting"
        }
    }
}

// MARK: - Row

private struct PendingMatchRow: View {
    let match: HomePendingMatch
    let mode: PendingSection.Mode
    let activeActionMatchID: UUID?
    var onOpenMatch: (HomePendingMatch) -> Void
    var onAccept: (HomePendingMatch) -> Void
    var onDeclineRequested: (HomePendingMatch) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                onOpenMatch(match)
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    AvatarView(
                        initials: match.opponent.initials,
                        color: color(from: match.opponent.colorHex),
                        size: 40
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(titleText)
                            .font(FitUpFont.display(15, weight: .bold))
                            .foregroundStyle(HomePageStyle.offWhite)
                            .lineLimit(2)
                        HStack(spacing: 5) {
                            Image(systemName: subtitleIconName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(subtitleIconColor)
                            Text(subtitleText)
                                .font(FitUpFont.body(13, weight: .medium))
                                .foregroundStyle(HomePageStyle.muted)
                        }
                        Text("\(match.sportLabel) · \(match.seriesLabel)")
                            .font(FitUpFont.mono(11, weight: .semibold))
                            .foregroundStyle(HomePageStyle.faint)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            if mode == .actionRequired {
                HStack(spacing: 8) {
                    Button {
                        onDeclineRequested(match)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(FitUpColors.Neon.pink)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(FitUpColors.Neon.pink.opacity(0.12))
                                    .overlay(Circle().strokeBorder(FitUpColors.Neon.pink.opacity(0.25), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                            onAccept(match)
                        }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(FitUpColors.Neon.cyan)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(FitUpColors.Neon.cyan.opacity(0.12))
                                    .overlay(Circle().strokeBorder(FitUpColors.Neon.cyan.opacity(0.25), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                waitingIndicator
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .homeLiquidGlassCard(mode == .actionRequired ? .pending : .base)
        .overlay {
            if mode == .waitingOnOpponent {
                RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                    .strokeBorder(FitUpColors.Neon.orange.opacity(0.18), lineWidth: 1)
            }
        }
        .disabled(activeActionMatchID == match.id)
        .opacity(activeActionMatchID == match.id ? 0.6 : 1)
    }

    private var titleText: String {
        switch mode {
        case .actionRequired:
            if match.matchType == "direct_challenge" {
                return "\(match.opponent.displayName) invited you to battle"
            }
            return "Opponent found: \(match.opponent.displayName)"
        case .waitingOnOpponent:
            return "Invite sent to \(match.opponent.displayName)"
        }
    }

    private var subtitleText: String {
        switch mode {
        case .actionRequired:
            return "Accept to start battle"
        case .waitingOnOpponent:
            return "Waiting on response"
        }
    }

    private var subtitleIconName: String {
        switch mode {
        case .actionRequired:
            return "bolt.fill"
        case .waitingOnOpponent:
            return "clock.arrow.circlepath"
        }
    }

    private var subtitleIconColor: Color {
        switch mode {
        case .actionRequired:
            return FitUpColors.Neon.cyan
        case .waitingOnOpponent:
            return FitUpColors.Neon.orange
        }
    }

    private var waitingIndicator: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock")
                .font(.system(size: 11, weight: .bold))
            Text("Waiting")
                .font(FitUpFont.mono(10, weight: .bold))
        }
        .foregroundStyle(FitUpColors.Neon.orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(FitUpColors.Neon.orange.opacity(0.12))
                .overlay(
                    Capsule()
                        .strokeBorder(FitUpColors.Neon.orange.opacity(0.28), lineWidth: 1)
                )
        )
    }

    private func color(from hex: String) -> Color {
        guard let value = UInt32(hex, radix: 16) else {
            return FitUpColors.Neon.blue
        }
        return Color(rgb: value)
    }
}
