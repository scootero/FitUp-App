//
//  MessagingDiscoBackground.swift
//  FitUp
//
//  Retro neon backgrounds for Messages inbox + 1:1 chat arena.
//

import SwiftUI

// MARK: - Layout tokens

enum MessagingLayout {
    static let horizontalInset: CGFloat = 20
    static let verticalInset: CGFloat = 16
    static let composerBottomPad: CGFloat = 10
    static let bubbleMaxWidth: CGFloat = 260
    static let bubbleSideGutter: CGFloat = 28
}

// MARK: - Inbox background

struct MessagingDiscoBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(rgb: 0x12082A),
                    Color(rgb: 0x0A1538),
                    Color(rgb: 0x061018),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            messagingGridTexture(opacity: 0.04, step: 28)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            FitUpColors.Neon.cyan.opacity(0.34),
                            FitUpColors.Neon.blue.opacity(0.14),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 220
                    )
                )
                .frame(width: 420, height: 420)
                .offset(x: -140, y: -220)
                .blur(radius: 8)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            FitUpColors.Neon.orange.opacity(0.28),
                            FitUpColors.Neon.pink.opacity(0.16),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 260
                    )
                )
                .frame(width: 460, height: 460)
                .offset(x: 160, y: 120)
                .blur(radius: 10)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.05),
                    .clear,
                    Color.black.opacity(0.38),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Chat arena background (split orange / blue + center bolt)

struct MessagingArenaBackground: View {
    var body: some View {
        GeometryReader { geo in
            let centerX = geo.size.width * 0.5
            let boltHalfWidth: CGFloat = 30

            ZStack {
                Color(rgb: 0x060A14)

                HStack(spacing: 0) {
                    opponentSideGradient
                        .frame(width: max(0, centerX - boltHalfWidth))
                    Color.clear.frame(width: boltHalfWidth * 2)
                    userSideGradient
                        .frame(width: max(0, centerX - boltHalfWidth))
                }

                messagingNoiseTexture
                    .blur(radius: 14)
                    .opacity(0.55)

                messagingGridTexture(opacity: 0.03, step: 22)
                    .blur(radius: 1.5)

                LightningBoltDivider()
                    .fill(
                        LinearGradient(
                            colors: [
                                FitUpColors.Neon.yellow.opacity(0.22),
                                FitUpColors.Neon.yellow.opacity(0.08),
                                FitUpColors.Neon.orange.opacity(0.06),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 22, height: geo.size.height * 0.94)
                    .position(x: centerX, y: geo.size.height * 0.5)
                    .shadow(color: FitUpColors.Neon.yellow.opacity(0.18), radius: 18)
                    .blur(radius: 0.6)

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.2),
                        Color.clear,
                        Color.black.opacity(0.42),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }

    private var opponentSideGradient: some View {
        LinearGradient(
            colors: [
                FitUpColors.Neon.orange.opacity(0.38),
                FitUpColors.Neon.orange.opacity(0.16),
                Color(rgb: 0x1A0C06).opacity(0.85),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .overlay(
            RadialGradient(
                colors: [
                    FitUpColors.Neon.yellow.opacity(0.14),
                    .clear,
                ],
                center: UnitPoint(x: 0.12, y: 0.35),
                startRadius: 8,
                endRadius: 280
            )
        )
    }

    private var userSideGradient: some View {
        LinearGradient(
            colors: [
                Color(rgb: 0x061018).opacity(0.85),
                FitUpColors.Neon.blue.opacity(0.18),
                FitUpColors.Neon.cyan.opacity(0.34),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .overlay(
            RadialGradient(
                colors: [
                    FitUpColors.Neon.cyan.opacity(0.16),
                    .clear,
                ],
                center: UnitPoint(x: 0.88, y: 0.4),
                startRadius: 8,
                endRadius: 300
            )
        )
    }
}

// MARK: - Shared texture helpers

private func messagingGridTexture(opacity: Double, step: CGFloat) -> some View {
    GeometryReader { geo in
        Canvas { context, size in
            var path = Path()
            for x in stride(from: 0, through: size.width, by: step) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0, through: size.height, by: step) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(Color.white.opacity(opacity)), lineWidth: 0.5)
        }
        .frame(width: geo.size.width, height: geo.size.height)
    }
}

private var messagingNoiseTexture: some View {
    GeometryReader { geo in
        Canvas { context, size in
            let seed: [CGFloat] = [0.12, 0.31, 0.47, 0.58, 0.71, 0.83, 0.19, 0.64, 0.39, 0.92, 0.26, 0.55]
            for (index, sx) in seed.enumerated() {
                let sy = seed[(index + 3) % seed.count]
                let rect = CGRect(
                    x: sx * size.width,
                    y: sy * size.height,
                    width: 40 + CGFloat(index % 4) * 18,
                    height: 28 + CGFloat(index % 3) * 14
                )
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 6),
                    with: .color(Color.white.opacity(0.035 + Double(index % 3) * 0.012))
                )
            }
        }
        .frame(width: geo.size.width, height: geo.size.height)
    }
}

// MARK: - Lightning bolt divider

private struct LightningBoltDivider: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: w * 0.55, y: 0))
        path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.34))
        path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.34))
        path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.58))
        path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.58))
        path.addLine(to: CGPoint(x: w * 0.12, y: h))
        path.addLine(to: CGPoint(x: w * 0.48, y: h * 0.72))
        path.addLine(to: CGPoint(x: w * 0.38, y: h * 0.48))
        path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.22))
        path.closeSubpath()

        return path
    }
}
