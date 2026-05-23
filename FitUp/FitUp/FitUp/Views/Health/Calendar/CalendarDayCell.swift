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
    let battleState: CalendarDayBattleState
    let stepsState: CalendarDayStepsState?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            Text("\(item.dayNumber)")
                .font(FitUpFont.mono(12, weight: item.isToday ? .bold : .semibold))
                .foregroundStyle(dayNumberColor)
                .frame(height: 14)

            if item.isWithinDisplayedMonth {
                ringView
            } else {
                Color.clear
                    .frame(width: 26, height: 26)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
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
                CalendarDayRingView(style: .battle(battleState))
            case .steps:
                CalendarDayRingView(style: .steps(stepsState))
            }
        }
        .frame(width: 26, height: 26)
    }
}
