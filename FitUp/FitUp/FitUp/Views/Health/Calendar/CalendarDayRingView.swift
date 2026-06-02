//
//  CalendarDayRingView.swift
//  FitUp
//
//  Small day indicators for the activity calendar (ghost ring, battle dot, step progress).
//

import SwiftUI

enum CalendarDayRingStyle: Equatable {
    case ghost
    case battle(state: CalendarDayBattleState, margin: Int?)
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

    var body: some View {
        switch style {
        case .ghost:
            ghostRing
        case .battle(let state, let margin):
            battleIndicator(state, margin: margin)
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
    private func battleIndicator(_ state: CalendarDayBattleState, margin: Int?) -> some View {
        if state != .none,
           let resolved = CalendarBattleMarginTone.resolvedMargin(state: state, marginByDate: margin) {
            let fill = CalendarBattleMarginTone.fillColor(margin: resolved)
            let glow = CalendarBattleMarginTone.glowColor(margin: resolved)
            let chipHeight = innerDiameter * (layout == .expanded ? 0.42 : 0.38)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(fill)
                .frame(width: innerDiameter * 0.92, height: chipHeight)
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.6)
                }
                .shadow(color: glow, radius: layout == .expanded ? 5 : 3)
        } else {
            emptyBattlePlaceholder
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
        CalendarDayRingView(style: .battle(state: .wonAny, margin: 1200))
        CalendarDayRingView(style: .battle(state: .lostAll, margin: -800))
        CalendarDayRingView(style: .battle(state: .inProgress, margin: 120))
        CalendarDayRingView(style: .steps(CalendarDayStepsState(steps: 8420, stepsGoal: 12000)))
        CalendarDayRingView(style: .steps(CalendarDayStepsState(steps: 12500, stepsGoal: 12000)))
    }
    .padding()
    .background { FitUpColors.Bg.base }
}
