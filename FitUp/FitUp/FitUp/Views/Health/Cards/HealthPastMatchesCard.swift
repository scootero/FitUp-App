//
//  HealthPastMatchesCard.swift
//  FitUp
//
//  Collapsed/expandable completed matches card for Home.
//

import SwiftUI

struct HealthPastMatchesCard: View {
    let matches: [ActivityCompletedMatch]
    let isExpanded: Bool
    let isLoading: Bool
    var onToggleExpanded: () -> Void
    var onOpenMatch: (ActivityCompletedMatch) -> Void

    var body: some View {
        PastMatchesExpandableList(
            title: "Past Battles",
            matches: matches,
            isExpanded: isExpanded,
            isLoading: isLoading,
            style: .panel,
            accent: FitUpColors.Neon.purple,
            onToggle: onToggleExpanded,
            onOpenMatch: onOpenMatch
        )
    }
}
