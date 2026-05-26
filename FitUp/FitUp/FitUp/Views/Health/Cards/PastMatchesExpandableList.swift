//
//  PastMatchesExpandableList.swift
//  FitUp
//
//  Shared expandable completed-matches list (Home panel + Stats opponent cards).
//

import SwiftUI

enum PastMatchesExpandableStyle {
    case panel
    case embedded
}

struct PastMatchesExpandableList: View {
    let title: String
    let matches: [ActivityCompletedMatch]
    let isExpanded: Bool
    let isLoading: Bool
    let style: PastMatchesExpandableStyle
    let accent: Color
    var emptyMessage: String = "No completed battles yet."
    var onToggle: () -> Void
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
        Group {
            switch style {
            case .panel:
                panelBody
            case .embedded:
                embeddedBody
            }
        }
    }

    private var panelBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: isExpanded ? 10 : 0) {
                headerButton(useNeonTitle: true)
                if isExpanded {
                    expandedContent
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .neonRivalryPanel()
        }
    }

    private var embeddedBody: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 8 : 0) {
            headerButton(useNeonTitle: false)
            if isExpanded {
                expandedContent
            }
        }
        .padding(.top, 4)
    }

    private func headerButton(useNeonTitle: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isExpanded {
                    isListExpanded = false
                }
                onToggle()
            }
        } label: {
            HStack(spacing: 8) {
                if useNeonTitle {
                    NeonPanelTitle(
                        title: title,
                        style: .compact,
                        accent: accent
                    )
                } else {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.white.opacity(0.82))
                }

                Spacer(minLength: 0)

                if !isLoading, !matches.isEmpty {
                    Text("\(matches.count)")
                        .font(FitUpFont.mono(11, weight: .bold))
                        .foregroundStyle(accent.opacity(0.92))
                }

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(HomePageStyle.muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(
            isLoading
                ? "Loading"
                : (matches.isEmpty ? "No completed battles" : "\(matches.count) completed")
        )
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")
    }

    @ViewBuilder
    private var expandedContent: some View {
        if isLoading {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(FitUpColors.Neon.cyan)
                Text("Loading completed battles...")
                    .font(FitUpFont.body(14, weight: .medium))
                    .foregroundStyle(HomePageStyle.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .neonRowInsetPlate(accent: accent)
        } else if matches.isEmpty {
            Text(emptyMessage)
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(HomePageStyle.muted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .neonRowInsetPlate(accent: accent)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(displayedMatches.enumerated()), id: \.element.id) { index, match in
                    if index > 0 {
                        NeonRowSeparator()
                    }

                    PastMatchRow(match: match, rowIndex: index) {
                        onOpenMatch(match)
                    }
                }

                if matches.count > Self.collapsedCount {
                    NeonRowSeparator()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isListExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isListExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                            Text(isListExpanded ? "Show less" : "Show \(hiddenCount) more")
                                .font(FitUpFont.mono(11, weight: .bold))
                                .tracking(0.4)
                        }
                        .foregroundStyle(HomePageStyle.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .neonRowInsetPlate(accent: FitUpColors.Neon.blue.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
