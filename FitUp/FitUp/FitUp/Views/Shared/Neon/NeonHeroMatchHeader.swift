//
//  NeonHeroMatchHeader.swift
//  FitUp
//
//  Retro VS banner + glowing meta pills + centered day progress for the Home energy hero.
//

import SwiftUI

struct NeonHeroMetaPill {
    let id: String
    let label: String
    let accent: Color
}

struct NeonHeroMatchHeaderContent: Equatable {
    let userDisplayName: String
    let opponentDisplayName: String
    let pills: [NeonHeroMetaPill]
    let dayProgressLabel: String

    static func == (lhs: NeonHeroMatchHeaderContent, rhs: NeonHeroMatchHeaderContent) -> Bool {
        lhs.userDisplayName == rhs.userDisplayName
            && lhs.opponentDisplayName == rhs.opponentDisplayName
            && lhs.dayProgressLabel == rhs.dayProgressLabel
            && lhs.pills.map(\.id) == rhs.pills.map(\.id)
            && lhs.pills.map(\.label) == rhs.pills.map(\.label)
    }
}

// MARK: - Layout (VS row + player columns share insets)

enum NeonHeroVersusLayout {
    /// Pushes user/opponent columns toward card edges so names sit over each profile stack.
    static let playerColumnEdgeInset: CGFloat = 26
    static let playerColumnSpacing: CGFloat = 6
    /// Keeps avatar → “steps today” gap after removing the in-column name row.
    static let profileNameBelowAvatarReservedHeight: CGFloat = 12
}

// MARK: - Day progress banner (top of card)

struct NeonHeroDayProgressBanner: View {
    let label: String

    @Environment(\.homeHeroCompactScale) private var compactScale

    var body: some View {
        Text(label.uppercased())
            .font(FitUpFont.mono(HomeHeroCompactLayout.scaled(16, by: compactScale), weight: .heavy))
            .tracking(5.2 * compactScale)
            .foregroundStyle(FitUpColors.Neon.cyan.opacity(0.92))
            .shadow(color: FitUpColors.Neon.cyan.opacity(0.35), radius: 10, x: 0, y: 0)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
    }
}

// MARK: - Header stack (legacy composite — day + pills only)

struct NeonHeroMatchHeader: View {
    let content: NeonHeroMatchHeaderContent

    var body: some View {
        VStack(spacing: 10) {
            NeonHeroDayProgressBanner(label: content.dayProgressLabel)
            NeonHeroMetaPillsRow(pills: content.pills)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Capsule chrome (border + outer glow, faint inner edge)

/// Border-first glow: shadows sit outside the shape; a thin inner rim fades within ~3pt.
struct NeonGlowCapsuleChrome: View {
    let accent: Color

    var body: some View {
        Capsule(style: .continuous)
            .fill(Color.black.opacity(0.58))
            .overlay {
                Capsule(style: .continuous)
                    .inset(by: 0.5)
                    .strokeBorder(accent.opacity(0.22), lineWidth: 3)
                    .blur(radius: 1.4)
                    .mask {
                        Capsule(style: .continuous)
                            .fill(Color.black)
                    }
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(accent.opacity(0.9), lineWidth: 1.5)
            }
            .shadow(color: accent.opacity(0.52), radius: 6, x: 0, y: 0)
            .shadow(color: accent.opacity(0.26), radius: 11, x: 0, y: 0)
            .shadow(color: Color.black.opacity(0.42), radius: 5, x: 0, y: 3)
    }
}

// MARK: - Sparky hero name (cheap CPU flicker back to accent)

struct NeonSparkyHeroName: View {
    let text: String
    let accent: Color
    var alignment: HorizontalAlignment = .center

    @Environment(\.homeHeroCompactScale) private var compactScale

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 14.0)) { timeline in
            let wall = timeline.date.timeIntervalSinceReferenceDate
            let spark = sparkIntensity(at: wall)
            let display = displayName(text)

            Text(display)
                .font(FitUpFont.display(HomeHeroCompactLayout.scaled(24, by: compactScale), weight: .black))
                .tracking(1.8 * compactScale)
                .foregroundStyle(accent)
                .overlay {
                    Text(display)
                        .font(FitUpFont.display(HomeHeroCompactLayout.scaled(24, by: compactScale), weight: .black))
                        .tracking(1.8 * compactScale)
                        .foregroundStyle(Color.white.opacity(Double(spark) * 0.55))
                        .blendMode(.plusLighter)
                }
                .shadow(color: accent.opacity(0.55 + spark * 0.35), radius: 6 + spark * 6, x: 0, y: 0)
                .shadow(color: Color.white.opacity(spark * 0.42), radius: 2 + spark * 5, x: 0, y: 0)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .allowsTightening(true)
                .multilineTextAlignment(alignment == .leading ? .leading : alignment == .trailing ? .trailing : .center)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
        }
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .leading: return .leading
        case .trailing: return .trailing
        default: return .center
        }
    }

    /// Occasional bright spikes that fall back to the team accent.
    private func sparkIntensity(at wall: TimeInterval) -> CGFloat {
        let slow = sin(wall * 6.4) * 0.5 + 0.5
        let fast = sin(wall * 14.8 + 0.9) * 0.5 + 0.5
        let spike = sin(wall * 23.5 + 2.1) * 0.5 + 0.5
        let mix = slow * fast
        return CGFloat(pow(Double(mix), 2.4) * (0.35 + Double(spike) * 0.65))
    }

    private func displayName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "YOU" }
        return trimmed.uppercased()
    }
}

