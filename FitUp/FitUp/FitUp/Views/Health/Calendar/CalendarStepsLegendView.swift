//
//  CalendarStepsLegendView.swift
//  FitUp
//
//  Legend for Steps mode on the activity calendar.
//

import SwiftUI

struct CalendarStepsLegendView: View {
    var ringSize: CGFloat = 14

    private var lineWidth: CGFloat { max(1.5, ringSize * 0.14) }
    private var innerDiameter: CGFloat { ringSize - lineWidth }

    var body: some View {
        HStack(spacing: 14) {
            legendItem(
                ring: { goalHitRing },
                label: "Goal hit"
            )
            legendItem(
                ring: { progressRing },
                label: "In progress"
            )
            legendItem(
                ring: { restDayRing },
                label: "Rest day"
            )
            legendItem(
                ring: { emptyRing },
                label: "Today / pending"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendItem<Ring: View>(@ViewBuilder ring: () -> Ring, label: String) -> some View {
        HStack(spacing: 6) {
            ring()
                .frame(width: ringSize, height: ringSize)
            Text(label)
                .font(FitUpFont.body(10, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.tertiary)
        }
    }

    private var goalHitRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
                .frame(width: innerDiameter, height: innerDiameter)
            Circle()
                .trim(from: 0, to: 1)
                .stroke(
                    FitUpColors.Neon.blue,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: innerDiameter, height: innerDiameter)
                .rotationEffect(.degrees(-90))
        }
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
                .frame(width: innerDiameter, height: innerDiameter)
            Circle()
                .trim(from: 0, to: 0.55)
                .stroke(
                    FitUpColors.Neon.cyan,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: innerDiameter, height: innerDiameter)
                .rotationEffect(.degrees(-90))
        }
    }

    private var emptyRing: some View {
        Circle()
            .stroke(Color.white.opacity(0.13), lineWidth: lineWidth)
            .frame(width: innerDiameter, height: innerDiameter)
    }

    private var restDayRing: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: innerDiameter, height: innerDiameter)
                .overlay {
                    Circle()
                        .strokeBorder(Color.black.opacity(0.2), lineWidth: max(1, lineWidth * 0.85))
                }

            Image(systemName: "skull.fill")
                .font(.system(size: ringSize * 0.38, weight: .semibold))
                .foregroundStyle(Color.black)
        }
    }
}

#Preview {
    CalendarStepsLegendView()
        .padding()
        .background { FitUpColors.Bg.base }
}
