//
//  NeonLeaderboardChrome.swift
//  FitUp
//
//  Retro-neon chrome for Weekly Steps / Ranks (podium tiers + list rows).
//

import SwiftUI

// MARK: - Podium tier

enum LeaderboardPodiumTier: Equatable {
    case gold
    case silver
    case bronze

    var accent: Color {
        switch self {
        case .gold:
            return FitUpColors.Neon.yellow
        case .silver:
            return Color(red: 0.82, green: 0.9, blue: 1.0)
        case .bronze:
            return Color(red: 1.0, green: 0.55, blue: 0.22)
        }
    }

    var secondaryAccent: Color {
        switch self {
        case .gold:
            return FitUpColors.Neon.orange
        case .silver:
            return FitUpColors.Neon.cyan
        case .bronze:
            return FitUpColors.Neon.orange
        }
    }

    var borderOpacity: Double {
        switch self {
        case .gold: return 0.95
        case .silver: return 0.72
        case .bronze: return 0.68
        }
    }

    var outerGlowOpacity: Double {
        switch self {
        case .gold: return 0.72
        case .silver: return 0.42
        case .bronze: return 0.36
        }
    }

    var outerGlowRadius: CGFloat {
        switch self {
        case .gold: return 28
        case .silver: return 16
        case .bronze: return 14
        }
    }

    var innerGlowOpacity: Double {
        switch self {
        case .gold: return 0.55
        case .silver: return 0.32
        case .bronze: return 0.28
        }
    }

    var borderLineWidth: CGFloat {
        switch self {
        case .gold: return 3
        case .silver, .bronze: return 2
        }
    }

    var cardBorderLineWidth: CGFloat {
        switch self {
        case .gold: return 2
        case .silver, .bronze: return 1.5
        }
    }
}

// MARK: - Arcade background

struct LeaderboardArcadeBackground: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    FitUpColors.Neon.purple.opacity(0.22),
                    FitUpColors.Neon.pink.opacity(0.08),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.2, y: 0.0),
                startRadius: 0,
                endRadius: 420
            )

            RadialGradient(
                colors: [
                    FitUpColors.Neon.orange.opacity(0.12),
                    FitUpColors.Neon.pink.opacity(0.06),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.9, y: 0.35),
                startRadius: 0,
                endRadius: 380
            )

            LeaderboardPerspectiveGrid()
                .mask {
                    LinearGradient(
                        colors: [Color.clear, Color.white.opacity(0.85), Color.white],
                        startPoint: UnitPoint(x: 0.5, y: 0.35),
                        endPoint: .bottom
                    )
                }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.42),
                ],
                startPoint: UnitPoint(x: 0.5, y: 0.5),
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
    }
}

private struct LeaderboardPerspectiveGrid: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let horizonY = size.height * 0.42
                let vanishX = size.width * 0.5
                let lineColor = FitUpColors.Neon.purple.opacity(0.38)

                var hPath = Path()
                let horizontalCount = 14
                for i in 0..<horizontalCount {
                    let t = CGFloat(i) / CGFloat(horizontalCount - 1)
                    let y = horizonY + (size.height - horizonY) * pow(t, 1.35)
                    let spread = 0.15 + t * 0.85
                    let leftX = vanishX - size.width * 0.5 * spread
                    let rightX = vanishX + size.width * 0.5 * spread
                    hPath.move(to: CGPoint(x: leftX, y: y))
                    hPath.addLine(to: CGPoint(x: rightX, y: y))
                }
                context.stroke(hPath, with: .color(lineColor), lineWidth: 0.6)

                var vPath = Path()
                let verticalCount = 18
                for i in 0..<verticalCount {
                    let t = CGFloat(i) / CGFloat(verticalCount - 1)
                    let topX = vanishX + (t - 0.5) * size.width * 0.12
                    let bottomX = vanishX + (t - 0.5) * size.width * 1.05
                    vPath.move(to: CGPoint(x: topX, y: horizonY))
                    vPath.addLine(to: CGPoint(x: bottomX, y: size.height + 8))
                }
                context.stroke(vPath, with: .color(FitUpColors.Neon.pink.opacity(0.22)), lineWidth: 0.5)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Podium card shell

