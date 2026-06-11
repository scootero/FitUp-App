//
//  ActivityCalendarSheet.swift
//  FitUp
//
//  Full-screen activity calendar (Battles + Steps) from the STATS date chip.
//

import SwiftUI

struct ActivityCalendarSheet: View {
    let userId: UUID
    let profileTimeZoneIdentifier: String?
    let profileCreatedAt: Date?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ActivityCalendarViewModel

    init(
        userId: UUID,
        profileTimeZoneIdentifier: String?,
        profileCreatedAt: Date? = nil
    ) {
        self.userId = userId
        self.profileTimeZoneIdentifier = profileTimeZoneIdentifier
        self.profileCreatedAt = profileCreatedAt
        _viewModel = StateObject(
            wrappedValue: ActivityCalendarViewModel(
                userId: userId,
                profileTimeZoneIdentifier: profileTimeZoneIdentifier,
                profileCreatedAt: profileCreatedAt
            )
        )
    }

    private var showsDayDock: Bool {
        viewModel.selectedDayItem != nil
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FitUpColors.Bg.base.ignoresSafeArea()
                BackgroundGradientView()
                    .opacity(0.35)
                    .ignoresSafeArea()

                ScrollView {
                    ActivityCalendarScrollContent(viewModel: viewModel)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, showsDayDock ? 340 : 24)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    viewModel.reload()
                }

                if showsDayDock {
                    CalendarDayDetailDock(
                        mode: viewModel.mode,
                        isLoading: viewModel.isDayDetailLoading,
                        battleDetail: viewModel.battleDayDetail,
                        stepsDetail: viewModel.stepsDayDetail,
                        onDismiss: { viewModel.dismissDayDetail() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(FitUpColors.Neon.orange)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .trackProductScreen("activity_calendar", userId: userId)
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: showsDayDock)
        .onAppear {
            viewModel.start()
        }
        .onChange(of: viewModel.mode) { _, _ in
            trackCalendarContext()
        }
        .onChange(of: viewModel.displayedMonth) { _, _ in
            trackCalendarContext()
        }
    }

    private func trackCalendarContext() {
        ProductAnalytics.track(
            ProductAnalytics.Event.screenViewed,
            userId: userId,
            screenName: "activity_calendar",
            properties: [
                "mode": viewModel.mode.rawValue,
                "month": viewModel.monthTitle,
            ]
        )
    }

}
