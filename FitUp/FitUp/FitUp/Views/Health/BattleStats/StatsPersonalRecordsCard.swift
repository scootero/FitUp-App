//
//  StatsPersonalRecordsCard.swift
//  FitUp
//

import SwiftUI

struct StatsPersonalRecordsCard: View {
    let records: StatsPersonalRecords?
    let isLoading: Bool

    var body: some View {
        if isLoading {
            BattleStatsTheme.battleStatsCard {
                VStack(spacing: 8) {
                    BattleStatsTheme.sectionLabel("PERSONAL RECORDS")
                    ProgressView()
                        .tint(BattleStatsTheme.green)
                    Text("Loading records…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(BattleStatsTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        } else if let records, !records.isEmpty {
            BattleStatsTheme.battleStatsCard {
                VStack(alignment: .leading, spacing: 12) {
                    BattleStatsTheme.sectionLabel("PERSONAL RECORDS")

                    VStack(spacing: 10) {
                        ForEach(records.rows) { row in
                            recordRow(row)
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Personal records")
        }
    }

    private func recordRow(_ row: StatsPersonalRecordRow) -> some View {
        HStack(spacing: 12) {
            Text(row.icon)
                .font(.system(size: 22))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(BattleStatsTheme.textSecondary)
                Text(row.value)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(BattleStatsTheme.textPrimary)
            }

            Spacer(minLength: 8)

            if let subtitle = row.subtitle {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(BattleStatsTheme.textLabel)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.label), \(row.value)\(row.subtitle.map { ", \($0)" } ?? "")")
    }
}
