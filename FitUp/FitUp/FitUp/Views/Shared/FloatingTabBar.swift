//
//  FloatingTabBar.swift
//  FitUp
//
//  Maps JSX `BottomNav` — floating card, five slots: Home, Stats, Battle, Ranks, Profile.
//  Center Battle opens the challenge flow; label lives inside the gradient card.
//

import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case home
    case health
    case ranks
    case profile

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: return "HOME"
        case .health: return "STATS"
        case .ranks: return "RANKS"
        case .profile: return "PROFILE"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .health: return "chart.bar.fill"
        case .ranks: return "trophy.fill"
        case .profile: return "person.fill"
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selected: MainTab
    /// When false, the center Battle card uses a slow fiery red glow to invite a new match.
    var hasActiveBattle: Bool
    var onBattle: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let barHeight: CGFloat = 68
    private let battleCorner: CGFloat = 16

    private var showsIdleBattleFire: Bool { !hasActiveBattle }

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home)
            tabButton(.health)
            battleColumn
            tabButton(.ranks)
            tabButton(.profile)
        }
        .frame(height: barHeight, alignment: .center)
        .frame(maxWidth: .infinity)
        .background { barBackground }
        .clipShape(RoundedRectangle(cornerRadius: FitUpRadius.xl, style: .continuous))
        .shadow(color: FitUpColors.Neon.cyan.opacity(0.24), radius: 18, x: 0, y: 2)
        .shadow(color: .black.opacity(0.55), radius: 20, x: 0, y: 10)
        .padding(.horizontal, FitUpLayout.floatingBottomBarHorizontalPadding)
        .padding(.bottom, FitUpLayout.floatingBottomBarBottomPadding)
    }

    private var barBackground: some View {
        TimelineView(.animation(minimumInterval: 1 / 28, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let angle = Angle(degrees: (t * 5).truncatingRemainder(dividingBy: 360))

            RoundedRectangle(cornerRadius: FitUpRadius.xl, style: .continuous)
                .fill(Color(red: 16 / 255, green: 24 / 255, blue: 34 / 255, opacity: 0.70))
                .background {
                    RoundedRectangle(cornerRadius: FitUpRadius.xl, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: FitUpRadius.xl, style: .continuous)
                        .fill(
                            AngularGradient(
                                colors: [
                                    FitUpColors.Neon.cyan.opacity(0.40),
                                    FitUpColors.Neon.blue.opacity(0.35),
                                    FitUpColors.Neon.purple.opacity(0.32),
                                    FitUpColors.Neon.green.opacity(0.28),
                                    FitUpColors.Neon.cyan.opacity(0.40),
                                ],
                                center: .center,
                                angle: angle
                            )
                        )
                        .blendMode(.screen)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: FitUpRadius.xl, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: FitUpRadius.xl, style: .continuous)
                        .strokeBorder(FitUpColors.Neon.cyan.opacity(0.18), lineWidth: 1)
                        .padding(-1)
                }
        }
    }

    private var battleColumn: some View {
        Button(action: onBattle) {
            VStack(spacing: 4) {
                Text("⚔️")
                    .font(.system(size: showsIdleBattleFire ? 18 : 17))
                Text("BATTLE")
                    .font(FitUpFont.body(9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(showsIdleBattleFire ? 1 : 0.95))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, showsIdleBattleFire ? 9 : 8)
            .padding(.horizontal, 4)
            .offset(y: showsIdleBattleFire ? -4 : -1)
            .scaleEffect(showsIdleBattleFire ? 1.08 : 1.03)
            .background {
                Group {
                    if showsIdleBattleFire {
                        idleBattleFireBackground
                    } else {
                        activeBattleBackground
                    }
                }
            }
            .animation(.easeInOut(duration: 0.55), value: showsIdleBattleFire)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showsIdleBattleFire ? "Start a battle" : "Battle")
    }

    private var activeBattleBackground: some View {
        RoundedRectangle(cornerRadius: battleCorner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.blue, FitUpColors.Neon.purple.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: FitUpColors.Neon.cyan.opacity(0.48), radius: 14, x: 0, y: 3)
            .shadow(color: FitUpColors.Neon.blue.opacity(0.34), radius: 18, x: 0, y: 6)
            .overlay(alignment: .top) { battleCardTopShine }
            .overlay { battleCardOuterStroke }
    }

    @ViewBuilder
    private var idleBattleFireBackground: some View {
        if reduceMotion {
            idleBattleFireBackground(at: 0)
        } else {
            TimelineView(.animation(minimumInterval: 1 / 24, paused: false)) { timeline in
                idleBattleFireBackground(at: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func idleBattleFireBackground(at time: TimeInterval) -> some View {
        let angle = Angle(degrees: (time * 8).truncatingRemainder(dividingBy: 360))
        let pulse = 0.55 + 0.45 * sin(time * 0.62)
        let drift = sin(time * 0.38) * 0.14

        return RoundedRectangle(cornerRadius: battleCorner, style: .continuous)
            .fill(
                AngularGradient(
                    colors: [
                        Color(rgb: 0xFF1A00),
                        FitUpColors.Neon.red,
                        FitUpColors.Neon.orange,
                        FitUpColors.Neon.yellow.opacity(0.96),
                        Color(rgb: 0xFF4500),
                        FitUpColors.Neon.red.opacity(0.94),
                        Color(rgb: 0xFF1A00),
                    ],
                    center: .center,
                    angle: angle
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: battleCorner, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                FitUpColors.Neon.yellow.opacity(0.24 + 0.08 * pulse),
                                Color.clear,
                                FitUpColors.Neon.red.opacity(0.20 + 0.07 * pulse),
                            ],
                            startPoint: UnitPoint(x: 0.44 + drift, y: 1),
                            endPoint: UnitPoint(x: 0.56 - drift, y: 0)
                        )
                    )
                    .blendMode(.screen)
            }
            .shadow(color: FitUpColors.Neon.orange.opacity(0.36 + 0.16 * pulse), radius: 14 + 5 * pulse, x: 0, y: 4)
            .shadow(color: FitUpColors.Neon.red.opacity(0.30 + 0.12 * pulse), radius: 20 + 7 * pulse, x: 0, y: 7)
            .overlay(alignment: .top) { battleCardTopShine }
            .overlay { battleCardOuterStroke }
    }

    private var battleCardTopShine: some View {
        RoundedRectangle(cornerRadius: battleCorner, style: .continuous)
            .strokeBorder(Color.white.opacity(0.36), lineWidth: 0.7)
            .blur(radius: 0.2)
            .mask(
                LinearGradient(
                    colors: [Color.white, Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private var battleCardOuterStroke: some View {
        RoundedRectangle(cornerRadius: battleCorner, style: .continuous)
            .strokeBorder(Color(red: 5 / 255, green: 5 / 255, blue: 10 / 255, opacity: 0.92), lineWidth: 2)
    }

    private func tabButton(_ tab: MainTab) -> some View {
        let isSelected = selected == tab
        return Button {
            selected = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(isSelected ? FitUpColors.Neon.cyan : Color(red: 0.78, green: 0.88, blue: 1.0))
                    .opacity(isSelected ? 1 : 0.82)
                    .shadow(color: isSelected ? FitUpColors.Neon.cyan.opacity(0.45) : .clear, radius: 6, x: 0, y: 0)

                Text(tab.label)
                    .font(FitUpFont.body(9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(isSelected ? FitUpColors.Neon.cyan : Color(red: 0.78, green: 0.88, blue: 1.0).opacity(0.90))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Idle fire") {
    struct PreviewHost: View {
        @State private var tab: MainTab = .home
        var body: some View {
            ZStack(alignment: .bottom) {
                BackgroundGradientView()
                FloatingTabBar(selected: $tab, hasActiveBattle: false, onBattle: {})
            }
        }
    }
    return PreviewHost()
}

#Preview("Active battle") {
    struct PreviewHost: View {
        @State private var tab: MainTab = .home
        var body: some View {
            ZStack(alignment: .bottom) {
                BackgroundGradientView()
                FloatingTabBar(selected: $tab, hasActiveBattle: true, onBattle: {})
            }
        }
    }
    return PreviewHost()
}
