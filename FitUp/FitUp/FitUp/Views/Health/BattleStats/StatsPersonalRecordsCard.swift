//
//  StatsPersonalRecordsCard.swift
//  FitUp
//

import SwiftUI

struct StatsPersonalRecordsCard: View {
    let records: StatsPersonalRecords?
    let isLoading: Bool
    var onShowCombinedMetricExplainer: ([StatsMetricExplainerKind]) -> Void = { _ in }

    var body: some View {
        if isLoading {
            BattleStatsTheme.battleStatsCard(accent: .warm) {
                VStack(spacing: 8) {
                    personalRecordsHeader
                    ProgressView()
                        .tint(BattleStatsTheme.green)
                    Text("Loading records…")
                        .battleStatsStyle(.secondary, size: BattleStatsTheme.Typography.bodySmall, accent: .warm)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        } else if let records, !records.isEmpty {
            BattleStatsTheme.battleStatsCard(accent: .warm) {
                VStack(alignment: .leading, spacing: 12) {
                    personalRecordsHeader
                        .padding(.trailing, 32)

                    VStack(spacing: 10) {
                        ForEach(records.rows) { row in
                            recordRow(row)
                        }
                    }
                }
            }
            .statsCardCombinedMetricInfoCorner(
                kinds: explainerKinds(for: records),
                accent: .warm,
                onShow: onShowCombinedMetricExplainer
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Personal records")
        }
    }

    private func explainerKinds(for records: StatsPersonalRecords) -> [StatsMetricExplainerKind] {
        records.rows.compactMap { StatsMetricExplainerKind.personalRecordKind(forRowId: $0.id) }
    }

    private var personalRecordsHeader: some View {
        BattleStatsTheme.sectionLabel("PERSONAL RECORDS", accent: .warm)
    }

    private func recordRow(_ row: StatsPersonalRecordRow) -> some View {
        HStack(spacing: 12) {
            Text(row.icon)
                .font(.system(size: 26))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.label)
                    .battleStatsStyle(.secondary, size: BattleStatsTheme.Typography.caption, accent: .warm)
                Text(row.value)
                    .battleStatsStyle(.primary, size: 18, weight: .bold, design: .monospaced, accent: .warm)
            }

            Spacer(minLength: 8)

            if let subtitle = row.subtitle {
                Text(subtitle)
                    .battleStatsStyle(.label, size: BattleStatsTheme.Typography.caption, accent: .warm)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BattleStatsTheme.gold.opacity(0.14),
                            BattleStatsTheme.orange.opacity(0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.label), \(row.value)\(row.subtitle.map { ", \($0)" } ?? "")")
    }
}