private struct NeonPodiumCardModifier: ViewModifier {
    let tier: LeaderboardPodiumTier
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.62))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        tier.accent.opacity(tier.innerGlowOpacity),
                                        tier.secondaryAccent.opacity(tier.innerGlowOpacity * 0.45),
                                        tier.accent.opacity(0.06),
                                        Color.clear,
                                    ],
                                    center: UnitPoint(x: 0.5, y: 0.0),
                                    startRadius: 0,
                                    endRadius: 90
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.14),
                                        Color.clear,
                                        Color.black.opacity(0.42),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        tier.accent.opacity(tier.borderOpacity),
                                        tier.secondaryAccent.opacity(tier.borderOpacity * 0.75),
                                        tier.accent.opacity(tier.borderOpacity * 0.55),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: tier.cardBorderLineWidth
                            )
                    }
                    .shadow(color: tier.accent.opacity(tier.outerGlowOpacity), radius: tier.outerGlowRadius, x: 0, y: 0)
                    .shadow(color: tier.secondaryAccent.opacity(tier.outerGlowOpacity * 0.55), radius: tier.outerGlowRadius * 0.65, x: 0, y: 0)
                    .shadow(color: Color.black.opacity(0.55), radius: 10, x: 0, y: 6)
            }
    }
}

// MARK: - List row shell

private struct NeonLeaderboardRowModifier: ViewModifier {
    let isCurrentUser: Bool
    let isPinned: Bool

    private var accent: Color {
        if isCurrentUser || isPinned {
            return FitUpColors.Neon.cyan
        }
        return FitUpColors.Neon.purple
    }

    private var secondary: Color {
        if isCurrentUser || isPinned {
            return FitUpColors.Neon.pink
        }
        return FitUpColors.Neon.pink.opacity(0.65)
    }

    private var borderOpacity: Double {
        if isCurrentUser || isPinned { return 0.58 }
        return 0.22
    }

    private var glowOpacity: Double {
        if isCurrentUser || isPinned { return 0.38 }
        return 0.14
    }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: NeonArcadeChrome.battleCardCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.54))
                    .overlay {
                        RoundedRectangle(cornerRadius: NeonArcadeChrome.battleCardCornerRadius, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        accent.opacity(isCurrentUser || isPinned ? 0.28 : 0.12),
                                        secondary.opacity(0.06),
                                        Color.clear,
                                    ],
                                    center: UnitPoint(x: 0.0, y: 0.5),
                                    startRadius: 0,
                                    endRadius: 220
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: NeonArcadeChrome.battleCardCornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear,
                                        Color.black.opacity(0.35),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: NeonArcadeChrome.battleCardCornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        accent.opacity(borderOpacity),
                                        secondary.opacity(borderOpacity * 0.7),
                                        accent.opacity(borderOpacity * 0.45),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isCurrentUser || isPinned ? 1.5 : 1
                            )
                    }
                    .shadow(color: accent.opacity(glowOpacity), radius: isCurrentUser || isPinned ? 14 : 8, x: 0, y: 0)
                    .shadow(color: secondary.opacity(glowOpacity * 0.6), radius: isCurrentUser || isPinned ? 10 : 5, x: 0, y: 0)
                    .shadow(color: Color.black.opacity(0.45), radius: 8, x: 0, y: 5)
            }
    }
}

// MARK: - Tab segment

struct NeonLeaderboardTabSegment: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(FitUpFont.mono(11, weight: .bold))
                .tracking(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .foregroundStyle(
                    isSelected
                        ? FitUpColors.Neon.cyan
                        : FitUpColors.Text.secondary
                )
                .shadow(
                    color: isSelected ? FitUpColors.Neon.cyan.opacity(0.55) : .clear,
                    radius: 8,
                    x: 0,
                    y: 0
                )
                .background {
                    Capsule()
                        .fill(Color.black.opacity(isSelected ? 0.55 : 0.38))
                        .overlay {
                            if isSelected {
                                Capsule()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                FitUpColors.Neon.cyan.opacity(0.22),
                                                FitUpColors.Neon.pink.opacity(0.08),
                                                Color.clear,
                                            ],
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 120
                                        )
                                    )
                            }
                        }
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    isSelected
                                        ? LinearGradient(
                                            colors: [
                                                FitUpColors.Neon.cyan.opacity(0.9),
                                                FitUpColors.Neon.pink.opacity(0.55),
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        : LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.1),
                                                Color.white.opacity(0.06),
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                    lineWidth: isSelected ? 1.5 : 1
                                )
                        }
                        .shadow(
                            color: isSelected ? FitUpColors.Neon.cyan.opacity(0.35) : .clear,
                            radius: 12,
                            x: 0,
                            y: 0
                        )
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View extensions

extension View {
    func neonLeaderboardPodiumCard(tier: LeaderboardPodiumTier, cornerRadius: CGFloat = 16) -> some View {
        modifier(NeonPodiumCardModifier(tier: tier, cornerRadius: cornerRadius))
    }

    func neonLeaderboardRow(isCurrentUser: Bool = false, isPinned: Bool = false) -> some View {
        modifier(NeonLeaderboardRowModifier(isCurrentUser: isCurrentUser, isPinned: isPinned))
    }
}
