//
//  ActiveSection.swift
//  FitUp
//
//  Slice 3 active match cards section.
//

import SwiftUI

struct ActiveSection: View {
    let matches: [HomeActiveMatch]
    var onOpenMatch: (HomeActiveMatch) -> Void

    @State private var isExpanded = false

    private static let collapsedCount = 4

    private var displayedMatches: [HomeActiveMatch] {
        isExpanded ? matches : Array(matches.prefix(Self.collapsedCount))
    }

    private var hiddenCount: Int {
        max(0, matches.count - Self.collapsedCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if matches.isEmpty {
                SectionHeader(title: "Active Battles")
            } else {
                SectionHeader(title: "Active Battles", actionTitle: "\(matches.count) live", onAction: {})
            }

            if matches.isEmpty {
                Text("No active battles right now.")
                    .font(FitUpFont.body(13, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .glassCard(.base)
            } else {
                ForEach(Array(displayedMatches.enumerated()), id: \.element.id) { index, match in
                    MatchCardView(match: match, index: index) {
                        onOpenMatch(match)
                    }
                }

                if matches.count > Self.collapsedCount {
                    expandCollapseButton
                }
            }
        }
    }

    private var expandCollapseButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                Text(isExpanded ? "Show less" : "Show \(hiddenCount) more")
                    .font(FitUpFont.body(13, weight: .semibold))
            }
            .foregroundStyle(FitUpColors.Text.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .glassCard(.base)
        }
        .buttonStyle(.plain)
    }
}
