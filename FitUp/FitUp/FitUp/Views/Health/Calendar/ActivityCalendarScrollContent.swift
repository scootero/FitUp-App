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
            CalendarModePillSwitcher(mode: $viewModel.mode)
                .frame(maxWidth: 220)

            CalendarMonthHeaderView(
                monthTitle: viewModel.monthTitle,
                centerLabel: viewModel.monthShortTitle,
                headerTitleSize: layout.headerTitleSize,
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
                onSelectDay: { viewModel.selectDay($0) }
            )
            .opacity(viewModel.isLoading ? 0.65 : 1)

            if viewModel.mode == .steps {
                CalendarStepsLegendView(ringSize: layout == .expanded ? 14 : 12)
                    .padding(.top, 2)
            }
        }
    }

    private var healthAccessBanner: some View {
        Text("Apple Health access is off. Enable Steps read access in Settings to see daily step rings.")
            .font(FitUpFont.body(12))
            .foregroundStyle(FitUpColors.Text.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(.base)
    }
}
