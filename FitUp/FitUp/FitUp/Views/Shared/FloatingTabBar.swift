//
//  FloatingTabBar.swift
//  FitUp
//
//  Maps JSX `BottomNav` — floating card, 6 slots, center BATTLE elevated 14pt.
//

import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case home
    case activity
    case health
    case profile
    case ranks

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: return "HOME"
        case .activity: return "BATTLES"
        case .health: return "HEALTH"
        case .profile: return "PROFILE"
        case .ranks: return "RANKS"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .activity: return "figure.run"
        case .health: return "heart.fill"
        case .profile: return "person.fill"
        case .ranks: return "trophy.fill"
        }
    }

    /// Visual column index in the bar (0…5), skipping center battle at 2.
    var barIndex: Int {
        switch self {
        case .home: return 0
        case .activity: return 1
        case .health: return 3
        case .profile: return 4
        case .ranks: return 5
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selected: MainTab
    var onBattle: () -> Void

    private let barHeight: CGFloat = 68
    private let horizontalPadding: CGFloat = 12
    private let bottomPadding: CGFloat = 10
    private let battleSize: CGFloat = 54
    private let battleCorner: CGFloat = 18
    private let battleLift: CGFloat = 14

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { column in
                if column == 2 {
                    battleColumn
                } else if let tab = tab(at: column) {
                    tabButton(tab)
                }
            }
        }
        .padding(.top, 10)
        .frame(height: barHeight, alignment: .top)
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
        VStack(spacing: 3) {
            ZStack {
                Button(action: onBattle) {
                    Text("⚔️")
                        .font(.system(size: 22))
                        .frame(width: battleSize, height: battleSize)
                        .background {
                            RoundedRectangle(cornerRadius: battleCorner, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: FitUpColors.Neon.cyan.opacity(0.4), radius: 12, x: 0, y: 4)
                                .overlay {
                                    RoundedRectangle(cornerRadius: battleCorner, style: .continuous)
                                        .strokeBorder(Color(red: 5 / 255, green: 5 / 255, blue: 10 / 255, opacity: 0.92), lineWidth: 3)
                                }
                        }
                }
                .buttonStyle(.plain)
                .offset(y: -battleLift)
            }
            .frame(height: 30)

            Text("BATTLE")
                .font(FitUpFont.body(9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(FitUpColors.Text.tertiary)
        }
        .frame(maxWidth: .infinity)
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

    private func tab(at column: Int) -> MainTab? {
        MainTab.allCases.first { $0.barIndex == column }
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
