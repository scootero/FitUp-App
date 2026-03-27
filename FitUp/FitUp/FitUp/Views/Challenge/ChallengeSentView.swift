//
//  ChallengeSentView.swift
//  FitUp
//
//  Slice 4 sent confirmation state.
//

import SwiftUI

struct ChallengeSentView: View {
    let opponentName: String
    let metricLabel: String
    let formatLabel: String
    var onBackHome: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 10)

            Text("⚡")
                .font(.system(size: 58))

            Text("Challenge Sent!")
                .font(FitUpFont.display(22, weight: .black))
                .foregroundStyle(FitUpColors.Neon.cyan)

            Text("Waiting for \(opponentName) to accept...")
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
                .multilineTextAlignment(.center)

            NeonBadge(label: "\(metricLabel) · \(formatLabel)", color: FitUpColors.Neon.cyan)

            Button("Back to Home") {
                onBackHome()
            }
            .buttonStyle(.plain)
            .ghostButton(color: FitUpColors.Neon.cyan)
            .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

