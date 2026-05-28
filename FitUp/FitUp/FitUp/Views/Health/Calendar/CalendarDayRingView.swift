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

    private var lineWidth: CGFloat { max(1.5, size * 0.1) }
    private var innerDiameter: CGFloat { size - lineWidth }

    private var stepLabelFontScale: CGFloat {
        layout == .expanded ? 0.28 : 0.26
    }

    private var stepsGoalRingColor: Color { FitUpColors.Neon.blue }
    private var stepsProgressRingColor: Color { FitUpColors.Neon.cyan }

    private var battleDotScale: CGFloat {
        layout == .expanded ? 0.82 : 0.72
    }

    private var battleLabelFontScale: CGFloat {
        layout == .expanded ? 0.38 : 0.34
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

    private var emptyBattlePlaceholder: some View {
        Color.clear
            .frame(width: size, height: size)
    }

    @ViewBuilder
    private func battleIndicator(_ state: CalendarDayBattleState) -> some View {
        switch state {
        case .none:
            emptyBattlePlaceholder
        case .wonAny:
            battleOutcomeCircle(
                fill: FitUpColors.Neon.green,
                shadowColor: FitUpColors.Neon.green.opacity(0.45),
                label: "W",
                labelColor: Color.black.opacity(0.88)
            )
        case .lostAll:
            battleOutcomeCircle(
                fill: FitUpColors.Neon.red,
                shadowColor: FitUpColors.Neon.red.opacity(0.4),
                label: "L",
                labelColor: Color.white.opacity(0.95)
            )
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

    private func battleOutcomeCircle(
        fill: Color,
        shadowColor: Color,
        label: String,
        labelColor: Color
    ) -> some View {
        ZStack {
            Circle()
                .fill(fill)
                .frame(width: innerDiameter * battleDotScale, height: innerDiameter * battleDotScale)
                .shadow(color: shadowColor, radius: layout == .expanded ? 4 : 3)

            Text(label)
                .font(FitUpFont.mono(size * battleLabelFontScale, weight: .black))
                .foregroundStyle(labelColor)
        }
    }

    @ViewBuilder
    private func stepsIndicator(_ state: CalendarDayStepsState?) -> some View {
        if let state, state.steps > 0 {
            let progress = state.goalMet ? 1.0 : state.progress
            let ringColor = state.goalMet ? stepsGoalRingColor : stepsProgressRingColor
            let label = state.calendarRingStepsLabel

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
                    .shadow(
                        color: state.goalMet ? ringColor.opacity(0.4) : .clear,
                        radius: state.goalMet ? (layout == .expanded ? 4 : 3) : 0
                    )

                Text(label)
                    .font(FitUpFont.mono(size * stepLabelFontScale, weight: state.goalMet ? .black : .bold))
                    .foregroundStyle(state.goalMet ? Color.white.opacity(0.92) : ringColor)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .padding(.horizontal, size * 0.12)
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
