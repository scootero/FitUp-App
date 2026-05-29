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
    var compact: Bool = false
    /// When set, overrides `HomeHeroCompactLayout.battlesScale` for tighter stat tiles.
    var compactScale: CGFloat? = nil

    private var scale: CGFloat {
        if let compactScale { return compactScale }
        return compact ? HomeHeroCompactLayout.battlesScale : 1
    }

    var body: some View {
        VStack(spacing: HomeHeroCompactLayout.scaled(5, by: scale)) {
            Image(systemName: systemImage)
                .font(.system(size: HomeHeroCompactLayout.scaled(compact ? 15 : 18, by: scale), weight: .bold))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.75), radius: HomeHeroCompactLayout.scaled(8, by: scale), x: 0, y: 0)
                .padding(.top, HomeHeroCompactLayout.scaled(4, by: scale))

            Text(label.uppercased())
                .font(FitUpFont.mono(HomeHeroCompactLayout.scaled(compact ? 8 : 9, by: scale), weight: .bold))
                .tracking(1.0 * scale)
                .foregroundStyle(HomePageStyle.offWhite.opacity(0.94))
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .multilineTextAlignment(.center)

            Text(value)
                .font(FitUpFont.display(HomeHeroCompactLayout.scaled(compact ? 24 : 30, by: scale), weight: .black))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .shadow(color: accent.opacity(0.62), radius: HomeHeroCompactLayout.scaled(10, by: scale), x: 0, y: 0)
                .padding(.bottom, HomeHeroCompactLayout.scaled(2, by: scale))
        }
        .padding(.horizontal, HomeHeroCompactLayout.scaled(4, by: scale))
        .padding(.vertical, HomeHeroCompactLayout.scaled(compact ? 4 : 6, by: scale))
        .neonOvalStatCard(
            accent: accent,
            minHeight: HomeHeroCompactLayout.scaled(NeonArcadeChrome.statCardMinHeight, by: scale)
        )
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
