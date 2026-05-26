//
//  NeonArcadeChrome.swift
//  FitUp
//
//  Shared neon/arcade panel chrome for Home Active Battles (not global glass cards).
//

import SwiftUI

enum NeonArcadeChrome {
    static let statCardCornerRadius: CGFloat = 20
    static let statCardMinHeight: CGFloat = 92
    static let battleCardCornerRadius: CGFloat = 17
    static let battleCardMinHeight: CGFloat = 70
    static let rivalryPanelCornerRadius: CGFloat = 30
    static let rowPlateCornerRadius: CGFloat = 14
}

// MARK: - Oval stat card shell

private struct NeonOvalStatCardModifier: ViewModifier {
    let accent: Color

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .frame(minHeight: NeonArcadeChrome.statCardMinHeight)
            .background {
                RoundedRectangle(cornerRadius: NeonArcadeChrome.statCardCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.58))
                    .overlay {
                        RoundedRectangle(cornerRadius: NeonArcadeChrome.statCardCornerRadius, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        accent.opacity(0.38),
                                        accent.opacity(0.14),
                                        accent.opacity(0.04),
                                        Color.clear,
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 72
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: NeonArcadeChrome.statCardCornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accent.opacity(0.12),
                                        Color.clear,
                                        Color.black.opacity(0.35),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: NeonArcadeChrome.statCardCornerRadius, style: .continuous)
                            .strokeBorder(accent.opacity(0.82), lineWidth: 2)
                    }
                    .shadow(color: accent.opacity(0.55), radius: 12, x: 0, y: 0)
                    .shadow(color: accent.opacity(0.28), radius: 26, x: 0, y: 0)
                    .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 5)
            }
    }
}

// MARK: - Rivalry list panel shell

private struct NeonRivalryPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: NeonArcadeChrome.rivalryPanelCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.72))
                    .overlay {
                        RoundedRectangle(cornerRadius: NeonArcadeChrome.rivalryPanelCornerRadius, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        FitUpColors.Neon.purple.opacity(0.16),
                                        FitUpColors.Neon.pink.opacity(0.06),
                                        Color.clear,
                                    ],
                                    center: UnitPoint(x: 0.12, y: 0.0),
                                    startRadius: 0,
                                    endRadius: 280
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: NeonArcadeChrome.rivalryPanelCornerRadius, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        FitUpColors.Neon.pink.opacity(0.1),
                                        Color.clear,
                                    ],
                                    center: UnitPoint(x: 0.88, y: 1.0),
                                    startRadius: 0,
                                    endRadius: 200
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: NeonArcadeChrome.rivalryPanelCornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        FitUpColors.Neon.purple.opacity(0.45),
                                        Color.white.opacity(0.06),
                                        FitUpColors.Neon.pink.opacity(0.32),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.4
                            )
                    }
                    .shadow(color: FitUpColors.Neon.purple.opacity(0.2), radius: 28, x: 0, y: 10)
                    .shadow(color: Color.black.opacity(0.55), radius: 18, x: 0, y: 12)
            }
    }
}

// MARK: - Compact battle card shell (stat-card language, thinner border, ~25% glow)

private struct NeonCompactBattleCardModifier: ViewModifier {
    let accent: Color
    var minHeight: CGFloat?

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .frame(minHeight: minHeight ?? NeonArcadeChrome.battleCardMinHeight)
            .background {
                RoundedRectangle(cornerRadius: NeonArcadeChrome.battleCardCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.58))
                    .overlay {
                        RoundedRectangle(cornerRadius: NeonArcadeChrome.battleCardCornerRadius, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        accent.opacity(0.38),
                                        accent.opacity(0.14),
                                        accent.opacity(0.04),
                                        Color.clear,
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 60
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: NeonArcadeChrome.battleCardCornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accent.opacity(0.12),
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
                            .strokeBorder(accent.opacity(0.82), lineWidth: 1)
                    }
                    .shadow(color: accent.opacity(0.14), radius: 3, x: 0, y: 0)
                    .shadow(color: accent.opacity(0.07), radius: 7, x: 0, y: 0)
                    .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 5)
            }
    }
}

// MARK: - Row inset plate

private struct NeonRowInsetPlateModifier: ViewModifier {
    var accent: Color

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: NeonArcadeChrome.rowPlateCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.42))
                    .overlay {
                        RoundedRectangle(cornerRadius: NeonArcadeChrome.rowPlateCornerRadius, style: .continuous)
                            .strokeBorder(accent.opacity(0.14), lineWidth: 1)
                    }
            }
    }
}

// MARK: - Row separator

struct NeonRowSeparator: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        FitUpColors.Neon.purple.opacity(0.22),
                        Color.clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.vertical, 3)
    }
}

// MARK: - View extensions

extension View {
    func neonOvalStatCard(accent: Color) -> some View {
        modifier(NeonOvalStatCardModifier(accent: accent))
    }

    func neonRivalryPanel() -> some View {
        modifier(NeonRivalryPanelModifier())
    }

    func neonRowInsetPlate(accent: Color) -> some View {
        modifier(NeonRowInsetPlateModifier(accent: accent))
    }

    func neonCompactBattleCard(accent: Color, minHeight: CGFloat? = nil) -> some View {
        modifier(NeonCompactBattleCardModifier(accent: accent, minHeight: minHeight))
    }
}
