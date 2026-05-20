//
//  HealthPastMatchesCard.swift
//  FitUp
//
//  Collapsed/expandable completed matches card for Health.
//

import SwiftUI

struct HealthPastMatchesCard: View {
    let matches: [ActivityCompletedMatch]
    let isExpanded: Bool
    let isLoading: Bool
    var onToggleExpanded: () -> Void
    var onOpenMatch: (ActivityCompletedMatch) -> Void

    @State private var isListExpanded = false

    private static let collapsedCount = 4

    private var displayedMatches: [ActivityCompletedMatch] {
        isListExpanded ? matches : Array(matches.prefix(Self.collapsedCount))
    }

    private var hiddenCount: Int {
        max(0, matches.count - Self.collapsedCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        isListExpanded = false
                    }
                    onToggleExpanded()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("PAST BATTLES")
                        .font(FitUpFont.body(11, weight: .heavy))
                        .fitUpGlobalTitleStyle(weight: .heavy, tracking: 2)

                    Spacer(minLength: 0)

                    if !isLoading, !matches.isEmpty {
                        Text("\(matches.count)")
                            .font(FitUpFont.body(11, weight: .semibold))
                            .foregroundStyle(FitUpColors.Text.secondary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .homeLiquidGlassCard(.base)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Past battles")
            .accessibilityValue(
                isLoading
                    ? "Loading"
                    : (matches.isEmpty ? "No completed battles" : "\(matches.count) completed")
            )
            .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand past battles")

            if isExpanded {
                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(FitUpColors.Neon.cyan)
                        Text("Loading completed battles...")
                            .font(FitUpFont.body(13, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .homeLiquidGlassCard(.base)
                } else if matches.isEmpty {
                    Text("No completed battles yet.")
                        .font(FitUpFont.body(13, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .homeLiquidGlassCard(.base)
                } else {
                    ForEach(displayedMatches) { match in
                        PastMatchRow(match: match) {
                            onOpenMatch(match)
                        }
                    }

                    if matches.count > Self.collapsedCount {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isListExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isListExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .bold))
                                Text(isListExpanded ? "Show less" : "Show \(hiddenCount) more")
                                    .font(FitUpFont.body(13, weight: .semibold))
                            }
                            .foregroundStyle(FitUpColors.Text.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .homeLiquidGlassCard(.base)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
