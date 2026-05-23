//
//  CalendarMonthGridView.swift
//  FitUp
//
//  6-week Monday-first grid for the activity calendar.
//

import SwiftUI

struct CalendarMonthGridView: View {
    let items: [CalendarDayItem]
    let mode: ActivityCalendarMode
    let selectedDayId: String?
    let battleState: (String) -> CalendarDayBattleState
    let stepsState: (String) -> CalendarDayStepsState?
    let onSelectDay: (CalendarDayItem) -> Void

    private let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(FitUpFont.mono(10, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(items) { item in
                    CalendarDayCell(
                        item: item,
                        mode: mode,
                        battleState: battleState(item.id),
                        stepsState: stepsState(item.id),
                        isSelected: selectedDayId == item.id,
                        onTap: { onSelectDay(item) }
                    )
                }
            }
        }
    }
}
