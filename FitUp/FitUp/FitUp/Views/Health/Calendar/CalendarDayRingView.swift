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
    var layout: ActivityCalendarLayout = .compact

    private var lineWidth: CGFloat { max(2, size * 0.12) }
    private var innerDiameter: CGFloat { size - lineWidth }

    private var stepLabelFontScale: CGFloat {
        layout == .expanded ? 0.46 : 0.28
    }

    private var battleDotScale: CGFloat {
        layout == .expanded ? 0.88 : 0.72
    }

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
                .frame(width: innerDiameter * battleDotScale, height: innerDiameter * battleDotScale)
                .shadow(color: FitUpColors.Neon.green.opacity(0.45), radius: layout == .expanded ? 6 : 4)
        case .lostAll:
            Circle()
                .fill(FitUpColors.Neon.red)
                .frame(width: innerDiameter * battleDotScale, height: innerDiameter * battleDotScale)
                .shadow(color: FitUpColors.Neon.red.opacity(0.4), radius: layout == .expanded ? 6 : 4)
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

            if state.goalMet {
                ZStack {
                    Circle()
                        .fill(ringColor)
                        .frame(width: innerDiameter * 0.92, height: innerDiameter * 0.92)
                        .shadow(color: ringColor.opacity(0.45), radius: layout == .expanded ? 6 : 4)

                    Text(state.abbreviatedStepsLabel)
                        .font(FitUpFont.mono(size * stepLabelFontScale, weight: .black))
                        .foregroundStyle(Color.black.opacity(0.88))
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                }
            } else {
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
                        .font(FitUpFont.mono(size * stepLabelFontScale, weight: .bold))
                        .foregroundStyle(ringColor)
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                }
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
