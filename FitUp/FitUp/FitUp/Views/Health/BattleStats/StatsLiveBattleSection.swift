//
//  StatsLiveBattleSection.swift
//  FitUp
//
//  Live battle card with home-style side chevrons when multiple battles are active.
//

import SwiftUI

enum StatsLiveBattleSelection {
    static let chevronGutterWidth: CGFloat = 22

    static func sortedEligibleStepMatches(from matches: [HomeActiveMatch]) -> [HomeActiveMatch] {
        let eligible = matches.filter {
            $0.metricType == "steps" && $0.isStepsBattleForHomeUX && !$0.isEffectivelyOverForHomeUX
        }
        return eligible.sorted(by: statsCarouselSort)
    }

    static func featuredStepMatch(from matches: [HomeActiveMatch]) -> HomeActiveMatch? {
        HomeActiveMatch.featuredStepMatch(from: sortedEligibleStepMatches(from: matches))
    }

    static func resolvedMatch(
        from matches: [HomeActiveMatch],
        selectedId: UUID?
    ) -> HomeActiveMatch? {
        let sorted = sortedEligibleStepMatches(from: matches)
        guard !sorted.isEmpty else { return nil }
        if let selectedId, let selected = sorted.first(where: { $0.id == selectedId }) {
            return selected
        }
        return HomeActiveMatch.featuredStepMatch(from: sorted) ?? sorted.first
    }

    static func canSelectPrevious(selectedId: UUID?, matches: [HomeActiveMatch]) -> Bool {
        guard let index = selectedIndex(selectedId: selectedId, matches: matches) else { return false }
        return index > 0
    }

    static func canSelectNext(selectedId: UUID?, matches: [HomeActiveMatch]) -> Bool {
        let sorted = sortedEligibleStepMatches(from: matches)
        guard let index = selectedIndex(selectedId: selectedId, matches: matches) else { return false }
        return index < sorted.count - 1
    }

    static func adjacentMatch(
        from matches: [HomeActiveMatch],
        selectedId: UUID?,
        offset: Int
    ) -> HomeActiveMatch? {
        let sorted = sortedEligibleStepMatches(from: matches)
        guard sorted.count > 1,
              let currentId = resolvedMatch(from: matches, selectedId: selectedId)?.id,
              let index = sorted.firstIndex(where: { $0.id == currentId })
        else { return nil }
        let nextIndex = index + offset
        guard sorted.indices.contains(nextIndex) else { return nil }
        return sorted[nextIndex]
    }

    private static func selectedIndex(selectedId: UUID?, matches: [HomeActiveMatch]) -> Int? {
        let sorted = sortedEligibleStepMatches(from: matches)
        guard let current = resolvedMatch(from: matches, selectedId: selectedId) else { return nil }
        return sorted.firstIndex(where: { $0.id == current.id })
    }

    /// Mirrors home hero ordering: closest deficits first, then closest leads.
    private static func statsCarouselSort(_ lhs: HomeActiveMatch, _ rhs: HomeActiveMatch) -> Bool {
        let lhsMargin = lhs.matchScoreMargin
        let rhsMargin = rhs.matchScoreMargin

        let lhsLosing = lhsMargin < 0
        let rhsLosing = rhsMargin < 0
        if lhsLosing != rhsLosing { return lhsLosing }

        if lhsMargin != rhsMargin {
            if lhsMargin < 0 && rhsMargin < 0 { return lhsMargin > rhsMargin }
            if lhsMargin > 0 && rhsMargin > 0 { return lhsMargin < rhsMargin }
        }

        let lhsName = lhs.opponent.displayName.localizedLowercase
        let rhsName = rhs.opponent.displayName.localizedLowercase
        if lhsName != rhsName { return lhsName < rhsName }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

struct StatsLiveBattleSection: View {
    let matches: [HomeActiveMatch]
    @Binding var selectedMatchId: UUID?
    var onOpenMatchDetails: (HomeActiveMatch) -> Void

    private var sortedMatches: [HomeActiveMatch] {
        StatsLiveBattleSelection.sortedEligibleStepMatches(from: matches)
    }

    private var displayedMatch: HomeActiveMatch? {
        StatsLiveBattleSelection.resolvedMatch(from: matches, selectedId: selectedMatchId)
    }

    private var showsNavigation: Bool {
        sortedMatches.count > 1
    }

    var body: some View {
        if let match = displayedMatch {
            HStack(alignment: .center, spacing: 0) {
                navigationSlot(
                    showsGutter: showsNavigation,
                    visible: StatsLiveBattleSelection.canSelectPrevious(
                        selectedId: selectedMatchId,
                        matches: matches
                    ),
                    systemName: "chevron.left",
                    accessibilityLabel: "Previous battle"
                ) {
                    if let previous = StatsLiveBattleSelection.adjacentMatch(
                        from: matches,
                        selectedId: selectedMatchId,
                        offset: -1
                    ) {
                        selectedMatchId = previous.id
                    }
                }

                StatsLiveBattleCard(match: match) {
                    onOpenMatchDetails(match)
                }
                .frame(maxWidth: .infinity)

                navigationSlot(
                    showsGutter: showsNavigation,
                    visible: StatsLiveBattleSelection.canSelectNext(
                        selectedId: selectedMatchId,
                        matches: matches
                    ),
                    systemName: "chevron.right",
                    accessibilityLabel: "Next battle"
                ) {
                    if let next = StatsLiveBattleSelection.adjacentMatch(
                        from: matches,
                        selectedId: selectedMatchId,
                        offset: 1
                    ) {
                        selectedMatchId = next.id
                    }
                }
            }
            .onChange(of: matches.map(\.id)) { _, _ in
                reconcileSelection()
            }
            .onAppear {
                reconcileSelection()
            }
        }
    }

    private func reconcileSelection() {
        guard !sortedMatches.isEmpty else {
            selectedMatchId = nil
            return
        }
        if let selectedMatchId,
           sortedMatches.contains(where: { $0.id == selectedMatchId }) {
            return
        }
        selectedMatchId = StatsLiveBattleSelection.featuredStepMatch(from: matches)?.id
    }

    @ViewBuilder
    private func navigationSlot(
        showsGutter: Bool,
        visible: Bool,
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        ZStack {
            if visible {
                Button(action: action) {
                    Image(systemName: systemName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.black.opacity(0.38)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel)
            }
        }
        .frame(width: showsGutter ? StatsLiveBattleSelection.chevronGutterWidth : 0)
        .accessibilityHidden(!visible)
    }
}
