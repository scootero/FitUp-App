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

    var body: some View {
        if let userId {
            ActivityCalendarCardContent(
                userId: userId,
                profileTimeZoneIdentifier: profileTimeZoneIdentifier
            )
        } else {
            signedOutPlaceholder
        }
    }

    private var signedOutPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader
            Text("Sign in to view your activity calendar.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.62))
        }
        .padding(14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(cardTint.opacity(0.42), lineWidth: 1.4)
        }
    }

    private var cardHeader: some View {
        Text("ACTIVITY CALENDAR")
            .font(.system(size: 18, weight: .black))
            .tracking(2)
            .foregroundStyle(cardTint)
    }

    private var cardTint: Color {
        Color(red: 0.18, green: 1, blue: 0.54)
    }

    private var cardBackground: Color {
        Color(red: 0.02, green: 0.03, blue: 0.06)
    }
}

private struct ActivityCalendarCardContent: View {
    let userId: UUID
    let profileTimeZoneIdentifier: String?

    @StateObject private var viewModel: ActivityCalendarViewModel

    init(userId: UUID, profileTimeZoneIdentifier: String?) {
        self.userId = userId
        self.profileTimeZoneIdentifier = profileTimeZoneIdentifier
        _viewModel = StateObject(
            wrappedValue: ActivityCalendarViewModel(
                userId: userId,
                profileTimeZoneIdentifier: profileTimeZoneIdentifier
            )
        )
    }

    private var showsDayDetail: Bool {
        viewModel.selectedDayItem != nil
    }

    private var cardTint: Color {
        Color(red: 0.18, green: 1, blue: 0.54)
    }

    private var cardBackground: Color {
        Color(red: 0.02, green: 0.03, blue: 0.06)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACTIVITY CALENDAR")
                .font(.system(size: 18, weight: .black))
                .tracking(2)
                .foregroundStyle(cardTint)

            ActivityCalendarScrollContent(viewModel: viewModel, layout: .expanded)
        }
        .padding(14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(cardTint.opacity(0.42), lineWidth: 1.4)
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
            NavigationStack {
                ScrollView {
                    CalendarDayDetailDock(
                        mode: viewModel.mode,
                        isLoading: viewModel.isDayDetailLoading,
                        battleDetail: viewModel.battleDayDetail,
                        battleMatch: viewModel.selectedBattleMatch,
                        battleMatchIndex: viewModel.selectedBattleMatchIndex,
                        battleMatchCount: viewModel.battleDayDetail?.matches.count ?? 0,
                        stepsDetail: viewModel.stepsDayDetail,
                        onSelectBattleMatchIndex: { viewModel.selectBattleMatchIndex($0) },
                        onDismiss: { viewModel.dismissDayDetail() }
                    )
                    .padding(.top, 8)
                }
                .scrollIndicators(.hidden)
                .background(FitUpColors.Bg.base.ignoresSafeArea())
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
