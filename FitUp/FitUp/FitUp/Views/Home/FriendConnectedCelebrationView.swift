//
//  FriendConnectedCelebrationView.swift
//  FitUp
//
//  Mini celebration after you accept a friend request — entry to challenge the new friend.
//

import SwiftUI

struct FriendConnectedCelebrationView: View {
    let opponent: ChallengePrefillOpponent
    var onCompete: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("You’re in sync")
                    .font(FitUpFont.mono(11, weight: .bold))
                    .foregroundStyle(FitUpColors.Neon.cyan)
                Text("You and \(opponent.displayName) are now friends")
                    .font(FitUpFont.display(18, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(FitUpColors.Text.primary)
            }
            HStack {
                Spacer()
                AvatarView(
                    initials: opponent.initials,
                    color: ProfileAccentColor.swiftUIColor(hex: opponent.colorHex),
                    size: 72,
                    glow: true
                )
                Spacer()
            }
            Button {
                onCompete()
            } label: {
                Text("Compete?")
                    .font(FitUpFont.body(16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .foregroundStyle(FitUpColors.Neon.cyan)
            .background {
                RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                    .fill(FitUpColors.Neon.cyanDim.opacity(0.4))
                    .overlay {
                        RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                            .strokeBorder(FitUpColors.Neon.cyan.opacity(0.5), lineWidth: 1)
                    }
            }
            Button("Not now", action: onDismiss)
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
        }
        .padding(24)
        .background(BackgroundGradientView())
    }
}
