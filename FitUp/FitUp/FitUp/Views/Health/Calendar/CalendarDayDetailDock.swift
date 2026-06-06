//
//  CalendarDayDetailDock.swift
//  FitUp
//
//  Day detail chrome for activity calendar (bottom dock or stats-card sheet).
//

import SwiftUI

enum CalendarDayDetailPresentationStyle {
    case bottomDock
    case sheet
}

struct CalendarDayDetailDock: View {
    let mode: ActivityCalendarMode
    let isLoading: Bool
    let battleDetail: CalendarDayBattleDetail?
    let stepsDetail: CalendarDayStepsDetail?
    var presentationStyle: CalendarDayDetailPresentationStyle = .bottomDock
    var onOpenMatchDetails: ((UUID, String) -> Void)?
    let onDismiss: () -> Void

    @State private var isPresented = false
    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        Group {
            switch presentationStyle {
            case .bottomDock:
                dockBody
            case .sheet:
                sheetBody
            }
        }
    }

    private var sheetBody: some View {
        VStack(spacing: 0) {
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
            .padding(.horizontal, 16)
            .padding(.top, 4)

            if isLoading {
                ProgressView()
                    .tint(FitUpColors.Neon.cyan)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
                    .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(FitUpColors.Bg.base)
    }

    private var dockBody: some View {
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
                    onOpenMatchDetails: onOpenMatchDetails
                )
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
