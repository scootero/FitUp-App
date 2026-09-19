//
//  ActivityCalendarScrollContent.swift
//  FitUp
//
//  Shared month grid + mode switcher for activity calendar (sheet and inline card).
//

import SwiftUI

struct ActivityCalendarScrollContent: View {
    @ObservedObject var viewModel: ActivityCalendarViewModel
    var layout: ActivityCalendarLayout = .compact

    var body: some View {
        VStack(alignment: .leading, spacing: layout.sectionSpacing) {
            CalendarModePillSwitcher(mode: $viewModel.mode, size: layout.modeSwitcherSize)
                .frame(
                    maxWidth: layout.centersModeSwitcher ? .infinity : 220,
                    alignment: layout.centersModeSwitcher ? .center : .leading
                )
                .padding(.vertical, layout.modeSwitcherVerticalPadding)

            if layout.showsMonthRow {
                CalendarMonthHeaderView(
                    monthTitle: viewModel.monthTitle,
                    centerLabel: viewModel.monthShortTitle,
                    monthsFromCurrent: viewModel.monthsFromCurrent,
                    canGoNext: viewModel.canGoToNextMonth,
                    headerTitleSize: layout.headerTitleSize,
                    navSize: layout.monthNavSize,
                    onPrevious: {
                        viewModel.dismissDayDetail()
                        viewModel.goToPreviousMonth()
                    },
                    onNext: {
                        viewModel.dismissDayDetail()
                        viewModel.goToNextMonth()
                    },
                    onToday: {
                        viewModel.dismissDayDetail()
                        viewModel.goToToday()
                    }
                )
            }

            if viewModel.showHealthAccessBanner, viewModel.mode == .steps {
                healthAccessBanner
            }

            if let err = viewModel.errorMessage {
                Text(err)
                    .font(FitUpFont.body(12))
                    .foregroundStyle(FitUpColors.Neon.pink)
            }

            CalendarMonthGridView(
                items: viewModel.gridItems,
                mode: viewModel.mode,
                layout: layout,
                selectedDayId: viewModel.selectedDayItem?.id,
                battleSummary: { viewModel.battleSummary(for: $0) },
                battleMargin: { viewModel.battleMargin(for: $0) },
                stepsState: { viewModel.stepsState(for: $0) },
                showsRestDay: { viewModel.showsRestDay(for: $0) },
                showsNoBattleDay: { viewModel.showsNoBattleDay(for: $0) },
                isBeforeJoinDate: { viewModel.isBeforeJoinDate(for: $0) },
                onSelectDay: { viewModel.selectDay($0) }
            )
            .opacity(viewModel.isLoading ? 0.65 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var healthAccessBanner: some View {
        Text("FitOff can’t currently display Apple Health steps for daily rings. Review FitOff’s access in the Health app or Settings.")
            .font(FitUpFont.body(12))
            .foregroundStyle(FitUpColors.Text.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(.base)
    }
}
