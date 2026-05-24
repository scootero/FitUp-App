//
//  NeonStatCard.swift
//  FitUp
//
//  Reusable glowing oval stat tile for neon/arcade Home sections.
//

import SwiftUI

struct NeonStatCard: View {
    let systemImage: String
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.75), radius: 8, x: 0, y: 0)
                .padding(.top, 4)

            Text(label.uppercased())
                .font(FitUpFont.mono(9, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(HomePageStyle.offWhite.opacity(0.94))
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .multilineTextAlignment(.center)

            Text(value)
                .font(FitUpFont.display(30, weight: .black))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .shadow(color: accent.opacity(0.62), radius: 10, x: 0, y: 0)
                .padding(.bottom, 2)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .neonOvalStatCard(accent: accent)
    }
}

#Preview {
    HStack(spacing: 5) {
        NeonStatCard(
            systemImage: "trophy.fill",
            label: "Winning",
            value: "2",
            accent: FitUpColors.Neon.green
        )
        NeonStatCard(
            systemImage: "arrow.down.right.circle.fill",
            label: "Losing",
            value: "1",
            accent: FitUpColors.Neon.orange
        )
    }
    .padding()
    .background { BackgroundGradientView() }
}
