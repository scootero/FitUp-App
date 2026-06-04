//
//  CalendarDayDetailDock.swift
//  FitUp
//
//  Bottom shimmer dock for activity calendar day taps.
//

import SwiftUI

struct CalendarDayDetailDock: View {
    let mode: ActivityCalendarMode
    let isLoading: Bool
    let battleDetail: CalendarDayBattleDetail?
    let battleMatch: CalendarDayBattleMatchDetail?
    let battleMatchIndex: Int
    let battleMatchCount: Int
    let stepsDetail: CalendarDayStepsDetail?
    let onSelectBattleMatchIndex: (Int) -> Void
    let onDismiss: () -> Void

    @State private var isPresented = false
    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        VStack(spacing: 0) {
            shimmerBar

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(FitUpColors.Text.secondary)
                            .frame(width: 32, height: 28)
                    }
                    .buttonStyle(.plain)
                }

                if isLoading {
                    ProgressView()
                        .tint(FitUpColors.Neon.cyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    content
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 22)
        }
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(rgb: 0x080812).opacity(0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    FitUpColors.Neon.cyan.opacity(0.35),
                                    FitUpColors.Neon.purple.opacity(0.2),
                                    FitUpColors.Neon.orange.opacity(0.25),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: FitUpColors.Neon.cyan.opacity(0.12), radius: 24, y: -8)
        }
        .padding(.horizontal, 10)
        .offset(y: isPresented ? 0 : 280)
        .opacity(isPresented ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
                isPresented = true
            }
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.2
            }
        }
        .onDisappear {
            isPresented = false
            shimmerPhase = -1
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .battles:
            if let battleDetail {
                CalendarBattleDayDetailPanel(
                    detail: battleDetail,
                    match: battleMatch,
                    matchIndex: battleMatchIndex,
                    matchCount: battleMatchCount,
                    onSelectMatchIndex: onSelectBattleMatchIndex
                )
                if let match = battleMatch, !match.rivalryEmblems.isEmpty {
                    CalendarBattleEmblemStrip(emblems: match.rivalryEmblems)
                }
            }
        case .steps:
            if let stepsDetail {
                CalendarStepsDayDetailPanel(detail: stepsDetail)
            }
        }
    }

    private var shimmerBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            LinearGradient(
                colors: [
                    Color.clear,
                    FitUpColors.Neon.cyan.opacity(0.35),
                    FitUpColors.Neon.pink.opacity(0.28),
                    Color.clear,
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 0.45)
            .offset(x: width * shimmerPhase)
            .blur(radius: 6)
        }
        .frame(height: 3)
        .clipped()
    }
}