// MARK: - YOU vs OPPONENT

struct NeonRetroVersusBanner: View {
    let userName: String
    let opponentName: String

    @Environment(\.homeHeroCompactScale) private var compactScale

    var body: some View {
        HStack(alignment: .bottom, spacing: HomeHeroCompactLayout.scaled(NeonHeroVersusLayout.playerColumnSpacing, by: compactScale)) {
            NeonSparkyHeroName(text: userName, accent: FitUpColors.Neon.cyan, alignment: .center)
                .frame(maxWidth: .infinity)
                .padding(.leading, HomeHeroCompactLayout.scaled(NeonHeroVersusLayout.playerColumnEdgeInset, by: compactScale))

            versusMark
                .layoutPriority(1)
                .padding(.horizontal, HomeHeroCompactLayout.scaled(4, by: compactScale))

            NeonSparkyHeroName(text: opponentName, accent: FitUpColors.Neon.orange, alignment: .center)
                .frame(maxWidth: .infinity)
                .padding(.trailing, HomeHeroCompactLayout.scaled(NeonHeroVersusLayout.playerColumnEdgeInset, by: compactScale))
        }
        .frame(maxWidth: .infinity)
        .padding(.leading, HomeHeroCompactLayout.scaled(6, by: compactScale))
    }

    private var versusMark: some View {
        Text("VS")
            .font(FitUpFont.display(HomeHeroCompactLayout.scaled(34, by: compactScale), weight: .black))
            .tracking(4.8 * compactScale)
            .foregroundStyle(Color.white)
            .scaleEffect(x: 1.18, y: 1)
            .shadow(color: Color.white.opacity(0.28), radius: HomeHeroCompactLayout.scaled(8, by: compactScale), x: 0, y: 0)
            .offset(y: HomeHeroCompactLayout.scaled(8, by: compactScale))
            .accessibilityLabel("Versus")
    }
}

// MARK: - Meta pills row

struct NeonHeroMetaPillsRow: View {
    let pills: [NeonHeroMetaPill]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(pills, id: \.id) { pill in
                NeonGlowMetaPill(label: pill.label, accent: pill.accent)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct NeonGlowMetaPill: View {
    let label: String
    let accent: Color

    @Environment(\.homeHeroCompactScale) private var compactScale

    var body: some View {
        Text(label.uppercased())
            .font(FitUpFont.mono(HomeHeroCompactLayout.scaled(11, by: compactScale), weight: .heavy))
            .tracking(0.55 * compactScale)
            .foregroundStyle(accent)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
            .allowsTightening(true)
            .multilineTextAlignment(.center)
            .padding(.horizontal, HomeHeroCompactLayout.scaled(8, by: compactScale))
            .padding(.vertical, HomeHeroCompactLayout.scaled(7, by: compactScale))
            .frame(maxWidth: .infinity)
            .background {
                NeonGlowCapsuleChrome(accent: accent)
            }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 18) {
        NeonHeroDayProgressBanner(label: "Day 3 of 3")
        NeonHeroMetaPillsRow(
            pills: [
                NeonHeroMetaPill(id: "metric", label: "Steps", accent: FitUpColors.Neon.cyan),
                NeonHeroMetaPill(id: "duration", label: "Win 2 days", accent: FitUpColors.Neon.purple),
                NeonHeroMetaPill(id: "scoring", label: "Raw Battle", accent: FitUpColors.Neon.orange),
            ]
        )
        NeonRetroVersusBanner(userName: "Scott", opponentName: "Mike")
    }
    .padding()
    .background(FitUpColors.Bg.base)
}
#endif
