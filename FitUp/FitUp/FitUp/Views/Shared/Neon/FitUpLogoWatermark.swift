//
//  FitUpLogoWatermark.swift
//  FitUp
//
//  Decorative FitUp wordmark for neon card backgrounds.
//

import SwiftUI

struct FitUpLogoWatermark: View {
    var opacity: Double = 0.10
    var scale: CGFloat = 1.35

    var body: some View {
        HStack(spacing: 8 * scale) {
            HStack(spacing: 5 * scale) {
                Circle().fill(FitUpColors.Neon.cyan.opacity(0.95)).frame(width: 9 * scale, height: 9 * scale)
                Circle().fill(FitUpColors.Neon.blue.opacity(0.95)).frame(width: 7 * scale, height: 7 * scale)
                    .offset(y: -1)
                Circle().fill(FitUpColors.Neon.orange.opacity(0.95)).frame(width: 10 * scale, height: 10 * scale)
                    .offset(x: -2)
            }
            Text("FitUp")
                .font(.system(size: 22 * scale, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))
                .tracking(0.35)
        }
        .opacity(opacity)
        .allowsHitTesting(false)
    }
}
