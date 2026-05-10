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
    var onBattle: () -> Void

    private let barHeight: CGFloat = 68
    private let horizontalPadding: CGFloat = 12
    private let bottomPadding: CGFloat = 2
    private let battleCorner: CGFloat = 16

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
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, bottomPadding)
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
                    .font(.system(size: 17))
                Text("BATTLE")
                    .font(FitUpFont.body(9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.95))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .offset(y: -1)
            .scaleEffect(1.03)
            .background {
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
                    .overlay(alignment: .top) {
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
                    .overlay {
                        RoundedRectangle(cornerRadius: battleCorner, style: .continuous)
                            .strokeBorder(Color(red: 5 / 255, green: 5 / 255, blue: 10 / 255, opacity: 0.92), lineWidth: 2)
                    }
            }
        }
        .buttonStyle(.plain)
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

#Preview {
    struct PreviewHost: View {
        @State private var tab: MainTab = .home
        var body: some View {
            ZStack(alignment: .bottom) {
                BackgroundGradientView()
                FloatingTabBar(selected: $tab, onBattle: {})
            }
        }
    }
    return PreviewHost()
}
