//
//  CompetitionEdgeTodaySection.swift
//  FitUp
//
//  “Competition Edge Today” — combined delta vs opponent; duplicate opponents merge (Health + Home).
//

import SwiftUI

struct CompetitionEdgeTodaySection: View {
    let matches: [HomeActiveMatch]
    /// When `true` (Health tab), use the same light retro panels as other health cards.
    var healthLightChrome: Bool = false

    /// One row per opponent + metric; multiple active battles vs the same person combine with summed today totals and a match count badge.
    private var displayRows: [CompetitionEdgeTodayRowData] {
        var seenMatchIds = Set<UUID>()
        let dedupedMatches = matches.filter { seenMatchIds.insert($0.id).inserted }

        var merged: [String: CompetitionEdgeTodayRowData] = [:]
        for m in dedupedMatches {
            let key = "\(m.opponent.id.uuidString)|\(m.metricType)"
            if var existing = merged[key] {
                existing.myToday += m.myToday
                existing.theirToday += m.theirToday
                existing.matchCount += 1
                merged[key] = existing
            } else {
                merged[key] = CompetitionEdgeTodayRowData(
                    id: key,
                    opponent: m.opponent,
                    metricType: m.metricType,
                    myToday: m.myToday,
                    theirToday: m.theirToday,
                    matchCount: 1
                )
            }
        }

        return merged.values.sorted { lhs, rhs in
            let lhsDelta = lhs.myToday - lhs.theirToday
            let rhsDelta = rhs.myToday - rhs.theirToday
            if lhsDelta != rhsDelta {
                return lhsDelta > rhsDelta
            }
            let lhsName = lhs.opponent.displayName.localizedLowercase
            let rhsName = rhs.opponent.displayName.localizedLowercase
            if lhsName != rhsName {
                return lhsName < rhsName
            }
            return lhs.id < rhs.id
        }
    }

    private var edgeRowsContent: some View {
        VStack(spacing: 8) {
            if displayRows.isEmpty {
                Text("No active battles right now.")
                    .font(FitUpFont.body(13, weight: .medium))
                    .foregroundStyle(
                        healthLightChrome ? FitUpColors.HealthOnLight.secondary : FitUpColors.Text.secondary
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            } else {
                ForEach(displayRows) { row in
                    CompetitionEdgeTodayRow(row: row, healthLightChrome: healthLightChrome)
                }
            }
        }
        .padding(14)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("COMPETITION EDGE TODAY")
                    .font(FitUpFont.body(13, weight: .heavy))
                    .fitUpGlobalTitleStyle(weight: .heavy, tracking: 2)
                Spacer()
            }
            .padding(.top, 4)
            .padding(.bottom, 8)

            Text("Per opponent, see who is ahead right now.")
                .font(FitUpFont.body(12, weight: .medium))
                .foregroundStyle(
                    healthLightChrome
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [FitUpColors.HealthOnLight.secondary, FitUpColors.Neon.cyan.opacity(0.75)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        : AnyShapeStyle(
                            LinearGradient(
                                colors: [FitUpColors.Text.secondary, FitUpColors.Neon.cyan.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .padding(.bottom, 10)

            Group {
                if healthLightChrome {
                    edgeRowsContent.healthGamifiedCard(.competitionEdge)
                } else {
                    edgeRowsContent.modifier(CompetitionEdgeSectionLiquidGlassModifier())
                }
            }
        }
    }
}

/// Lighter than `glassCard`: lets the home background show through with system blur (cheap on GPU).
private struct CompetitionEdgeSectionLiquidGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.045),
                                        Color.white.opacity(0.012),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.22),
                                        Color.white.opacity(0.08),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 8)
            }
    }
}

private struct CompetitionEdgeTodayRowData: Identifiable, Equatable {
    let id: String
    let opponent: HomeOpponent
    let metricType: String
    var myToday: Int
    var theirToday: Int
    var matchCount: Int
}

private struct CompetitionEdgeTodayRow: View {
    let row: CompetitionEdgeTodayRowData
    var healthLightChrome: Bool = false

    private var delta: Int { row.myToday - row.theirToday }
    private var isAhead: Bool { delta >= 0 }
    private var unitLabel: String { row.metricType == "steps" ? "steps" : "cal" }
    private var deltaLabel: String { "\(abs(delta)) \(unitLabel)" }
    private var totalsLabel: String {
        "You \(row.myToday.formatted()) · Them \(row.theirToday.formatted()) \(unitLabel)"
    }
    private var matchCountBadge: String? {
        guard row.matchCount > 1 else { return nil }
        return "×\(row.matchCount)"
    }
    private var opponentAccent: Color {
        let sanitized = row.opponent.colorHex.replacingOccurrences(of: "#", with: "")
        return ProfileAccentColor.swiftUIColor(hex: sanitized)
    }

