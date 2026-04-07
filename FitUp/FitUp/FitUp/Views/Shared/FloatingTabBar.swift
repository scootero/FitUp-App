//
//  FloatingTabBar.swift
//  FitUp
//
//  Maps JSX `BottomNav` — floating card, five slots: Home, Health, Battle, Ranks, Profile.
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
        case .health: return "HEALTH"
        case .ranks: return "RANKS"
        case .profile: return "PROFILE"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .health: return "heart.fill"
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
    private let bottomPadding: CGFloat = 10
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
        .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: -4)
        .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, bottomPadding)
    }

    private var barBackground: some View {
        RoundedRectangle(cornerRadius: FitUpRadius.xl, style: .continuous)
            .fill(Color(red: 5 / 255, green: 5 / 255, blue: 10 / 255, opacity: 0.92))
            .background {
                RoundedRectangle(cornerRadius: FitUpRadius.xl, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: FitUpRadius.xl, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: FitUpRadius.xl, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.04), lineWidth: 1)
                    .padding(-1)
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
            .background {
                RoundedRectangle(cornerRadius: battleCorner, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: FitUpColors.Neon.cyan.opacity(0.35), radius: 10, x: 0, y: 2)
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
                    .foregroundStyle(isSelected ? FitUpColors.Neon.cyan : Color.white.opacity(0.55))
                    .opacity(isSelected ? 1 : 0.35)
                    .shadow(color: isSelected ? FitUpColors.Neon.cyan.opacity(0.45) : .clear, radius: 6, x: 0, y: 0)

                Text(tab.label)
                    .font(FitUpFont.body(9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(isSelected ? FitUpColors.Neon.cyan : FitUpColors.Text.tertiary)
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
