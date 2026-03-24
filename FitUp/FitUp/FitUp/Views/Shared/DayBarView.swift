//
//  DayBarView.swift
//  FitUp
//
//  Maps JSX `DayBar` — dual bars, day label, pip for finalized / today.
//

import SwiftUI

struct DayBarView: View {
    let day: String
    let myVal: Int
    let theirVal: Int
    let myWon: Bool
    let finalized: Bool
    let isToday: Bool

    private let chartHeight: CGFloat = 80
    private let barWidth: CGFloat = 12

    var body: some View {
        let maxVal = max(myVal, theirVal, 1)
        let myH = CGFloat(myVal) / CGFloat(maxVal) * chartHeight
        let thH = CGFloat(theirVal) / CGFloat(maxVal) * chartHeight

        VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 3) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(myBarFill(myWon: myWon, finalized: finalized))
                    .frame(width: barWidth, height: max(2, myH))

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(theirBarFill(myWon: myWon, finalized: finalized))
                    .frame(width: barWidth, height: max(2, thH))
            }
            .frame(height: chartHeight, alignment: .bottom)

            Text(day)
                .font(FitUpFont.mono(10, weight: .medium))
                .foregroundStyle(isToday ? FitUpColors.Neon.cyan : FitUpColors.Text.tertiary)

            if finalized {
                Circle()
                    .fill(myWon ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange)
                    .frame(width: 6, height: 6)
            } else if isToday {
                Circle()
                    .fill(FitUpColors.Neon.blue)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func myBarFill(myWon: Bool, finalized: Bool) -> Color {
        if finalized {
            return myWon ? FitUpColors.Neon.cyan : Color.white.opacity(0.15)
        }
        return Color(red: 0, green: 1, blue: 0.878, opacity: 0.5)
    }

    private func theirBarFill(myWon: Bool, finalized: Bool) -> Color {
        if finalized {
            return myWon ? Color.white.opacity(0.12) : FitUpColors.Neon.orange
        }
        return Color(red: 1, green: 0.384, blue: 0, opacity: 0.45)
    }
}

#Preview {
    HStack(alignment: .bottom) {
        DayBarView(day: "M", myVal: 12400, theirVal: 9800, myWon: true, finalized: true, isToday: false)
        DayBarView(day: "F", myVal: 11240, theirVal: 8980, myWon: false, finalized: false, isToday: true)
    }
    .padding()
    .background { BackgroundGradientView() }
}
