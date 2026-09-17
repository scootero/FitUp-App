//
//  MatchDetailsHeroCardChrome.swift
//  FitUp
//
//  Themed hero card chrome for Match Details (dark homepage plate + neon).
//

import SwiftUI

/// Brighter body copy on Match Details secondary cards (vs global `Text.secondary`).
enum MatchDetailsContentColors {
    static let sectionTitle = Color.white.opacity(0.96)
    static let label = Color.white.opacity(0.9)
    static let muted = Color.white.opacity(0.72)
}

struct MatchHeroPlayerTheme: Equatable {
    let primary: Color
    let secondary: Color

    /// FitOff wordmark blue: cyan → blue, same family as the FIT header.
    static let user = MatchHeroPlayerTheme(
        primary: FitUpColors.Neon.cyan,
        secondary: FitUpColors.Neon.blue
    )

    static let opponent = MatchHeroPlayerTheme(
        primary: FitUpColors.Neon.orange,
        secondary: FitUpColors.Neon.yellow
    )
}

struct MatchDetailsHeroCardChrome: ViewModifier {
    let accent: Color
    let variant: GlassCardVariant

    func body(content: Content) -> some View {
        content
            .background {
                MatchDetailsHeroPlate(accent: accent, variant: variant)
            }
            .clipShape(RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous))
            .shadow(color: FitUpColors.Neon.blue.opacity(0.10), radius: 18, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.45), radius: 14, x: 0, y: 8)
    }
}

/// Dark plate matching the homepage atmosphere, sitting behind the match content.
private struct MatchDetailsHeroPlate: View {
    let accent: Color
    let variant: GlassCardVariant

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
        ZStack {
            shape.fill(FitUpColors.Bg.base)

            shape.fill(
                RadialGradient(
                    colors: [
                        Color(red: 0, green: 1, blue: 0.878, opacity: 0.10),
                        .clear,
                    ],
                    center: UnitPoint(x: 0.12, y: 0.08),
                    startRadius: 0,
                    endRadius: 280
                )
            )

            shape.fill(
                RadialGradient(
                    colors: [
                        Color(red: 0, green: 0.667, blue: 1, opacity: 0.09),
                        .clear,
                    ],
                    center: UnitPoint(x: 0.88, y: 0.92),
                    startRadius: 0,
                    endRadius: 260
                )
            )

            shape.fill(
                RadialGradient(
                    colors: [
                        FitUpColors.Neon.orange.opacity(0.07),
                        .clear,
                    ],
                    center: UnitPoint(x: 0.82, y: 0.18),
                    startRadius: 0,
                    endRadius: 220
                )
            )

            shape.fill(variant.fillGradient)
            shape.fill(accent.opacity(0.04))

            MatchDetailsHeroTextureOverlay()
                .clipShape(shape)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        FitUpColors.Neon.cyan.opacity(0.38),
                        Color.white.opacity(0.10),
                        FitUpColors.Neon.orange.opacity(0.34),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        }
        .allowsHitTesting(false)
    }
}

/// Bigger neon profile orb: team gradient ring, inner texture, no square frame.
struct MatchHeroNeonAvatar: View {
    let initials: String
    let theme: MatchHeroPlayerTheme
    var size: CGFloat = 78
    var livePulse: Bool = false

    var body: some View {
        let ring = max(2.5, size * 0.045)
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            theme.primary.opacity(0.42),
                            theme.secondary.opacity(0.16),
                            Color.black.opacity(0.72),
                        ],
                        center: UnitPoint(x: 0.38, y: 0.32),
                        startRadius: 2,
                        endRadius: size * 0.62
                    )
                )

            MatchHeroAvatarTexture(primary: theme.primary, secondary: theme.secondary)
                .clipShape(Circle())
                .opacity(0.85)

            Circle()
                .strokeBorder(Color.black.opacity(0.45), lineWidth: ring + 1.5)

            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            theme.primary,
                            theme.secondary,
                            Color.white.opacity(0.92),
                            theme.primary.opacity(0.75),
                            theme.secondary,
                            theme.primary,
                        ],
                        center: .center
                    ),
                    lineWidth: ring
                )

            Circle()
                .strokeBorder(theme.primary.opacity(0.55), lineWidth: 1)
                .padding(ring + 2)
                .blur(radius: 0.4)

            Text(initials)
                .font(FitUpFont.display(size * 0.34, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white, theme.primary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: theme.primary.opacity(0.85), radius: 6, x: 0, y: 0)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(width: size, height: size)
        .shadow(color: theme.primary.opacity(livePulse ? 0.72 : 0.48), radius: livePulse ? 16 : 12, x: 0, y: 0)
        .shadow(color: theme.secondary.opacity(0.35), radius: 18, x: 0, y: 4)
        .accessibilityHidden(true)
    }
}

