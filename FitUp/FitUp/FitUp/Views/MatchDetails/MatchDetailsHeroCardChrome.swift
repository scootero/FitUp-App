//
//  MatchDetailsHeroCardChrome.swift
//  FitUp
//
//  Themed hero card chrome for Match Details (neon wash + glass).
//

import SwiftUI

struct MatchDetailsHeroCardChrome: ViewModifier {
    let accent: Color
    let variant: GlassCardVariant

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                        .fill(variant.fillGradient)

                    RadialGradient(
                        colors: [
                            accent.opacity(0.14),
                            accent.opacity(0.04),
                            Color.clear,
                        ],
                        center: .topLeading,
                        startRadius: 8,
                        endRadius: 220
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous))

                    MatchDetailsHeroTextureOverlay()
                        .clipShape(RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous))
                        .blendMode(.plusLighter)

                    RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    accent.opacity(0.45),
                                    Color.white.opacity(0.12),
                                    accent.opacity(0.22),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: accent.opacity(0.12), radius: 20, x: 0, y: 10)
                .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
            }
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
                            leadingAccent.opacity(0.12),
                            trailingAccent?.opacity(0.08) ?? leadingAccent.opacity(0.04),
                            Color.clear,
                        ],
                        center: .topLeading,
                        startRadius: 6,
                        endRadius: 180
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous))

                    MatchDetailsHeroTextureOverlay()
                        .opacity(0.45)
                        .clipShape(RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous))
                        .blendMode(.plusLighter)

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
