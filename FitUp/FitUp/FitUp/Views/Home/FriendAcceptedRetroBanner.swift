//
//  FriendAcceptedRetroBanner.swift
//  FitUp
//
//  Shown to the original requester when the other person accepts.
//

import SwiftUI

struct FriendAcceptedRetroBanner: View {
    let accepterName: String
    var onCompete: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FRIEND UNLOCKED")
                .font(FitUpFont.mono(10, weight: .black))
                .foregroundStyle(FitUpColors.Neon.yellow)
                .tracking(1.2)
            Text("\(accepterName) accepted your invite")
                .font(FitUpFont.body(15, weight: .bold))
                .foregroundStyle(FitUpColors.Text.primary)
            HStack(spacing: 10) {
                Button(action: onCompete) {
                    Text("Compete?")
                        .font(FitUpFont.body(14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .foregroundStyle(FitUpColors.Neon.cyan)
                .background {
                    RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                        .fill(FitUpColors.Neon.cyanDim.opacity(0.35))
                }
                Button("OK", action: onDismiss)
                    .font(FitUpFont.body(13, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                .fill(GlassCardVariant.win.fillGradient)
                .overlay {
                    RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                        .strokeBorder(FitUpColors.Neon.yellow.opacity(0.45), lineWidth: 1)
                }
        )
    }
}
