//
//  HeroActiveOpponentPickerRow.swift
//  FitUp
//
//  Horizontal neon chips to switch the Home energy hero between active step battles.
//

import SwiftUI

struct HeroActiveOpponentPickerRow: View {
    let matches: [HomeActiveMatch]
    let selectedMatchId: UUID?
    var onSelect: (HomeActiveMatch) -> Void

    private let maxSpreadCount = 4

    var body: some View {
        if matches.count > 1 {
            Group {
                if matches.count <= maxSpreadCount {
                    spreadRow
                } else {
                    scrollRow
                }
            }
            .padding(.horizontal, 14)
        }
    }

    private var spreadRow: some View {
        HStack(spacing: 8) {
            ForEach(matches) { match in
                chipButton(for: match)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var scrollRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(matches) { match in
                    chipButton(for: match)
                        .frame(minWidth: 88)
                }
            }
            .padding(.trailing, 2)
        }
    }

    private func chipButton(for match: HomeActiveMatch) -> some View {
        let isSelected = match.id == selectedMatchId
        return Button {
            onSelect(match)
        } label: {
            HeroActiveOpponentPickerChip(
                opponent: match.opponent,
                isSelected: isSelected
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(displayName(for: match.opponent)), \(isSelected ? "selected" : "switch hero battle")")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func displayName(for opponent: HomeOpponent) -> String {
        let trimmed = opponent.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let initials = opponent.initials.trimmingCharacters(in: .whitespacesAndNewlines)
        if !initials.isEmpty { return initials }
        return "Opponent"
    }
}

// MARK: - Chip

private struct HeroActiveOpponentPickerChip: View {
    let opponent: HomeOpponent
    let isSelected: Bool

    private var accent: Color {
        ProfileAccentColor.swiftUIColor(hex: opponent.colorHex)
    }

    private var label: String {
        let trimmed = opponent.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed.uppercased() }
        let initials = opponent.initials.trimmingCharacters(in: .whitespacesAndNewlines)
        if !initials.isEmpty { return initials.uppercased() }
        return "OPP"
    }

    private var initials: String {
        let trimmed = opponent.initials.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return String(trimmed.prefix(2)).uppercased() }
        let name = opponent.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.count >= 2 { return String(name.prefix(2)).uppercased() }
        if let first = name.first { return String(first).uppercased() }
        return "?"
    }

    var body: some View {
        HStack(spacing: 7) {
            avatarOrb
            Text(label)
                .font(FitUpFont.mono(10, weight: .heavy))
                .tracking(0.45)
                .foregroundStyle(isSelected ? FitUpColors.Neon.orange : accent)
                .shadow(color: (isSelected ? FitUpColors.Neon.orange : accent).opacity(0.82), radius: 8, x: 0, y: 0)
                .shadow(color: (isSelected ? FitUpColors.Neon.orange : accent).opacity(0.38), radius: 16, x: 0, y: 0)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background { chipBackground }
    }

    private var avatarOrb: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(FitUpColors.Neon.orange.opacity(0.22))
                    .frame(width: 22, height: 22)
                    .shadow(color: FitUpColors.Neon.orange.opacity(0.72), radius: 10, x: 0, y: 0)
                Circle()
                    .strokeBorder(FitUpColors.Neon.orange, lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .shadow(color: FitUpColors.Neon.orange.opacity(0.85), radius: 8, x: 0, y: 0)
                Circle()
                    .fill(FitUpColors.Neon.green)
                    .frame(width: 12, height: 12)
                    .shadow(color: FitUpColors.Neon.green.opacity(0.75), radius: 6, x: 0, y: 0)
            } else {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 20, height: 20)
                Circle()
                    .strokeBorder(accent.opacity(0.88), lineWidth: 1.5)
                    .frame(width: 20, height: 20)
                    .shadow(color: accent.opacity(0.45), radius: 6, x: 0, y: 0)
            }