    /// Single shadow + stroke keeps glow cheap vs. multi-layer blurs.
    private var edgeGlow: Color {
        if isAhead {
            return FitUpColors.Neon.green.opacity(0.55)
        }
        return FitUpColors.Neon.orange.opacity(0.65)
    }

    private var edgeGlowInner: Color {
        if isAhead {
            return FitUpColors.Neon.cyan.opacity(0.35)
        }
        return FitUpColors.Neon.red.opacity(0.28)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(row.opponent.displayName)
                    .font(FitUpFont.display(20, weight: .heavy))
                    .foregroundStyle(opponentAccent)
                    .shadow(color: opponentAccent.opacity(isAhead ? 0.45 : 0.35), radius: 6, x: 0, y: 0)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                if let matchCountBadge {
                    Text(matchCountBadge)
                        .font(FitUpFont.body(11, weight: .heavy))
                        .foregroundStyle(
                            healthLightChrome ? FitUpColors.HealthOnLight.tertiary : FitUpColors.Text.tertiary
                        )
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background {
                            Capsule()
                                .fill(
                                    healthLightChrome ? Color.black.opacity(0.06) : Color.white.opacity(0.07)
                                )
                                .overlay {
                                    Capsule()
                                        .strokeBorder(
                                            healthLightChrome ? Color.black.opacity(0.10) : Color.white.opacity(0.12),
                                            lineWidth: 1
                                        )
                                }
                        }
                        .accessibilityLabel("\(row.matchCount) matches")
                }

                Spacer(minLength: 6)

                HStack(spacing: 4) {
                    Image(systemName: isAhead ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isAhead ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange)
                    Text("\(isAhead ? "+" : "-")\(deltaLabel)")
                        .font(FitUpFont.display(13, weight: .bold))
                        .foregroundStyle(isAhead ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange)
                }
                .layoutPriority(1)
            }

            Text(totalsLabel)
                .font(FitUpFont.body(11, weight: .medium))
                .foregroundStyle(
                    healthLightChrome ? FitUpColors.HealthOnLight.tertiary : FitUpColors.Text.tertiary
                )
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                .fill(healthLightChrome ? Color.black.opacity(0.05) : Color.white.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [edgeGlow, edgeGlowInner],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.25
                        )
                }
                .shadow(color: edgeGlow.opacity(0.85), radius: 10, x: 0, y: 0)
        }
    }
}

#Preview {
    let alexOpponent = HomeOpponent(id: UUID(), displayName: "Alex", initials: "A", colorHex: "#00FFFF")
    return CompetitionEdgeTodaySection(
        matches: [
            HomeActiveMatch(
                id: UUID(),
                metricType: "steps",
                durationDays: 7,
                sportLabel: "Steps",
                seriesLabel: "Series",
                daysLeft: 3,
                finalDayCutoffAt: nil,
                finalDayScoreEndsAt: nil,
                myToday: 8200,
                theirToday: 7500,
                myScore: 1,
                theirScore: 0,
                isWinning: true,
                opponent: alexOpponent,
                opponentTodayUpdatedAt: nil,
                dayPips: []
            ),
            HomeActiveMatch(
                id: UUID(),
                metricType: "steps",
                durationDays: 7,
                sportLabel: "Steps",
                seriesLabel: "Series",
                daysLeft: 3,
                finalDayCutoffAt: nil,
                finalDayScoreEndsAt: nil,
                myToday: 3100,
                theirToday: 2900,
                myScore: 0,
                theirScore: 1,
                isWinning: false,
                opponent: alexOpponent,
                opponentTodayUpdatedAt: nil,
                dayPips: []
            ),
            HomeActiveMatch(
                id: UUID(),
                metricType: "active_calories",
                durationDays: 7,
                sportLabel: "Calories",
                seriesLabel: "Series",
                daysLeft: 2,
                finalDayCutoffAt: nil,
                finalDayScoreEndsAt: nil,
                myToday: 610,
                theirToday: 780,
                myScore: 3,
                theirScore: 2,
                isWinning: true,
                opponent: HomeOpponent(id: UUID(), displayName: "Jordan", initials: "J", colorHex: "FF6200"),
                opponentTodayUpdatedAt: nil,
                dayPips: []
            ),
            HomeActiveMatch(
                id: UUID(),
                metricType: "steps",
                durationDays: 7,
                sportLabel: "Steps",
                seriesLabel: "Series",
                daysLeft: 4,
                finalDayCutoffAt: nil,
                finalDayScoreEndsAt: nil,
                myToday: 6400,
                theirToday: 5200,
                myScore: 1,
                theirScore: 1,
                isWinning: false,
                opponent: HomeOpponent(id: UUID(), displayName: "Taylor", initials: "T", colorHex: "39FF14"),
                opponentTodayUpdatedAt: nil,
                dayPips: []
            ),
        ]
    )
    .padding()
    .background { BackgroundGradientView() }
}
