//
//  ActiveSection.swift
//  FitUp
//
//  Slice 3 active match cards section.
//

import SwiftUI

struct ActiveSection: View {
    let matches: [HomeActiveMatch]
    let primaryStepMatchID: UUID?
    var onOpenMatch: (HomeActiveMatch) -> Void

    private struct OtherBattleRowModel: Identifiable {
        let id: String
        let title: String
        let deltaText: String
        let contextText: String?
        let representativeMatch: HomeActiveMatch
    }

    private var candidateMatches: [HomeActiveMatch] {
        guard let primaryStepMatchID else { return matches }
        return matches.filter { $0.id != primaryStepMatchID }
    }

    private var groupedRows: [OtherBattleRowModel] {
        var grouped: [String: [HomeActiveMatch]] = [:]
        for match in candidateMatches {
            let key = "\(match.opponent.id.uuidString)|\(match.metricType)"
            grouped[key, default: []].append(match)
        }

        return grouped.values.compactMap { group in
            let sorted = group.sorted { lhs, rhs in lhs.id.uuidString < rhs.id.uuidString }
            guard let representative = sorted.first else { return nil }
            let count = sorted.count
            let title = count > 1
                ? "\(representative.opponent.displayName) (\(count) battles)"
                : representative.opponent.displayName

            let myTodayTotal = sorted.reduce(0) { $0 + $1.myToday }
            let theirTodayTotal = sorted.reduce(0) { $0 + $1.theirToday }
            let delta = myTodayTotal - theirTodayTotal
            let deltaText: String
            if delta == 0 {
                deltaText = "Tied"
            } else {
                deltaText = "\(delta > 0 ? "+" : "-")\(abs(delta).formatted())"
            }

            let dayNumber = currentDayNumber(for: representative)
            let dayText = MatchDurationCopy.dayProgress(current: dayNumber, total: representative.durationDays)
            let scoreText = "Match score: \(representative.myScore)–\(representative.theirScore)"
            let contextText = "\(dayText) · \(scoreText)"

            return OtherBattleRowModel(
                id: "\(representative.id.uuidString)|\(representative.metricType)",
                title: title,
                deltaText: deltaText,
                contextText: contextText,
                representativeMatch: representative
            )
        }
        .sorted { lhs, rhs in
            let lhsAbs = abs(rawDelta(from: lhs.deltaText))
            let rhsAbs = abs(rawDelta(from: rhs.deltaText))
            if lhsAbs != rhsAbs { return lhsAbs > rhsAbs }
            if lhs.title != rhs.title {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.id < rhs.id
        }
    }

    var body: some View {
        if !groupedRows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Other Battles")
                ForEach(groupedRows) { row in
                    compactRow(row)
                }
            }
        }
    }

    private func compactRow(_ row: OtherBattleRowModel) -> some View {
        Button {
            // TODO: Use explicit recency ordering when match created-at is available for grouped rows.
            onOpenMatch(row.representativeMatch)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    AvatarView(
                        initials: row.representativeMatch.opponent.initials,
                        color: ProfileAccentColor.swiftUIColor(hex: row.representativeMatch.opponent.colorHex),
                        size: 26
                    )
                    Text(row.title)
                        .font(FitUpFont.body(14, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.primary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(row.deltaText)
                        .font(FitUpFont.display(20, weight: .black))
                        .foregroundStyle(deltaColor(for: row))
                        .lineLimit(1)
                }

                if let contextText = row.contextText {
                    Text(contextText)
                        .font(FitUpFont.body(11, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .homeLiquidGlassCard(.base)
        }
        .buttonStyle(.plain)
    }

    private func deltaColor(for row: OtherBattleRowModel) -> Color {
        if row.deltaText == "Tied" { return FitUpColors.Text.secondary }
        return row.deltaText.hasPrefix("+") ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange
    }

    private func rawDelta(from formatted: String) -> Int {
        if formatted == "Tied" { return 0 }
        return Int(formatted.replacingOccurrences(of: "+", with: "")) ?? 0
    }

    private func currentDayNumber(for match: HomeActiveMatch) -> Int {
        if let todayPip = match.dayPips.first(where: { $0.state == .today }) {
            return todayPip.dayNumber
        }
        // Home rows only have lightweight day metadata and can be less precise than match-details merged rows.
        let inferred = max(1, match.durationDays - match.daysLeft + 1)
        return min(inferred, max(1, match.durationDays))
    }
}
