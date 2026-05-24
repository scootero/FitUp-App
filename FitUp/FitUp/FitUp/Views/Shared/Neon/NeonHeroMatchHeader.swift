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

// MARK: - Header stack

struct NeonHeroMatchHeader: View {
  let content: NeonHeroMatchHeaderContent
  /// When true, only meta pills + day caption (names/VS live in the hero top row).
  var metaOnly: Bool = false

  var body: some View {
    VStack(spacing: 14) {
      if !metaOnly {
        NeonRetroVersusBanner(
          userName: content.userDisplayName,
          opponentName: content.opponentDisplayName
        )
      }

      if !content.pills.isEmpty {
        NeonHeroMetaPillsRow(pills: content.pills)
      }

      if !content.dayProgressLabel.isEmpty {
        Text(content.dayProgressLabel.uppercased())
          .font(FitUpFont.mono(13, weight: .heavy))
          .tracking(2.2)
          .foregroundStyle(HomePageStyle.offWhite)
          .shadow(color: FitUpColors.Neon.cyan.opacity(0.35), radius: 8, x: 0, y: 0)
          .shadow(color: Color.white.opacity(0.18), radius: 4, x: 0, y: 0)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity)
          .lineLimit(1)
          .minimumScaleFactor(0.75)
          .allowsTightening(true)
      }
    }
    .frame(maxWidth: .infinity)
  }
}

// MARK: - Shared VS mark (hero top row)

struct HeroNeonVersusMark: View {
  var style: Style = .redRetro

  enum Style {
    case redRetro
    case gradient
  }

  var body: some View {
    Text("VS")
      .font(FitUpFont.display(28, weight: .black))
      .tracking(1.8)
      .foregroundStyle(foregroundGradient)
      .shadow(color: shadowPrimary, radius: 12, x: 0, y: 0)
      .shadow(color: shadowSecondary, radius: 22, x: 0, y: 0)
      .shadow(color: Color.white.opacity(0.22), radius: 4, x: 0, y: 0)
      .accessibilityLabel("Versus")
  }

  private var foregroundGradient: LinearGradient {
    switch style {
    case .redRetro:
      LinearGradient(
        colors: [
          Color(red: 1, green: 0.22, blue: 0.28),
          FitUpColors.Neon.pink,
          Color(red: 1, green: 0.45, blue: 0.12),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    case .gradient:
      LinearGradient(
        colors: [
          FitUpColors.Neon.pink,
          FitUpColors.Neon.purple,
          FitUpColors.Neon.yellow.opacity(0.95),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
  }

  private var shadowPrimary: Color {
    switch style {
    case .redRetro: return Color(red: 1, green: 0.2, blue: 0.25).opacity(0.75)
    case .gradient: return FitUpColors.Neon.pink.opacity(0.72)
    }
  }

  private var shadowSecondary: Color {
    switch style {
    case .redRetro: return FitUpColors.Neon.orange.opacity(0.45)
    case .gradient: return FitUpColors.Neon.purple.opacity(0.55)
    }
  }
}

// MARK: - YOU vs OPPONENT

private struct NeonRetroVersusBanner: View {
    let userName: String
    let opponentName: String

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            retroPlayerName(userName, accent: FitUpColors.Neon.cyan)
                .frame(maxWidth: .infinity, alignment: .trailing)

            versusMark
                .layoutPriority(1)

            retroPlayerName(opponentName, accent: FitUpColors.Neon.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    private var versusMark: some View {
        Text("VS")
            .font(FitUpFont.display(26, weight: .black))
            .tracking(1.6)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        FitUpColors.Neon.pink,
                        FitUpColors.Neon.purple,
                        FitUpColors.Neon.yellow.opacity(0.95),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: FitUpColors.Neon.pink.opacity(0.72), radius: 12, x: 0, y: 0)
            .shadow(color: FitUpColors.Neon.purple.opacity(0.55), radius: 22, x: 0, y: 0)
            .shadow(color: Color.white.opacity(0.22), radius: 4, x: 0, y: 0)
            .accessibilityLabel("Versus")
    }

    private func retroPlayerName(_ name: String, accent: Color) -> some View {
        Text(displayName(name))
            .font(FitUpFont.display(15, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(accent)
            .shadow(color: accent.opacity(0.75), radius: 10, x: 0, y: 0)
            .shadow(color: accent.opacity(0.35), radius: 20, x: 0, y: 0)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .allowsTightening(true)
    }

    private func displayName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "YOU" }
        return trimmed.uppercased()
    }
}

// MARK: - Meta pills row

private struct NeonHeroMetaPillsRow: View {
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

    var body: some View {
        Text(label.uppercased())
            .font(FitUpFont.mono(11, weight: .heavy))
            .tracking(0.55)
            .foregroundStyle(accent)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
            .allowsTightening(true)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.58))
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        accent.opacity(0.42),
                                        accent.opacity(0.18),
                                        accent.opacity(0.07),
                                        Color.clear,
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 52
                                )
                            )
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accent.opacity(0.14),
                                        Color.clear,
                                        Color.black.opacity(0.32),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(accent.opacity(0.88), lineWidth: 1.5)
                    }
                    .shadow(color: accent.opacity(0.58), radius: 10, x: 0, y: 0)
                    .shadow(color: accent.opacity(0.28), radius: 20, x: 0, y: 0)
                    .shadow(color: Color.black.opacity(0.45), radius: 6, x: 0, y: 4)
            }
    }
}

#if DEBUG
#Preview {
    NeonHeroMatchHeader(
        content: NeonHeroMatchHeaderContent(
            userDisplayName: "Scott",
            opponentDisplayName: "Mike",
            pills: [
                NeonHeroMetaPill(id: "metric", label: "Steps", accent: FitUpColors.Neon.cyan),
                NeonHeroMetaPill(id: "duration", label: "3-day match", accent: FitUpColors.Neon.purple),
                NeonHeroMetaPill(id: "scoring", label: "Raw Battle", accent: FitUpColors.Neon.orange),
            ],
            dayProgressLabel: "Day 3 of 3"
        )
    )
    .padding()
    .background(FitUpColors.Bg.base)
}
#endif
