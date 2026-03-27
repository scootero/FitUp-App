//
//  DiscoverSection.swift
//  FitUp
//
//  Slice 3 discover users section.
//

import SwiftUI

struct DiscoverSection: View {
    let users: [HomeDiscoverUser]
    var onChallenge: (HomeDiscoverUser) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Discover Players", actionTitle: "See All")

            ForEach(users) { user in
                HStack(spacing: 12) {
                    AvatarView(
                        initials: user.initials,
                        color: color(from: user.colorHex),
                        size: 38
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.displayName)
                            .font(FitUpFont.display(13, weight: .bold))
                            .foregroundStyle(FitUpColors.Text.primary)

                        Text(statLine(for: user))
                            .font(FitUpFont.body(11, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.secondary)
                    }

                    Spacer(minLength: 0)

                    Button {
                        onChallenge(user)
                    } label: {
                        Label("Challenge", systemImage: "bolt.fill")
                            .font(FitUpFont.body(12, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .ghostButton(color: FitUpColors.Neon.cyan)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .glassCard(.base)
            }
        }
    }

    private func statLine(for user: HomeDiscoverUser) -> String {
        let steps = user.todaySteps.map { "\($0.formatted()) steps" } ?? "-- steps"
        if let wins = user.wins, let losses = user.losses {
            return "\(steps) · \(wins)W \(losses)L"
        }
        return steps
    }

    private func color(from hex: String) -> Color {
        guard let value = UInt32(hex, radix: 16) else {
            return FitUpColors.Neon.blue
        }
        return Color(rgb: value)
    }
}
