//
//  FriendRequestRetroCard.swift
//  FitUp
//
//  Retro neon "arcade" card for an incoming friend request on Home.
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
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FRIEND INVITE")
                        .font(FitUpFont.mono(10, weight: .black))
                        .foregroundStyle(FitUpColors.Neon.cyan)
                        .tracking(1.2)
                    Text("\(fromName) wants to team up")
                        .font(FitUpFont.display(16, weight: .heavy))
                        .foregroundStyle(FitUpColors.Text.primary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 0) {
                FriendRequestScanLineStripes()
                    .frame(height: 2)
                    .clipShape(Capsule())
            }
            .opacity(0.6)

            HStack(spacing: 10) {
                Button {
                    onAccept()
                } label: {
                    Text("Accept")
                        .font(FitUpFont.body(14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(NeonCyanOutlineButtonStyle())
                .disabled(isLoading)

                Button {
                    onLater()
                } label: {
                    Text("Later")
                        .font(FitUpFont.body(13, weight: .semibold))
                }
                .foregroundStyle(FitUpColors.Text.secondary)
                .disabled(isLoading)
            }

            Button {
                onOpenFriends()
            } label: {
                Text("View in Friends")
                    .font(FitUpFont.body(12, weight: .semibold))
                    .foregroundStyle(FitUpColors.Neon.yellow)
            }
            .disabled(isLoading)
        }
        .padding(16)
        .homeLiquidGlassCard(.pending)
        .overlay {
            RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [FitUpColors.Neon.cyan.opacity(0.55), FitUpColors.Neon.pink.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

private struct NeonCyanOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(FitUpColors.Neon.cyan)
            .background {
                RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                    .fill(FitUpColors.Neon.cyanDim.opacity(configuration.isPressed ? 0.55 : 0.38))
            }
    }
}

// Mirrors ChallengeRivalStripView’s scan lines (that symbol is file-private there).
private struct FriendRequestScanLineStripes: View {
    var body: some View {
        GeometryReader { geo in
            let h = max(1, geo.size.height / 10)
            VStack(spacing: h) {
                ForEach(0..<10, id: \.self) { i in
                    Color.white
                        .opacity(i % 2 == 0 ? 0.04 : 0)
                        .frame(height: h * 0.45)
                }
            }
        }
    }
}
