//
//  DesignTokens.swift
//  FitUp
//
//  Visual tokens mapped from docs/mockups/FitUp_Final_Mockup.jsx (T, BG_STYLE, glassCard, etc.)
//

import SwiftUI

// MARK: - Color helpers

extension Color {
    /// sRGB hex, e.g. 0x00FFE0
    init(rgb: UInt32, alpha: Double = 1) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Tokens (T)

enum FitUpColors {
    enum Bg {
        static let base = Color(rgb: 0x04040A)
    }

    enum Neon {
        static let cyan = Color(rgb: 0x00FFE0)
        static let cyanDim = Color(red: 0, green: 1, blue: 0.878, opacity: 0.14)
        static let blue = Color(rgb: 0x00AAFF)
        static let blueDim = Color(red: 0, green: 0.667, blue: 1, opacity: 0.14)
        static let orange = Color(rgb: 0xFF6200)
        static let orangeDim = Color(red: 1, green: 0.384, blue: 0, opacity: 0.14)
        static let yellow = Color(rgb: 0xFFE000)
        static let pink = Color(rgb: 0xFF2D9B)
        static let purple = Color(rgb: 0xBF5FFF)
        static let green = Color(rgb: 0x39FF14)
        static let greenDim = Color(red: 0.224, green: 1, blue: 0.078, opacity: 0.12)
        static let red = Color(rgb: 0xFF3B3B)
    }

    enum Text {
        static let primary = Color.white
        static let secondary = Color.white.opacity(0.52)
        static let tertiary = Color.white.opacity(0.27)
        static let title = Color(red: 0.70, green: 0.95, blue: 1.0)
    }

    /// Body copy on light “gamified” health cards (dark ink for contrast).
    enum HealthOnLight {
        static let primary = Color(rgb: 0x1B2430)
        static let secondary = Color(rgb: 0x4B5569)
        static let tertiary = Color(rgb: 0x7A8499)
    }

    /// Single accent for uppercase section titles inside light health cards.
    enum HealthSection {
        static let title = Color(rgb: 0x0C6B7A)
    }

    /// Sleep stage segment colors — `HealthScreen` / `HEALTH_MOCK` in FitUp_Final_Mockup.jsx
    enum HealthSleepStage {
        static let deep = Color(rgb: 0x1E90FF)
        static let core = Color(rgb: 0x00A8FF)
        static let rem = Neon.cyan
        static let awake = Color.white.opacity(0.27)
    }
}

// MARK: - Radii (T.radius)

enum FitUpRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 22
    static let xl: CGFloat = 28
    static let pill: CGFloat = 999
}

// MARK: - Fonts (T.font → SF)

enum FitUpFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Glass card (glassCard())

enum GlassCardVariant: CaseIterable {
    case base, win, lose, pending, gold

    var cornerRadius: CGFloat { FitUpRadius.lg }

