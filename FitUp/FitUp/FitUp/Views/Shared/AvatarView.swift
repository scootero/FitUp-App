//
//  AvatarView.swift
//  FitUp
//
//  Maps JSX `Av` — initials, accent gradient fill, border, optional glow.
//

import SwiftUI

struct AvatarView: View {
    let initials: String
    let color: Color
    var size: CGFloat = 36
    var glow: Bool = false
    var rank: Int?

    private var fontSize: CGFloat { size * 0.33 }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(initials)
                .font(FitUpFont.display(fontSize, weight: .bold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.18), color.opacity(0.09)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Circle()
                                .strokeBorder(color.opacity(0.35), lineWidth: 2)
                        }
                        .shadow(color: glow ? color.opacity(0.33) : .clear, radius: 9, x: 0, y: 0)
                }

            if let rank {
                Text("\(rank)")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(width: 18, height: 18)
                    .background {
                        Circle()
                            .fill(rankBadgeColor(rank))
                    }
                    .offset(x: 4, y: 4)
            }
        }
    }

    private func rankBadgeColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return FitUpColors.Neon.yellow
        case 2: return Color(red: 0.75, green: 0.82, blue: 1, opacity: 0.9)
        default: return FitUpColors.Neon.orange
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        AvatarView(initials: "MR", color: FitUpColors.Neon.cyan, size: 38, glow: true)
        AvatarView(initials: "JT", color: FitUpColors.Neon.orange, size: 38)
        AvatarView(initials: "TH", color: FitUpColors.Neon.yellow, size: 44, rank: 1)
    }
    .padding()
    .background { BackgroundGradientView() }
}
