//
//  StatsArcadeAllRivalsSheet.swift
//  FitUp
//
//  Simple sheet listing already-loaded rival stats (no fetch, search, or sort UI).
//

import SwiftUI

struct StatsArcadeAllRivalsSheet: View {
    let rivals: [HomeRivalStat]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if rivals.isEmpty {
                    Text("Rival stats will appear after you complete more battles.")
                        .font(FitUpFont.body(14, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(24)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(rivals.enumerated()), id: \.element.id) { index, rival in
                                row(rank: index + 1, rival: rival)
                                if rival.id != rivals.last?.id {
                                    Divider()
                                        .overlay(Color.white.opacity(0.12))
                                        .padding(.leading, 52)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
            .background { BackgroundGradientView() }
            .navigationTitle("All Rivals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(rank: Int, rival: HomeRivalStat) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(FitUpColors.Text.tertiary)
                .frame(width: 22, alignment: .trailing)

            ZStack {
                Circle()
                    .fill(ProfileAccentColor.color(for: rival.opponentProfileId).opacity(0.22))
                Text(String(rival.opponentInitials.prefix(2)).uppercased())
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(ProfileAccentColor.color(for: rival.opponentProfileId))
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(rival.opponentDisplayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(rival.finalizedDaysCompeted) battle days · \(seriesRecord(rival))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
            }

            Spacer(minLength: 8)

            Text("\(rival.winPercentage)%")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(rival.matchWins >= rival.matchLosses ? FitUpColors.Neon.green : FitUpColors.Neon.orange)
        }
        .padding(.vertical, 12)
    }

    private func seriesRecord(_ rival: HomeRivalStat) -> String {
        if rival.matchTies > 0 {
            return "\(rival.matchWins)–\(rival.matchLosses)–\(rival.matchTies)"
        }
        return "\(rival.matchWins)–\(rival.matchLosses)"
    }
}