    /// Linear gradient matching JSX `T.glass.*.background` (135deg)
    var fillGradient: LinearGradient {
        switch self {
        case .win:
            return LinearGradient(
                colors: [
                    Color(red: 0, green: 1, blue: 0.878, opacity: 0.07),
                    Color(red: 0, green: 1, blue: 0.878, opacity: 0.02),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .lose:
            return LinearGradient(
                colors: [
                    Color(red: 1, green: 0.384, blue: 0, opacity: 0.07),
                    Color(red: 1, green: 0.384, blue: 0, opacity: 0.02),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .base:
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.055),
                    Color.white.opacity(0.018),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .pending:
            return LinearGradient(
                colors: [
                    Color(red: 0, green: 0.667, blue: 1, opacity: 0.07),
                    Color(red: 0, green: 0.667, blue: 1, opacity: 0.02),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .gold:
            return LinearGradient(
                colors: [
                    Color(red: 1, green: 0.878, blue: 0, opacity: 0.10),
                    Color(red: 1, green: 0.878, blue: 0, opacity: 0.03),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var borderColor: Color {
        switch self {
        case .win: return Color(red: 0, green: 1, blue: 0.878, opacity: 0.22)
        case .lose: return Color(red: 1, green: 0.384, blue: 0, opacity: 0.22)
        case .base: return Color.white.opacity(0.09)
        case .pending: return Color(red: 0, green: 0.667, blue: 1, opacity: 0.22)
        case .gold: return Color(red: 1, green: 0.878, blue: 0, opacity: 0.28)
        }
    }

    var shadowColor: Color {
        switch self {
        case .win: return FitUpColors.Neon.cyan.opacity(0.07)
        case .lose: return FitUpColors.Neon.orange.opacity(0.07)
        case .base: return Color.black.opacity(0.45)
        case .pending: return FitUpColors.Neon.blue.opacity(0.07)
        case .gold: return FitUpColors.Neon.yellow.opacity(0.10)
        }
    }
}

struct GlassCardModifier: ViewModifier {
    let variant: GlassCardVariant

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: variant.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: variant.cornerRadius, style: .continuous)
                            .fill(variant.fillGradient)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: variant.cornerRadius, style: .continuous)
                            .strokeBorder(variant.borderColor, lineWidth: 1)
                    }
                    .shadow(color: variant.shadowColor, radius: 16, x: 0, y: 8)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
    }
}

struct HomeLiquidGlassCardModifier: ViewModifier {
    let variant: GlassCardVariant

    private var darkFrostTint: LinearGradient {
        LinearGradient(
            colors: [
                Color.black.opacity(0.36),
                Color.black.opacity(0.24),
                Color.black.opacity(0.14),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var baseTintGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.06),
                Color.white.opacity(0.028),
                Color.clear,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var liquidSheen: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.18),
                Color.white.opacity(0.07),
                Color.clear,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var crystalHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.30),
                Color.white.opacity(0.08),
                Color.clear,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: variant.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: variant.cornerRadius, style: .continuous)
                            .fill(darkFrostTint)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: variant.cornerRadius, style: .continuous)
                            .fill(baseTintGradient)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: variant.cornerRadius, style: .continuous)
                            .fill(variant.fillGradient)
                            .opacity(0.22)
                    }
                    .overlay(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: variant.cornerRadius, style: .continuous)
                            .fill(liquidSheen)
                            .opacity(0.75)
                            .blur(radius: 0.2)
                            .mask(
                                RoundedRectangle(cornerRadius: variant.cornerRadius, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white, Color.white.opacity(0.2), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: variant.cornerRadius, style: .continuous)
                            .fill(crystalHighlight)
                    }
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: variant.cornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.55)
                            .blur(radius: 0.3)
                            .mask(
                                LinearGradient(
                                    colors: [Color.white, Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .overlay(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: variant.cornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.42), lineWidth: 0.65)
                            .blur(radius: 0.28)
                            .mask(
                                RoundedRectangle(cornerRadius: variant.cornerRadius, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white, Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: variant.cornerRadius, style: .continuous)
                            .strokeBorder(variant.borderColor.opacity(0.68), lineWidth: 0.9)
                    }
                    .shadow(color: variant.shadowColor.opacity(0.6), radius: 18, x: 0, y: 10)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
            }
    }
}

// MARK: - Health gamified cards (light surfaces, retro-neon wash)

enum HealthGamifiedCardVariant {
    case battleReadiness
    case componentBreakdown
    case weekChart
    case weekComparison
    case consistency
    case battleStats
    case pastMatchesPanel
    case sleepLastNight
    case sleepRatio
    case sleepSevenNight
    case competitionEdge
    case accessBanner
    case miniChip
    case miniAccent(Int)
    case matchRowWin
    case matchRowLose

    var cornerRadius: CGFloat {
        switch self {
        case .miniChip, .miniAccent:
            return FitUpRadius.md
        default:
            return FitUpRadius.lg
        }
    }

