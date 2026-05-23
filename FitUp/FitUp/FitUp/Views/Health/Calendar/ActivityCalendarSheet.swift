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

    @Environment(\.dismiss) private var dismiss
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
                    VStack(alignment: .leading, spacing: 16) {
                        CalendarModePillSwitcher(mode: $viewModel.mode)
                            .frame(maxWidth: .infinity)

                        CalendarMonthHeaderView(
                            monthTitle: viewModel.monthTitle,
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
                            selectedDayId: viewModel.selectedDayItem?.id,
                            battleState: { viewModel.battleState(for: $0) },
                            stepsState: { viewModel.stepsState(for: $0) },
                            onSelectDay: { viewModel.selectDay($0) }
                        )
                        .opacity(viewModel.isLoading ? 0.65 : 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, showsDayDock ? 320 : 24)
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
                        battleMatch: viewModel.selectedBattleMatch,
                        battleMatchIndex: viewModel.selectedBattleMatchIndex,
                        battleMatchCount: viewModel.battleDayDetail?.matches.count ?? 0,
                        stepsDetail: viewModel.stepsDayDetail,
                        onSelectBattleMatchIndex: { viewModel.selectBattleMatchIndex($0) },
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

    private var healthAccessBanner: some View {
        Text("Apple Health access is off. Enable Steps read access in Settings to see daily step rings.")
            .font(FitUpFont.body(12))
            .foregroundStyle(FitUpColors.Text.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(.base)
    }
}
