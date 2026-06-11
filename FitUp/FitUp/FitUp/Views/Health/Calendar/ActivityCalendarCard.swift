//
//  ActivityCalendarCard.swift
//  FitUp
//
//  Inline activity calendar (Battles + Steps) on the arcade stats page.
//

import SwiftUI

struct ActivityCalendarCard: View {
    let userId: UUID?
    let profileTimeZoneIdentifier: String?
    var profileCreatedAt: Date? = nil
    var onOpenMatchDetails: (UUID, String) -> Void = { _, _ in }

    var body: some View {
        if let userId {
            ActivityCalendarCardContent(
                userId: userId,
                profileTimeZoneIdentifier: profileTimeZoneIdentifier,
                profileCreatedAt: profileCreatedAt,
                onOpenMatchDetails: onOpenMatchDetails
            )
        } else {
            signedOutPlaceholder
        }
    }

    private var signedOutPlaceholder: some View {
        BattleStatsTheme.battleStatsCard(accent: .mint) {
            VStack(alignment: .leading, spacing: 10) {
                BattleStatsTheme.sectionTitle("ACTIVITY CALENDAR", accent: .mint)
                Text("Sign in to view your activity calendar.")
                    .font(.system(size: BattleStatsTheme.Typography.captionSmall, weight: .semibold))
                    .foregroundStyle(BattleStatsTheme.textLabel)
            }
        }
    }
}

private struct ActivityCalendarCardContent: View {
    let userId: UUID
    let profileTimeZoneIdentifier: String?
    let profileCreatedAt: Date?
    var onOpenMatchDetails: (UUID, String) -> Void

    @StateObject private var viewModel: ActivityCalendarViewModel

    init(
        userId: UUID,
        profileTimeZoneIdentifier: String?,
        profileCreatedAt: Date?,
        onOpenMatchDetails: @escaping (UUID, String) -> Void
    ) {
        self.userId = userId
        self.profileTimeZoneIdentifier = profileTimeZoneIdentifier
        self.profileCreatedAt = profileCreatedAt
        self.onOpenMatchDetails = onOpenMatchDetails
        _viewModel = StateObject(
            wrappedValue: ActivityCalendarViewModel(
                userId: userId,
                profileTimeZoneIdentifier: profileTimeZoneIdentifier,
                profileCreatedAt: profileCreatedAt
            )
        )
    }

    private var showsDayDetail: Bool {
        viewModel.selectedDayItem != nil
    }

    var body: some View {
        BattleStatsTheme.battleStatsCard(accent: .mint) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ACTIVITY CALENDAR")
                    .font(.system(
                        size: ActivityCalendarLayout.expanded.cardSectionTitleSize,
                        weight: .heavy,
                        design: .rounded
                    ))
                    .tracking(1.8)
                    .foregroundStyle(FitUpColors.Text.title)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(alignment: .center, spacing: 10) {
                    CalendarMonthTitleLabel(
                        title: viewModel.monthTitle,
                        monthsFromCurrent: viewModel.monthsFromCurrent,
                        fontSize: ActivityCalendarLayout.expanded.monthSubtitleSize
                    )

                    Spacer(minLength: 0)

                    CalendarMonthNavControls(
                        centerLabel: viewModel.monthShortTitle,
                        canGoNext: viewModel.canGoToNextMonth,
                        size: ActivityCalendarLayout.expanded.monthNavSize,
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

                ActivityCalendarScrollContent(viewModel: viewModel, layout: .expanded)
            }
        }
        .onAppear {
            viewModel.start()
            trackCalendarContext()
        }
        .onChange(of: viewModel.mode) { _, _ in
            trackCalendarContext()
        }
        .onChange(of: viewModel.displayedMonth) { _, _ in
            trackCalendarContext()
        }
        .sheet(isPresented: dayDetailPresented) {
            CalendarDayDetailDock(
                mode: viewModel.mode,
                isLoading: viewModel.isDayDetailLoading,
                battleDetail: viewModel.battleDayDetail,
                stepsDetail: viewModel.stepsDayDetail,
                presentationStyle: .sheet,
                onOpenMatchDetails: { matchId, opponentName in
                    viewModel.dismissDayDetail()
                    onOpenMatchDetails(matchId, opponentName)
                },
                onDismiss: { viewModel.dismissDayDetail() }
            )
            .presentationDetents([.fraction(0.78)])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
            .presentationBackground(FitUpColors.Bg.base)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: showsDayDetail)
    }

    private var dayDetailPresented: Binding<Bool> {
        Binding(
            get: { viewModel.selectedDayItem != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissDayDetail()
                }
            }
        )
    }

    private func trackCalendarContext() {
        ProductAnalytics.track(
            ProductAnalytics.Event.screenViewed,
            userId: userId,
            screenName: "activity_calendar",
            properties: [
                "mode": viewModel.mode.rawValue,
                "month": viewModel.monthTitle,
                "placement": "stats_arcade_card",
            ]
        )
    }
}