    var fillGradient: LinearGradient {
        switch self {
        case .battleReadiness:
            return LinearGradient(
                colors: [
                    Color(rgb: 0xF5FFFD),
                    Color(rgb: 0xDCF8F0),
                    Color(rgb: 0xC8EFE8),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .componentBreakdown:
            return LinearGradient(
                colors: [
                    Color(rgb: 0xF7F5FF),
                    Color(rgb: 0xEAE6FF),
                    Color(rgb: 0xDDD6FA),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .weekChart:
            return LinearGradient(
                colors: [
                    Color(rgb: 0xF2FBFF),
                    Color(rgb: 0xD9F0FF),
                    Color(rgb: 0xC4E5FA),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .weekComparison:
            return LinearGradient(
                colors: [
                    Color(rgb: 0xF4F7FF),
                    Color(rgb: 0xE3EBFF),
                    Color(rgb: 0xD2DBF5),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .consistency:
            return LinearGradient(
                colors: [
                    Color(rgb: 0xFAFFF6),
                    Color(rgb: 0xEAFBE4),
                    Color(rgb: 0xDCF5D3),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .battleStats:
            return LinearGradient(
                colors: [
                    Color(rgb: 0xFFFBF7),
                    Color(rgb: 0xFFEEDE),
                    Color(rgb: 0xFFDCC8),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .pastMatchesPanel:
            return LinearGradient(
                colors: [
                    Color(rgb: 0xFFF8FB),
                    Color(rgb: 0xFFE8F2),
                    Color(rgb: 0xF5D9EA),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sleepLastNight:
            return LinearGradient(
                colors: [
                    Color(rgb: 0xF3F5FF),
                    Color(rgb: 0xE2E8FF),
                    Color(rgb: 0xCFD8FA),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sleepRatio:
            return LinearGradient(
                colors: [
                    Color(rgb: 0xFAF7FF),
                    Color(rgb: 0xEEE5FF),
                    Color(rgb: 0xE0D4F7),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sleepSevenNight:
            return LinearGradient(
                colors: [
                    Color(rgb: 0xF3FAFF),
                    Color(rgb: 0xDCEEFF),
                    Color(rgb: 0xC5E2FB),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .competitionEdge:
            return LinearGradient(
                colors: [
                    Color(rgb: 0xF4FFFC),
                    Color(rgb: 0xE6F4FF),
                    Color(rgb: 0xD9E8FA),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .accessBanner:
            return LinearGradient(
                colors: [
                    Color(rgb: 0xF6F8FC),
                    Color(rgb: 0xE8EDF5),
                    Color(rgb: 0xD9E2EE),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .miniChip:
            return LinearGradient(
                colors: [
                    Color(rgb: 0xFFFFFF).opacity(0.94),
                    Color(rgb: 0xEFF3F8),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .miniAccent(let i):
            return Self.miniAccentGradient(index: i)
        case .matchRowWin:
            return LinearGradient(
                colors: [
                    Color(rgb: 0xF0FFFC),
                    Color(rgb: 0xD2FAF0),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .matchRowLose:
            return LinearGradient(
                colors: [
                    Color(rgb: 0xFFFAF6),
                    Color(rgb: 0xFFE4D4),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private static func miniAccentGradient(index: Int) -> LinearGradient {
        let palettes: [[Color]] = [
            [Color(rgb: 0xE8FFFD), Color(rgb: 0xC5F5EE)],
            [Color(rgb: 0xE8F4FF), Color(rgb: 0xC9E2FC)],
            [Color(rgb: 0xFFF4E8), Color(rgb: 0xFCD9C0)],
            [Color(rgb: 0xFFF0FA), Color(rgb: 0xF7CDE6)],
            [Color(rgb: 0xF2FFE8), Color(rgb: 0xDBF5C8)],
            [Color(rgb: 0xF5EDFF), Color(rgb: 0xE0D4FC)],
        ]
        let colors = palettes[index % palettes.count]
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var borderColor: Color {
        switch self {
        case .battleReadiness:
            return Color(rgb: 0x00C6B0).opacity(0.22)
        case .componentBreakdown:
            return Color(rgb: 0x8B7FD8).opacity(0.24)
        case .weekChart:
            return Color(rgb: 0x2FA8E6).opacity(0.24)
        case .weekComparison:
            return Color(rgb: 0x5B7FD4).opacity(0.24)
        case .consistency:
            return Color(rgb: 0x5CB85C).opacity(0.26)
        case .battleStats:
            return Color(rgb: 0xFF8A4C).opacity(0.26)
        case .pastMatchesPanel:
            return Color(rgb: 0xE878B8).opacity(0.22)
        case .sleepLastNight:
            return Color(rgb: 0x6B7FD9).opacity(0.24)
        case .sleepRatio:
            return Color(rgb: 0xA97FD9).opacity(0.24)
        case .sleepSevenNight:
            return Color(rgb: 0x4DA3E8).opacity(0.24)
        case .competitionEdge:
            return Color(rgb: 0x2BA8C9).opacity(0.26)
        case .accessBanner:
            return Color(rgb: 0x7A8AA3).opacity(0.22)
        case .miniChip:
            return Color(rgb: 0x94A3B8).opacity(0.28)
        case .miniAccent(let i):
            let accents: [Color] = [
                Color(rgb: 0x00C6B0).opacity(0.30),
                Color(rgb: 0x3B9FE8).opacity(0.30),
                Color(rgb: 0xFF8A4C).opacity(0.30),
                Color(rgb: 0xE868B8).opacity(0.30),
                Color(rgb: 0x7FD956).opacity(0.32),
                Color(rgb: 0xA97FD9).opacity(0.30),
            ]
            return accents[i % accents.count]
        case .matchRowWin:
            return FitUpColors.Neon.cyan.opacity(0.28)
        case .matchRowLose:
            return FitUpColors.Neon.orange.opacity(0.28)
        }
    }

    var shadowColor: Color {
        switch self {
        case .battleReadiness:
            return Color(rgb: 0x00C6B0).opacity(0.12)
        case .componentBreakdown:
            return Color(rgb: 0x8B7FD8).opacity(0.12)
        case .weekChart:
            return Color(rgb: 0x2FA8E6).opacity(0.12)
        case .weekComparison:
            return Color(rgb: 0x5B7FD4).opacity(0.12)
        case .consistency:
            return Color(rgb: 0x5CB85C).opacity(0.11)
        case .battleStats:
            return Color(rgb: 0xFF8A4C).opacity(0.12)
        case .pastMatchesPanel:
            return Color(rgb: 0xE878B8).opacity(0.11)
        case .sleepLastNight:
            return Color(rgb: 0x6B7FD9).opacity(0.11)
        case .sleepRatio:
            return Color(rgb: 0xA97FD9).opacity(0.11)
        case .sleepSevenNight:
            return Color(rgb: 0x4DA3E8).opacity(0.11)
        case .competitionEdge:
            return Color(rgb: 0x2BA8C9).opacity(0.11)
        case .accessBanner:
            return Color.black.opacity(0.08)
        case .miniChip:
            return Color.black.opacity(0.06)
        case .miniAccent(let i):
            let colors: [Color] = [
                Color(rgb: 0x00C6B0).opacity(0.10),
                Color(rgb: 0x3B9FE8).opacity(0.10),
                Color(rgb: 0xFF8A4C).opacity(0.10),
                Color(rgb: 0xE868B8).opacity(0.10),
                Color(rgb: 0x7FD956).opacity(0.10),
                Color(rgb: 0xA97FD9).opacity(0.10),
            ]
            return colors[i % colors.count]
        case .matchRowWin:
            return FitUpColors.Neon.cyan.opacity(0.10)
        case .matchRowLose:
            return FitUpColors.Neon.orange.opacity(0.10)
        }
    }
}

struct HealthGamifiedCardModifier: ViewModifier {
    let variant: HealthGamifiedCardVariant

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: variant.cornerRadius, style: .continuous)
                    .fill(variant.fillGradient)
                    .overlay {
                        RoundedRectangle(cornerRadius: variant.cornerRadius, style: .continuous)
                            .strokeBorder(variant.borderColor, lineWidth: 1)
                    }
                    .shadow(color: variant.shadowColor, radius: 14, x: 0, y: 8)
                    .shadow(color: Color.black.opacity(0.07), radius: 5, x: 0, y: 2)
            }
    }
}

extension View {
    func glassCard(_ variant: GlassCardVariant) -> some View {
        modifier(GlassCardModifier(variant: variant))
    }

    func homeLiquidGlassCard(_ variant: GlassCardVariant) -> some View {
        modifier(HomeLiquidGlassCardModifier(variant: variant))
    }

    func healthGamifiedCard(_ variant: HealthGamifiedCardVariant) -> some View {
        modifier(HealthGamifiedCardModifier(variant: variant))
    }
}

// MARK: - solidBtn / ghostBtn

struct SolidButtonModifier: ViewModifier {
    let accent: Color

    func body(content: Content) -> some View {
        content
            .font(FitUpFont.body(15, weight: .heavy))
            .foregroundStyle(.black)
            .padding(.horizontal, FitUpRadius.md)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.8), accent.opacity(0.53)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                            .strokeBorder(accent.opacity(0.31), lineWidth: 1)
                    }
                    .shadow(color: accent.opacity(0.27), radius: 12, x: 0, y: 0)
            }
    }
}

struct GhostButtonModifier: ViewModifier {
    let accent: Color

    func body(content: Content) -> some View {
        content
            .font(FitUpFont.body(14, weight: .heavy))
            .foregroundStyle(accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(accent.opacity(0.10))
                    .overlay {
                        Capsule()
                            .strokeBorder(accent.opacity(0.31), lineWidth: 1)
                    }
            }
    }
}

extension View {
    func solidButton(color accent: Color) -> some View {
        modifier(SolidButtonModifier(accent: accent))
    }

    func ghostButton(color accent: Color) -> some View {
        modifier(GhostButtonModifier(accent: accent))
    }
}

// MARK: - Global title text styling

extension Text {
    /// Shared title treatment for Home/Health/Profile heading labels.
    func fitUpGlobalTitleStyle(
        weight: Font.Weight = .semibold,
        tracking: CGFloat = 0.7
    ) -> some View {
        self
            .fontWeight(weight)
            .tracking(tracking)
            .foregroundStyle(FitUpColors.Text.title)
    }

    /// Uppercase section labels inside light health cards (shared ink color).
    func fitUpHealthSectionTitleStyle(
        weight: Font.Weight = .heavy,
        tracking: CGFloat = 2
    ) -> some View {
        self
            .fontWeight(weight)
            .tracking(tracking)
            .foregroundStyle(FitUpColors.HealthSection.title)
    }
}

// MARK: - BG_STYLE

struct BackgroundGradientView: View {
    var body: some View {
        ZStack {
            FitUpColors.Bg.base
            RadialGradient(
                colors: [
                    Color(red: 0, green: 1, blue: 0.878, opacity: 0.038),
                    .clear,
                ],
                center: UnitPoint(x: 0.15, y: 0.08),
                startRadius: 0,
                endRadius: 400
            )
            RadialGradient(
                colors: [
                    Color(red: 0, green: 0.667, blue: 1, opacity: 0.038),
                    .clear,
                ],
                center: UnitPoint(x: 0.85, y: 0.88),
                startRadius: 0,
                endRadius: 360
            )
            RadialGradient(
                colors: [
                    Color(red: 1, green: 0.384, blue: 0, opacity: 0.018),
                    .clear,
                ],
                center: .center,
                startRadius: 0,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - ScreenIn (0.26s ease)

struct ScreenTransitionModifier: ViewModifier {
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 12)
            .animation(.easeOut(duration: 0.26), value: visible)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                    visible = true
                }
            }
    }
}

extension View {
    func screenTransition() -> some View {
        modifier(ScreenTransitionModifier())
    }
}

// MARK: - Previews

#Preview("Glass variants") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(GlassCardVariant.allCases, id: \.self) { v in
                Text(String(describing: v).capitalized)
                    .font(FitUpFont.display(16))
                    .foregroundStyle(FitUpColors.Text.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .glassCard(v)
            }
        }
        .padding()
    }
    .background { BackgroundGradientView() }
}
