//
//  FriendRequestRetroCard.swift
//  FitUp
//
//  Glass friend-invite card for incoming requests on Home.
//

import SwiftUI

struct FriendRequestRetroCard: View {
    let fromName: String
    let isLoading: Bool
    var onAccept: () -> Void
    var onLater: () -> Void
    var onOpenFriends: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FRIEND INVITE")
                    .font(FitUpFont.mono(10, weight: .black))
                    .foregroundStyle(FitUpColors.Neon.blue)
                    .tracking(1.2)
                Text("\(fromName) wants to team up")
                    .font(FitUpFont.display(16, weight: .heavy))
                    .foregroundStyle(HomePageStyle.offWhite)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                Button {
                    onAccept()
                } label: {
                    Text("Accept")
                        .font(FitUpFont.body(14, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .ghostButton(color: FitUpColors.Neon.cyan)
                .disabled(isLoading)

                Button {
                    onLater()
                } label: {
                    Text("Later")
                        .font(FitUpFont.body(13, weight: .semibold))
                }
                .foregroundStyle(HomePageStyle.muted)
                .disabled(isLoading)
            }

            Button {
                onOpenFriends()
            } label: {
                Text("View in Friends")
                    .font(FitUpFont.body(12, weight: .semibold))
                    .foregroundStyle(FitUpColors.Neon.blue.opacity(0.88))
            }
            .disabled(isLoading)
        }
        .padding(16)
        .homeLiquidGlassCard(.pending)
        .overlay {
            friendInviteInnerGlow
        }
    }

    private var friendInviteInnerGlow: some View {
        GeometryReader { geo in
            let glowRadius = max(geo.size.width, geo.size.height) * 0.78
            RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            FitUpColors.Neon.blue.opacity(0.30),
                            FitUpColors.Neon.cyan.opacity(0.14),
                            FitUpColors.Neon.blue.opacity(0.42),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: glowRadius
                    )
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
    }
}
