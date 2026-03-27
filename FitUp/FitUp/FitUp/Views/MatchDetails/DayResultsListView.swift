//
//  DayResultsListView.swift
//  FitUp
//
//  Slice 5 results list card for Match Details.
//

import SwiftUI

struct DayResultsListView: View {
    let dayRows: [MatchDetailsDayRow]
    let opponentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RESULTS")
                .font(FitUpFont.mono(11, weight: .bold))
                .foregroundStyle(FitUpColors.Text.secondary)
                .tracking(0.9)

            ForEach(Array(dayRows.enumerated()), id: \.element.id) { index, day in
                resultRow(day: day)
                    .padding(.vertical, 10)
                if index < dayRows.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard(.base)
    }

    private func resultRow(day: MatchDetailsDayRow) -> some View {
        let leftHighlighted = day.myWon == true || day.isTie
        let rightHighlighted = day.myWon == false
        let scoreColor = day.myWon == false ? opponentColor : FitUpColors.Neon.cyan

        return HStack(spacing: 10) {
            Text(day.dayLabel)
                .font(FitUpFont.body(12, weight: .medium))
                .foregroundStyle(FitUpColors.Text.tertiary)
                .frame(width: 28, alignment: .leading)

            GeometryReader { proxy in
                let leftWidth = max(proxy.size.width * (leftHighlighted ? 0.60 : 0.35), 10)
                let rightWidth = max(proxy.size.width - leftWidth - 4, 10)
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(leftHighlighted ? FitUpColors.Neon.cyan : Color.white.opacity(0.1))
                        .frame(width: leftWidth, height: 4)

                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(rightHighlighted ? opponentColor : Color.white.opacity(0.1))
                        .frame(width: rightWidth, height: 4)
                }
            }
            .frame(height: 4)

            Text(day.myValue.formatted())
                .font(FitUpFont.mono(10, weight: .bold))
                .foregroundStyle(scoreColor)
                .frame(width: 60, alignment: .trailing)
        }
    }
}
