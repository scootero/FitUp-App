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
    let battleState: CalendarDayBattleState
    let stepsState: CalendarDayStepsState?
    let isSelected: Bool
    let onTap: () -> Void

    private var ringSize: CGFloat { layout.ringSize }

    var body: some View {
        VStack(spacing: layout == .expanded ? 4 : 5) {
            Text("\(item.dayNumber)")
                .font(FitUpFont.mono(layout.dayNumberFontSize, weight: item.isToday ? .bold : .semibold))
                .foregroundStyle(dayNumberColor)
                .frame(height: layout == .expanded ? 16 : 14)

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
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(FitUpColors.Neon.cyan.opacity(0.7), lineWidth: 1.2)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(FitUpColors.Neon.cyan.opacity(0.1))
                    )
            } else if item.isToday {
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
        if item.isWithinDisplayedMonth {
            return FitUpColors.Text.primary
        }
        return FitUpColors.Text.tertiary.opacity(0.55)
    }

    private var ringView: some View {
        Group {
            switch mode {
            case .battles:
                CalendarDayRingView(style: .battle(battleState), size: ringSize, layout: layout)
            case .steps:
                CalendarDayRingView(style: .steps(stepsState), size: ringSize, layout: layout)
            }
        }
        .frame(width: ringSize, height: ringSize)
    }
}
