//
//  CalendarDayCell.swift
//  FitUp
//
//  Single day in the activity calendar month grid.
//

import SwiftUI

struct CalendarDayCell: View {
    let item: CalendarDayItem
    let mode: ActivityCalendarMode
    var layout: ActivityCalendarLayout = .compact
    let battleSummary: CalendarDayBattleSummary
    let battleMargin: Int?
    let stepsState: CalendarDayStepsState?
    let showsRestDay: Bool
    let showsNoBattleDay: Bool
    let isBeforeJoinDate: Bool
    let isSelected: Bool
    let onTap: () -> Void

    private var ringSize: CGFloat { layout.ringSize }

    var body: some View {
        VStack(spacing: layout == .expanded ? 3 : 5) {
            Text("\(item.dayNumber)")
                .font(FitUpFont.mono(layout.dayNumberFontSize, weight: item.isToday ? .bold : .semibold))
                .foregroundStyle(dayNumberColor)
                .frame(height: layout == .expanded ? 14 : 14)

            if item.isWithinDisplayedMonth {
                ringView
            } else {
                Color.clear
                    .frame(width: ringSize, height: ringSize)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, layout.cellVerticalPadding)
        .background {
            if isSelected, !isBeforeJoinDate {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(FitUpColors.Neon.cyan.opacity(0.7), lineWidth: 1.2)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(FitUpColors.Neon.cyan.opacity(0.1))
                    )
            } else if item.isToday, !isBeforeJoinDate {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(FitUpColors.Neon.orange.opacity(0.75), lineWidth: 1.2)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(FitUpColors.Neon.orange.opacity(0.08))
                    )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var dayNumberColor: Color {
        if item.isToday {
            return FitUpColors.Neon.orange
        }
        if isBeforeJoinDate, item.isWithinDisplayedMonth {
            return FitUpColors.Text.tertiary.opacity(0.4)
        }
        if item.isWithinDisplayedMonth {
            return FitUpColors.Text.primary
        }
        return FitUpColors.Text.tertiary.opacity(0.55)
    }

    private var ringView: some View {
        Group {
            if isBeforeJoinDate {
                CalendarDayRingView(style: .notApplicable, size: ringSize, layout: layout)
                    .frame(width: ringSize, height: ringSize)
            } else {
                switch mode {
                case .battles:
                    VStack(spacing: 1) {
                        CalendarDayRingView(
                            style: .battle(
                                summary: battleSummary,
                                margin: battleMargin,
                                showsNoBattleDay: showsNoBattleDay,
                                showsRestDay: showsRestDay
                            ),
                            size: ringSize,
                            layout: layout
                        )
                        .frame(width: ringSize, height: ringSize)

                        if battleSummary.matchCount > 1 {
                            Text("x\(battleSummary.matchCount)")
                                .font(FitUpFont.mono(layout == .expanded ? 7 : 8, weight: .semibold))
                                .foregroundStyle(FitUpColors.Text.tertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                case .steps:
                    CalendarDayRingView(
                        style: .steps(stepsState, showsRestDay: showsRestDay),
                        size: ringSize,
                        layout: layout
                    )
                    .frame(width: ringSize, height: ringSize)
                }
            }
        }
    }
}
