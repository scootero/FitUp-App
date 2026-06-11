//
//  CalendarPaceChipView.swift
//  FitUp
//
//  Bottom-right pace chip on the activity calendar (7D / 30D vs today's step pace).
//

import SwiftUI

struct CalendarPaceChipView: View {
    let inputs: CalendarPaceChipInputs
    var layout: ActivityCalendarLayout = .compact

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathingExpanded = false
    @State private var isInfoPresented = false

    private var isExpanded: Bool { layout == .expanded }

    private var headerFontSize: CGFloat { isExpanded ? 8.5 : 7.5 }
    private var percentFontSize: CGFloat { isExpanded ? 18.7 : 15.3 }
    private var statusFontSize: CGFloat { isExpanded ? 7.5 : 6.5 }
    private var cornerRadius: CGFloat { isExpanded ? 14 : 11 }
    private var columnSpacing: CGFloat { isExpanded ? 22 : 16 }
    private var horizontalPadding: CGFloat { isExpanded ? 16 : 12 }
    private var verticalPadding: CGFloat { isExpanded ? 12 : 9 }
    private var columnMinWidth: CGFloat { isExpanded ? 108 : 88 }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            if let display = CalendarPaceComparison.make(
                todaySteps: inputs.todaySteps,
                avg7: inputs.avg7,
                avg30: inputs.avg30,
                profileTimeZoneIdentifier: inputs.profileTimeZoneIdentifier,
                referenceDate: context.date
            ) {
                chipContent(display: display)
            }
        }
    }

    private func chipContent(display: CalendarPaceDisplay) -> some View {
        VStack(spacing: isExpanded ? 8 : 6) {
            HStack(alignment: .top, spacing: columnSpacing) {
                paceColumn(
                    window: .sevenDay,
                    pct: display.pct7,
                    display: display
                )

                paceDivider

                paceColumn(
                    window: .thirtyDay,
                    pct: display.pct30,
                    display: display
                )
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .padding(.top, isExpanded ? 6 : 4)
        .background { chipBackground(display: display) }
        .overlay(alignment: .topTrailing) {
            paceInfoButton(display: display)
                .padding(.top, isExpanded ? 4 : 2)
                .padding(.trailing, isExpanded ? 4 : 2)
        }
        .scaleEffect(breathScale(for: display))
        .animation(breathAnimation(for: display), value: isBreathingExpanded)
        .onAppear { startBreathingIfNeeded(zone: display.zone) }
        .onChange(of: display.zone) { _, zone in
            startBreathingIfNeeded(zone: zone)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: display))
    }

    private func paceColumn(
        window: CalendarPaceComparison.PaceWindow,
        pct: Int,
        display: CalendarPaceDisplay
    ) -> some View {
        VStack(spacing: isExpanded ? 6 : 5) {
            Text(window.columnHeader)
                .font(FitUpFont.body(headerFontSize, weight: .bold))
                .foregroundStyle(FitUpColors.Text.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)

            Text(CalendarPaceComparison.formattedPercent(pct))
                .font(FitUpFont.mono(percentFontSize, weight: .heavy))
                .tracking(1.6)
                .foregroundStyle(
                    LinearGradient(
                        colors: display.percentGradient(for: pct),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: display.percentGradient(for: pct).first?.opacity(0.35) ?? .clear, radius: 3)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)

            Text(CalendarPaceComparison.columnStatusLabel(for: pct, window: window))
                .font(FitUpFont.body(statusFontSize, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: display.statusGradientColors(for: pct),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .multilineTextAlignment(.center)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .frame(minWidth: columnMinWidth, maxWidth: .infinity)
    }

    private func paceInfoButton(display: CalendarPaceDisplay) -> some View {
        Button {
            isInfoPresented = true
        } label: {
            Image(systemName: "info.circle.fill")
                .font(.system(size: isExpanded ? 14 : 12, weight: .semibold))
                .foregroundStyle(infoButtonColor(for: display))
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                .frame(width: isExpanded ? 28 : 24, height: isExpanded ? 28 : 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("About step pace")
        .popover(isPresented: $isInfoPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(CalendarPaceComparison.infoTitle)
                    .font(FitUpFont.body(14, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.primary)
                Text(CalendarPaceComparison.infoBody)
                    .font(FitUpFont.body(12, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: 260, alignment: .leading)
            .presentationCompactAdaptation(.popover)
        }
    }

    private func infoButtonColor(for display: CalendarPaceDisplay) -> Color {
        switch display.zone {
        case .ahead:
            return FitUpColors.Neon.cyan
        case .behindMild:
            return FitUpColors.Neon.orange
        case .behindSevere:
            return FitUpColors.Neon.pink
        }
    }

    private var paceDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        FitUpColors.Neon.orange.opacity(0.05),
                        FitUpColors.Neon.orange.opacity(0.35),
                        FitUpColors.Neon.orange.opacity(0.05),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 1)
            .padding(.vertical, 2)
    }

    @ViewBuilder
    private func chipBackground(display: CalendarPaceDisplay) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: display.fillGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.35))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: display.borderGradientColors.map { $0.opacity(0.55) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: display.glowColor.opacity(isExpanded ? 0.38 : 0.28), radius: isExpanded ? 10 : 6)
    }

    private func breathScale(for display: CalendarPaceDisplay) -> CGFloat {
        guard display.zone == .ahead, !reduceMotion else { return 1 }
        return isBreathingExpanded ? 1.02 : 0.99
    }

    private func breathAnimation(for display: CalendarPaceDisplay) -> Animation? {
        guard display.zone == .ahead, !reduceMotion else { return nil }
        return .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
    }

    private func startBreathingIfNeeded(zone: CalendarPaceZone) {
        guard zone == .ahead, !reduceMotion else {
            isBreathingExpanded = false
            return
        }
        isBreathingExpanded = true
    }

    private func accessibilityLabel(for display: CalendarPaceDisplay) -> String {
        let label7 = CalendarPaceComparison.columnStatusLabel(for: display.pct7, window: .sevenDay)
        let label30 = CalendarPaceComparison.columnStatusLabel(for: display.pct30, window: .thirtyDay)
        return "Step pace vs average. 7 day \(CalendarPaceComparison.formattedPercent(display.pct7)). \(label7). 30 day \(CalendarPaceComparison.formattedPercent(display.pct30)). \(label30)."
    }
}

#Preview {
    VStack(spacing: 20) {
        CalendarPaceChipView(
            inputs: CalendarPaceChipInputs(
                todaySteps: 6200,
                avg7: 8000,
                avg30: 7500,
                profileTimeZoneIdentifier: nil
            ),
            layout: .expanded
        )
        CalendarPaceChipView(
            inputs: CalendarPaceChipInputs(
                todaySteps: 4500,
                avg7: 8000,
                avg30: 7500,
                profileTimeZoneIdentifier: nil
            ),
            layout: .expanded
        )
        CalendarPaceChipView(
            inputs: CalendarPaceChipInputs(
                todaySteps: 2800,
                avg7: 8000,
                avg30: 7500,
                profileTimeZoneIdentifier: nil
            ),
            layout: .expanded
        )
    }
    .padding()
    .background { FitUpColors.Bg.base }
}
