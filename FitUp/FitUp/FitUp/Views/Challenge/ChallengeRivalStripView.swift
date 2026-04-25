//
//  ChallengeRivalStripView.swift
//  FitUp
//
//  Horizontal “rival” mini-cards for the New Challenge flow: today steps/cals vs you.
//

import SwiftUI

struct ChallengeRivalStripView: View {
    let entries: [ChallengeRivalStripEntry]
    let mySteps: Int?
    let myActiveCalories: Int?
    let isLoading: Bool
    var onSelect: (ChallengeRivalStripEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TODAY / RIVALS")
                    .font(FitUpFont.mono(10, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.tertiary)
                Spacer(minLength: 0)
                if mySteps != nil || myActiveCalories != nil {
                    Text(trailingMeTag)
                        .font(FitUpFont.mono(9, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                }
            }
            if isLoading {
                ProgressView()
                    .tint(FitUpColors.Neon.cyan)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
            } else if entries.isEmpty {
                Text("No synced rivals for today yet.")
                    .font(FitUpFont.body(11, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(entries) { entry in
                            Button {
                                onSelect(entry)
                            } label: {
                                rivalCard(entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.trailing, 2)
                }
            }
        }
    }

    private var trailingMeTag: String {
        let s = mySteps.map { "\($0.formatted()) st" } ?? "— st"
        let c = myActiveCalories.map { " · \($0.formatted()) kcal" } ?? ""
        return "You \(s)\(c)"
    }

    @ViewBuilder
    private func rivalCard(_ entry: ChallengeRivalStripEntry) -> some View {
        let style = RivalCardStyle(comparison: entry.comparison)
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                .fill(style.fill)
                .overlay {
                    RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                        .strokeBorder(style.border, lineWidth: 1.1)
                }
                .shadow(color: style.glow, radius: style.glow == .clear ? 0 : 6, x: 0, y: 0)

            if style.scanLines {
                ScanLineStripes()
                    .clipShape(RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous))
                    .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    AvatarView(
                        initials: entry.initials,
                        color: color(from: entry.colorHex),
                        size: 32
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.displayName)
                            .font(FitUpFont.display(12, weight: .bold))
                            .foregroundStyle(FitUpColors.Text.primary)
                            .lineLimit(1)
                        Text(style.badgeLabel)
                            .font(FitUpFont.mono(8, weight: .bold))
                            .foregroundStyle(style.badgeText)
                    }
                }

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("STEPS")
                            .font(FitUpFont.mono(7, weight: .bold))
                            .foregroundStyle(FitUpColors.Text.tertiary)
                        Text(entry.steps.map { $0.formatted() } ?? "—")
                            .font(FitUpFont.mono(11, weight: .bold))
                            .foregroundStyle(FitUpColors.Text.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("KCAL")
                            .font(FitUpFont.mono(7, weight: .bold))
                            .foregroundStyle(FitUpColors.Text.tertiary)
                        Text(entry.activeCalories.map { $0.formatted() } ?? "—")
                            .font(FitUpFont.mono(11, weight: .bold))
                            .foregroundStyle(FitUpColors.Text.primary)
                    }
                }
            }
            .padding(10)
        }
        .frame(width: 150, height: 118, alignment: .topLeading)
    }

    private func color(from hex: String) -> Color {
        guard let value = UInt32(hex, radix: 16) else {
            return FitUpColors.Neon.blue
        }
        return Color(rgb: value)
    }
}

// MARK: - Styling

private struct RivalCardStyle {
    var fill: LinearGradient
    var border: Color
    var glow: Color
    var badgeLabel: String
    var badgeText: Color
    var scanLines: Bool

    init(comparison: ChallengeRivalComparison) {
        switch comparison {
        case .opponentAhead:
            // Positive: they’re leading you today.
            fill = LinearGradient(
                colors: [
                    FitUpColors.Neon.green.opacity(0.12),
                    FitUpColors.Neon.cyan.opacity(0.06),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            border = FitUpColors.Neon.green.opacity(0.5)
            glow = FitUpColors.Neon.green.opacity(0.45)
            badgeLabel = "AHEAD"
            badgeText = FitUpColors.Neon.green
            scanLines = false
        case .youAhead:
            // 70s arcade: you’re leading — they’re chasing.
            fill = LinearGradient(
                colors: [
                    FitUpColors.Neon.orange.opacity(0.14),
                    FitUpColors.Neon.pink.opacity(0.1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            border = FitUpColors.Neon.yellow.opacity(0.5)
            glow = FitUpColors.Neon.pink.opacity(0.4)
            badgeLabel = "CHASIN’"
            badgeText = FitUpColors.Neon.yellow
            scanLines = true
        case .tie:
            fill = LinearGradient(
                colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            border = Color.white.opacity(0.2)
            glow = .clear
            badgeLabel = "TIE"
            badgeText = FitUpColors.Text.secondary
            scanLines = false
        case .unknown:
            fill = LinearGradient(
                colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            border = Color.white.opacity(0.15)
            glow = .clear
            badgeLabel = "N/A"
            badgeText = FitUpColors.Text.tertiary
            scanLines = false
        }
    }
}

/// Very subtle horizontal “scan” accents for the retro chaser look.
private struct ScanLineStripes: View {
    var body: some View {
        GeometryReader { geo in
            let h = max(1, geo.size.height / 10)
            VStack(spacing: h) {
                ForEach(0..<10, id: \.self) { i in
                    Color.white
                        .opacity(i % 2 == 0 ? 0.04 : 0)
                        .frame(height: h * 0.45)
                }
            }
        }
    }
}

#Preview {
    ChallengeRivalStripView(
        entries: [
            ChallengeRivalStripEntry(
                userId: UUID(),
                displayName: "Alex Ray",
                initials: "AR",
                colorHex: "00AAFF",
                steps: 12040,
                activeCalories: 420,
                comparison: .opponentAhead
            ),
            ChallengeRivalStripEntry(
                userId: UUID(),
                displayName: "Bo Mix",
                initials: "BM",
                colorHex: "FF6200",
                steps: 8021,
                activeCalories: 310,
                comparison: .youAhead
            ),
        ],
        mySteps: 9000,
        myActiveCalories: 300,
        isLoading: false,
        onSelect: { _ in }
    )
    .padding()
    .background { BackgroundGradientView() }
}
