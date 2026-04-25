//
//  NeonBadge.swift
//  FitUp
//
//  Maps JSX `Badge` / `neonPill` — pill tint + border.
//

import SwiftUI

struct NeonBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(FitUpFont.mono(11, weight: .bold))
            .foregroundStyle(color)
            .tracking(0.05 * 11)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(color.opacity(0.094))
                    .overlay {
                        Capsule()
                            .strokeBorder(color.opacity(0.25), lineWidth: 1)
                    }
            }
    }
}

#Preview {
    VStack(spacing: 12) {
        NeonBadge(label: "LIVE", color: FitUpColors.Neon.green)
        NeonBadge(label: "PRO", color: FitUpColors.Neon.yellow)
        NeonBadge(label: "7-day match", color: FitUpColors.Neon.cyan)
    }
    .padding()
    .background { BackgroundGradientView() }
}
