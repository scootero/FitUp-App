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

extension View {
    func glassCard(_ variant: GlassCardVariant) -> some View {
        modifier(GlassCardModifier(variant: variant))
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
