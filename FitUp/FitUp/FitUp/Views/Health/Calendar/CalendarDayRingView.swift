//
//  CalendarDayRingView.swift
//  FitUp
//
//  Small day indicators for the activity calendar (ghost ring, battle dot, step progress).
//

import SwiftUI

enum CalendarDayRingStyle: Equatable {
    case ghost
    case battle(summary: CalendarDayBattleSummary, margin: Int?)
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

    private var battleLabelFontScale: CGFloat {
        layout == .expanded ? 0.3 : 0.28
    }

    private var stepsGoalRingColor: Color { FitUpColors.Neon.blue }
    private var stepsProgressRingColor: Color { FitUpColors.Neon.cyan }
    private var liveRingColor: Color { FitUpColors.Neon.orange }

    var body: some View {
        switch style {
        case .ghost:
            ghostRing
        case .battle(let summary, let margin):
            battleIndicator(summary: summary, margin: margin)
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
    private func battleIndicator(summary: CalendarDayBattleSummary, margin: Int?) -> some View {
        let indicator = CalendarBattleDayIndicator.resolve(summary: summary, margin: margin)

        switch indicator {
        case .ghost:
            ghostRing
        case .live(let trimProgress, let label):
            liveBattleRing(trimProgress: trimProgress, label: label)
        case .filled(let label, let fillColor, let glowColor):
            filledBattleCircle(label: label, fillColor: fillColor, glowColor: glowColor)
        }
    }

    private func liveBattleRing(trimProgress: Double, label: String) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
                .frame(width: innerDiameter, height: innerDiameter)

            Circle()
                .trim(from: 0, to: CGFloat(trimProgress))
                .stroke(
                    liveRingColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: innerDiameter, height: innerDiameter)
                .rotationEffect(.degrees(-90))
                .shadow(color: liveRingColor.opacity(0.35), radius: layout == .expanded ? 4 : 3)

            Text(label)
                .font(FitUpFont.mono(size * battleLabelFontScale, weight: .bold))
                .foregroundStyle(liveRingColor)
                .minimumScaleFactor(0.45)
                .lineLimit(1)
                .padding(.horizontal, size * 0.1)
        }
    }

    private func filledBattleCircle(label: String, fillColor: Color, glowColor: Color) -> some View {
        ZStack {
            Circle()
                .fill(fillColor)
                .frame(width: innerDiameter, height: innerDiameter)
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.6)
                }
                .shadow(color: glowColor, radius: layout == .expanded ? 5 : 3)

            Text(label)
                .font(FitUpFont.mono(size * battleLabelFontScale, weight: .black))
                .foregroundStyle(Color.white.opacity(0.92))
                .minimumScaleFactor(0.45)
                .lineLimit(1)
                .padding(.horizontal, size * 0.1)
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
        CalendarDayRingView(style: .battle(summary: CalendarDayBattleSummary(state: .wonAny, matchCount: 1, wins: 1, losses: 0, voids: 0), margin: nil))
        CalendarDayRingView(style: .battle(summary: CalendarDayBattleSummary(state: .lostAll, matchCount: 1, wins: 0, losses: 1, voids: 0), margin: nil))
        CalendarDayRingView(style: .battle(summary: CalendarDayBattleSummary(state: .voidOnly, matchCount: 1, wins: 0, losses: 0, voids: 1), margin: nil))
        CalendarDayRingView(style: .battle(summary: CalendarDayBattleSummary(state: .inProgress, matchCount: 1, wins: 0, losses: 0, voids: 0), margin: 850))
        CalendarDayRingView(style: .battle(summary: CalendarDayBattleSummary(state: .wonAny, matchCount: 2, wins: 2, losses: 0, voids: 0), margin: nil))
        CalendarDayRingView(style: .steps(CalendarDayStepsState(steps: 8420, stepsGoal: 12000)))
    }
    .padding()
    .background { FitUpColors.Bg.base }
}