private struct MatchHeroAvatarTexture: View {
    let primary: Color
    let secondary: Color

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            var hatch = Path()
            let step: CGFloat = 5
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                hatch.move(to: CGPoint(x: x, y: size.height))
                hatch.addLine(to: CGPoint(x: x + size.height * 0.72, y: 0))
                x += step
            }
            context.stroke(hatch, with: .color(primary.opacity(0.28)), lineWidth: 0.7)

            var sweep = Path()
            sweep.addArc(
                center: center,
                radius: size.width * 0.34,
                startAngle: .degrees(-40),
                endAngle: .degrees(210),
                clockwise: false
            )
            context.stroke(
                sweep,
                with: .color(secondary.opacity(0.55)),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
            )

            let hotspot = CGRect(
                x: size.width * 0.18,
                y: size.height * 0.12,
                width: size.width * 0.38,
                height: size.height * 0.28
            )
            context.fill(
                Path(ellipseIn: hotspot),
                with: .color(Color.white.opacity(0.16))
            )
        }
        .allowsHitTesting(false)
    }
}

private struct MatchDetailsHeroTextureOverlay: View {
    var body: some View {
        Canvas { context, size in
            var mesh = Path()
            let step: CGFloat = 18
            var x = -size.height
            while x < size.width + size.height {
                mesh.move(to: CGPoint(x: x, y: size.height))
                mesh.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += step
            }
            context.stroke(mesh, with: .color(Color.white.opacity(0.03)), lineWidth: 1)

            let wash = CGRect(origin: .zero, size: size)
            context.fill(
                Path(ellipseIn: wash),
                with: .linearGradient(
                    Gradient(colors: [
                        FitUpColors.Neon.cyan.opacity(0.06),
                        Color.clear,
                        FitUpColors.Neon.orange.opacity(0.05),
                    ]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )
        }
        .blur(radius: 0.5)
        .opacity(0.9)
    }
}

extension View {
    func matchDetailsHeroCardChrome(accent: Color, variant: GlassCardVariant) -> some View {
        modifier(MatchDetailsHeroCardChrome(accent: accent, variant: variant))
    }

    func matchDetailsSecondaryCard(leadingAccent: Color, trailingAccent: Color? = nil) -> some View {
        modifier(MatchDetailsSecondaryCardChrome(leadingAccent: leadingAccent, trailingAccent: trailingAccent))
    }
}

struct MatchDetailsSecondaryCardChrome: ViewModifier {
    let leadingAccent: Color
    let trailingAccent: Color?

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.03),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RadialGradient(
                        colors: [
                            leadingAccent.opacity(0.14),
                            trailingAccent?.opacity(0.1) ?? leadingAccent.opacity(0.05),
                            Color.clear,
                        ],
                        center: .topLeading,
                        startRadius: 6,
                        endRadius: 200
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous))

                    RadialGradient(
                        colors: [
                            FitUpColors.Neon.purple.opacity(0.16),
                            FitUpColors.Neon.pink.opacity(0.06),
                            Color.clear,
                        ],
                        center: .bottomTrailing,
                        startRadius: 4,
                        endRadius: 220
                    )
                    .blur(radius: 10)
                    .clipShape(RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous))

                    MatchDetailsHeroTextureOverlay()
                        .opacity(0.45)
                        .clipShape(RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous))
                        .blendMode(.plusLighter)
                        .blur(radius: 0.6)

                    RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    leadingAccent.opacity(0.32),
                                    Color.white.opacity(0.14),
                                    (trailingAccent ?? leadingAccent).opacity(0.24),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: leadingAccent.opacity(0.08), radius: 14, x: 0, y: 8)
                .shadow(color: Color.black.opacity(0.28), radius: 10, x: 0, y: 5)
            }
    }
}
