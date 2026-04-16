//
//  PendingSection.swift
//  FitUp
//
//  Slice 3 pending challenges section.
//

import SwiftUI

struct PendingSection: View {
    let matches: [HomePendingMatch]
    let activeActionMatchID: UUID?
    var onOpenMatch: (HomePendingMatch) -> Void
    var onAccept: (HomePendingMatch) -> Void
    var onDecline: (HomePendingMatch) -> Void

    @State private var declineConfirmMatch: HomePendingMatch?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Pending", actionTitle: "\(matches.count) new")

            ForEach(matches) { match in
                PendingMatchRow(
                    match: match,
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
}

// MARK: - Row

private struct PendingMatchRow: View {
    let match: HomePendingMatch
    let activeActionMatchID: UUID?
    var onOpenMatch: (HomePendingMatch) -> Void
    var onAccept: (HomePendingMatch) -> Void
    var onDeclineRequested: (HomePendingMatch) -> Void

    @State private var glowPulse = false
    /// Starts true so the burst ring is hidden until we animate accept; avoids a one-frame flash on load.
    @State private var ringExpand = true

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
                        Text(match.opponent.displayName)
                            .font(FitUpFont.display(14, weight: .bold))
                            .foregroundStyle(FitUpColors.Text.primary)
                        Text("\(match.sportLabel) · \(match.seriesLabel)")
                            .font(FitUpFont.body(11, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.secondary)
                        if match.hasAcceptedByMe, !match.hasAcceptedByOpponent {
                            Text("Waiting for \(match.opponent.displayName) to accept")
                                .font(FitUpFont.mono(10, weight: .semibold))
                                .foregroundStyle(FitUpColors.Neon.cyan.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

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

                if match.hasAcceptedByMe {
                    acceptLockedButton
                } else {
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
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard(.pending)
        .disabled(activeActionMatchID == match.id)
        .opacity(activeActionMatchID == match.id ? 0.6 : 1)
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: match.hasAcceptedByMe)
        .onAppear {
            guard match.hasAcceptedByMe else { return }
            startLockedGlowPulse()
        }
        .onChange(of: match.hasAcceptedByMe) { wasAccepted, accepted in
            guard accepted, !wasAccepted else { return }
            ringExpand = false
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                ringExpand = true
            }
            startLockedGlowPulse()
        }
        .onChange(of: match.id) { _, _ in
            ringExpand = true
            glowPulse = false
        }
    }

    private func startLockedGlowPulse() {
        glowPulse = false
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            glowPulse = true
        }
    }

    private var acceptLockedButton: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            FitUpColors.Neon.cyan.opacity(0.85),
                            FitUpColors.Neon.green.opacity(0.45),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 36, height: 36)
                .scaleEffect(ringExpand ? 1.45 : 1)
                .opacity(ringExpand ? 0 : 0.75)

            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.cyan.opacity(0.75)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                )
                .shadow(color: FitUpColors.Neon.cyan.opacity(0.5), radius: glowPulse ? 12 : 5)
                .scaleEffect(glowPulse ? 1.05 : 1)
        }
        .frame(width: 48, height: 48)
        .accessibilityLabel("You accepted this match")
    }

    private func color(from hex: String) -> Color {
        guard let value = UInt32(hex, radix: 16) else {
            return FitUpColors.Neon.blue
        }
        return Color(rgb: value)
    }
}