            Text(initials)
                .font(FitUpFont.mono(7, weight: .heavy))
                .foregroundStyle(isSelected ? Color.black.opacity(0.82) : Color.white.opacity(0.95))
        }
        .frame(width: 22, height: 22)
    }

    @ViewBuilder
    private var chipBackground: some View {
        let rim = isSelected ? FitUpColors.Neon.orange : accent
        Capsule(style: .continuous)
            .fill(Color.black.opacity(0.42))
            .overlay {
                Capsule(style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                rim.opacity(isSelected ? 0.34 : 0.28),
                                rim.opacity(isSelected ? 0.14 : 0.1),
                                Color.clear,
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 72
                        )
                    )
            }
            .overlay {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                rim.opacity(isSelected ? 0.12 : 0.08),
                                Color.clear,
                                Color.black.opacity(0.34),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(rim.opacity(isSelected ? 0.95 : 0.72), lineWidth: isSelected ? 1.8 : 1.2)
            }
            .shadow(color: rim.opacity(isSelected ? 0.62 : 0.34), radius: isSelected ? 12 : 8, x: 0, y: 0)
            .shadow(color: rim.opacity(isSelected ? 0.28 : 0.16), radius: isSelected ? 22 : 14, x: 0, y: 0)
    }
}

#if DEBUG
#Preview("Spread — 3 opponents") {
    let opponents: [HomeActiveMatch] = [
        HomeActiveMatch(
            id: UUID(),
            metricType: "steps",
            durationDays: 7,
            sportLabel: "Steps",
            seriesLabel: "7D",
            daysLeft: 4,
            finalDayCutoffAt: nil,
            finalDayScoreEndsAt: nil,
            myToday: 9000,
            theirToday: 8000,
            myScore: 2,
            theirScore: 1,
            isWinning: true,
            opponent: HomeOpponent(id: UUID(), displayName: "Mike", initials: "MI", colorHex: "#FF9500"),
            opponentTodayUpdatedAt: nil,
            dayPips: [],
            scoringMode: "balanced",
            difficulty: nil,
            myBaselineSteps: 8000,
            theirBaselineSteps: 7500
        ),
        HomeActiveMatch(
            id: UUID(),
            metricType: "steps",
            durationDays: 3,
            sportLabel: "Steps",
            seriesLabel: "3D",
            daysLeft: 2,
            finalDayCutoffAt: nil,
            finalDayScoreEndsAt: nil,
            myToday: 6000,
            theirToday: 7000,
            myScore: 0,
            theirScore: 1,
            isWinning: false,
            opponent: HomeOpponent(id: UUID(), displayName: "Jordan", initials: "JO", colorHex: "#BF5FFF"),
            opponentTodayUpdatedAt: nil,
            dayPips: [],
            scoringMode: nil,
            difficulty: nil,
            myBaselineSteps: nil,
            theirBaselineSteps: nil
        ),
        HomeActiveMatch(
            id: UUID(),
            metricType: "steps",
            durationDays: 1,
            sportLabel: "Steps",
            seriesLabel: "1D",
            daysLeft: 1,
            finalDayCutoffAt: nil,
            finalDayScoreEndsAt: nil,
            myToday: 4000,
            theirToday: 3900,
            myScore: 0,
            theirScore: 0,
            isWinning: true,
            opponent: HomeOpponent(id: UUID(), displayName: "Sam", initials: "SA", colorHex: "#39FF14"),
            opponentTodayUpdatedAt: nil,
            dayPips: [],
            scoringMode: "balanced",
            difficulty: nil,
            myBaselineSteps: 8000,
            theirBaselineSteps: 8000
        ),
    ]

    return VStack {
        HeroActiveOpponentPickerRow(
            matches: opponents,
            selectedMatchId: opponents[0].id,
            onSelect: { _ in }
        )
    }
    .padding()
    .background(FitUpColors.Bg.base)
}
#endif
