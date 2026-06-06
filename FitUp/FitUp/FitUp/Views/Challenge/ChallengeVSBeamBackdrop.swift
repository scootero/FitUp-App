//
//  ChallengeVSBeamBackdrop.swift
//  FitUp
//
//  Static cyan/orange beam wash behind the challenge VS card (no TimelineView).
//

import SwiftUI

struct ChallengeVSBeamBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let centerX = w * 0.5

            ZStack {
                RadialGradient(
                    colors: [
                        FitUpColors.Neon.cyan.opacity(0.42),
                        FitUpColors.Neon.cyan.opacity(0.12),
                        Color.clear,
                    ],
                    center: UnitPoint(x: 0.22, y: 0.5),
                    startRadius: 0,
                    endRadius: w * 0.42
                )

                RadialGradient(
                    colors: [
                        FitUpColors.Neon.orange.opacity(0.40),
                        FitUpColors.Neon.orange.opacity(0.10),
                        Color.clear,
                    ],
                    center: UnitPoint(x: 0.78, y: 0.5),
                    startRadius: 0,
                    endRadius: w * 0.42
                )

                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [
                                FitUpColors.Neon.cyan.opacity(0.35),
                                FitUpColors.Neon.purple.opacity(0.18),
                                FitUpColors.Neon.orange.opacity(0.32),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: w * 0.28, height: h * 0.55)
                    .position(x: centerX, y: h * 0.46)
                    .blur(radius: 18)
            }
            .opacity(0.72)
        }
        .allowsHitTesting(false)
    }
}
