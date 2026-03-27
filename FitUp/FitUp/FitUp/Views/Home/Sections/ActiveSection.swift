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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Active Matches", actionTitle: "\(matches.count) live")

            ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                MatchCardView(match: match, index: index) {
                    onOpenMatch(match)
                }
            }
        }
    }
}
