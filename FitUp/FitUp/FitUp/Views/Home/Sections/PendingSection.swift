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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Pending", actionTitle: "\(matches.count) new")

            ForEach(matches) { match in
                HStack(spacing: 12) {
                    Button {
                        onOpenMatch(match)
                    } label: {
                        HStack(spacing: 12) {
                            AvatarView(
                                initials: match.opponent.initials,
                                color: color(from: match.opponent.colorHex),
                                size: 40
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(match.opponent.displayName)
                                    .font(FitUpFont.display(14, weight: .bold))
                                    .foregroundStyle(FitUpColors.Text.primary)
                                Text("\(match.sportLabel) · \(match.seriesLabel)")
                                    .font(FitUpFont.body(11, weight: .medium))
                                    .foregroundStyle(FitUpColors.Text.secondary)
                            }

                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        Button {
                            onDecline(match)
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
                            onAccept(match)
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
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .glassCard(.pending)
                .disabled(activeActionMatchID == match.id)
                .opacity(activeActionMatchID == match.id ? 0.6 : 1)
            }
        }
    }

    private func color(from hex: String) -> Color {
        guard let value = UInt32(hex, radix: 16) else {
            return FitUpColors.Neon.blue
        }
        return Color(rgb: value)
    }
}
