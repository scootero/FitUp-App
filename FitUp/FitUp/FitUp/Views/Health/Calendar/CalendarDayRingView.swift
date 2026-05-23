//
//  CalendarDayRingView.swift
//  FitUp
//
//  Small day indicators for the activity calendar (ghost ring, battle dot, step progress).
//

import SwiftUI

enum CalendarDayRingStyle: Equatable {
    case ghost
    case battle(CalendarDayBattleState)
    case steps(CalendarDayStepsState?)
}

struct CalendarDayRingView: View {
    let style: CalendarDayRingStyle
    var size: CGFloat = 26

    private var lineWidth: CGFloat { max(2, size * 0.12) }
    private var innerDiameter: CGFloat { size - lineWidth }

    var body: some View {
        switch style {
        case .ghost:
            ghostRing
        case .battle(let state):
            battleIndicator(state)
        case .steps(let state):
            stepsIndicator(state)
        }
    }

    private var ghostRing: some View {
        Circle()
            .stroke(Color.white.opacity(0.13), lineWidth: lineWidth)
            .frame(width: innerDiameter, height: innerDiameter)
    }

    @ViewBuilder
    private func battleIndicator(_ state: CalendarDayBattleState) -> some View {
        switch state {
        case .none:
            ghostRing
        case .wonAny:
            Circle()
                .fill(FitUpColors.Neon.green)
                .frame(width: innerDiameter * 0.72, height: innerDiameter * 0.72)
                .shadow(color: FitUpColors.Neon.green.opacity(0.45), radius: 4)
        case .lostAll:
            Circle()
                .fill(FitUpColors.Neon.red)
                .frame(width: innerDiameter * 0.72, height: innerDiameter * 0.72)
                .shadow(color: FitUpColors.Neon.red.opacity(0.4), radius: 4)
        case .inProgress:
            ZStack {
                ghostRing
                Circle()
                    .trim(from: 0, to: 0.55)
                    .stroke(
                        FitUpColors.Neon.orange,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: innerDiameter, height: innerDiameter)
                    .rotationEffect(.degrees(-90))
            }
        case .voidOnly:
            Circle()
                .fill(FitUpColors.Neon.yellow.opacity(0.55))
                .frame(width: innerDiameter * 0.38, height: innerDiameter * 0.38)
        }
    }

    @ViewBuilder
    private func stepsIndicator(_ state: CalendarDayStepsState?) -> some View {
        if let state, state.steps > 0 {
            let ringColor = state.goalMet ? FitUpColors.Neon.green : FitUpColors.Neon.cyan
            let progress = state.progress

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
                    .frame(width: innerDiameter, height: innerDiameter)

                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: innerDiameter, height: innerDiameter)
                    .rotationEffect(.degrees(-90))

                Text(state.abbreviatedStepsLabel)
                    .font(FitUpFont.mono(size * 0.28, weight: .bold))
                    .foregroundStyle(ringColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        } else {
            ghostRing
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        CalendarDayRingView(style: .ghost)
        CalendarDayRingView(style: .battle(.wonAny))
        CalendarDayRingView(style: .battle(.lostAll))
        CalendarDayRingView(style: .battle(.inProgress))
        CalendarDayRingView(style: .steps(CalendarDayStepsState(steps: 8420, stepsGoal: 12000)))
        CalendarDayRingView(style: .steps(CalendarDayStepsState(steps: 12500, stepsGoal: 12000)))
    }
    .padding()
    .background { FitUpColors.Bg.base }
}
