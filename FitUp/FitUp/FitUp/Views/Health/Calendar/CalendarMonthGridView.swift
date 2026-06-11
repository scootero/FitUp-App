//
//  CalendarMonthGridView.swift
//  FitUp
//
//  Monday-first month grid for the activity calendar.
//

import SwiftUI

struct CalendarMonthGridView: View {
    let items: [CalendarDayItem]
    let mode: ActivityCalendarMode
    var layout: ActivityCalendarLayout = .compact
    let selectedDayId: String?
    let battleSummary: (String) -> CalendarDayBattleSummary
    let battleMargin: (String) -> Int?
    let stepsState: (String) -> CalendarDayStepsState?
    let showsRestDay: (String) -> Bool
    let showsNoBattleDay: (String) -> Bool
    let isBeforeJoinDate: (String) -> Bool
    let onSelectDay: (CalendarDayItem) -> Void

    private let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: layout.gridColumnSpacing), count: 7)
    }

    var body: some View {
        VStack(spacing: layout == .expanded ? 4 : 8) {
            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(FitUpFont.mono(layout == .expanded ? 9 : 10, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: layout.gridRowSpacing) {
                ForEach(items) { item in
                    CalendarDayCell(
                        item: item,
                        mode: mode,
                        layout: layout,
                        battleSummary: battleSummary(item.id),
                        battleMargin: battleMargin(item.id),
                        stepsState: stepsState(item.id),
                        showsRestDay: showsRestDay(item.id),
                        showsNoBattleDay: showsNoBattleDay(item.id),
                        isBeforeJoinDate: isBeforeJoinDate(item.id),
                        isSelected: selectedDayId == item.id,
                        onTap: { onSelectDay(item) }
                    )
                }
            }
        }
    }
}
