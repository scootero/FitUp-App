//
//  CalendarMonthHeaderView.swift
//  FitUp
//
//  Month title and navigation for the activity calendar.
//

import SwiftUI

enum CalendarMonthNavSize {
    case compact
    case expanded

    var labelFontSize: CGFloat {
        switch self {
        case .compact: 13
        case .expanded: 16
        }
    }

    var arrowFontSize: CGFloat {
        switch self {
        case .compact: 14
        case .expanded: 17
        }
    }

    var arrowFrame: CGFloat {
        switch self {
        case .compact: 34
        case .expanded: 40
        }
    }

    var spacing: CGFloat {
        switch self {
        case .compact: 8
        case .expanded: 12
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .compact: 6
        case .expanded: 10
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .compact: 4
        case .expanded: 6
        }
    }
}

enum CalendarMonthTitleTone {
    case current
    case recentPast
    case deepPast

    init(monthsFromCurrent: Int) {
        switch monthsFromCurrent {
        case 0: self = .current
        case -1: self = .recentPast
        default: self = .deepPast
        }
    }

    var color: Color {
        switch self {
        case .current: return FitUpColors.Neon.cyan
        case .recentPast: return FitUpColors.Neon.orange
        case .deepPast: return FitUpColors.Neon.purple
        }
    }

    var glowColor: Color {
        color.opacity(0.45)
    }
}

struct CalendarMonthNavControls: View {
    let centerLabel: String
    let canGoNext: Bool
    var size: CalendarMonthNavSize = .compact
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    var body: some View {
        HStack(spacing: size.spacing) {
            gameArrowButton(systemName: "arrowtriangle.left.fill", action: onPrevious)

            Button(action: onToday) {
                Text(centerLabel.uppercased())
                    .font(FitUpFont.mono(size.labelFontSize, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(BattleStatsTheme.red)
                    .shadow(color: FitUpColors.Neon.red.opacity(0.55), radius: 5, x: 0, y: 0)
                    .shadow(color: BattleStatsTheme.red.opacity(0.35), radius: 10, x: 0, y: 0)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(.plain)

            if canGoNext {
                gameArrowButton(systemName: "arrowtriangle.right.fill", action: onNext)
            } else {
                Color.clear
                    .frame(width: size.arrowFrame, height: size.arrowFrame)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
    }

    private func gameArrowButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size.arrowFontSize, weight: .heavy))
                .foregroundStyle(
                    LinearGradient(
                        colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: FitUpColors.Neon.cyan.opacity(0.55), radius: 4, x: 0, y: 0)
                .frame(width: size.arrowFrame, height: size.arrowFrame)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.42))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            FitUpColors.Neon.cyan.opacity(0.85),
                                            FitUpColors.Neon.purple.opacity(0.65),
                                            FitUpColors.Neon.cyan.opacity(0.85),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        }
                        .shadow(color: FitUpColors.Neon.cyan.opacity(0.35), radius: 6, x: 0, y: 2)
                        .shadow(color: Color.black.opacity(0.45), radius: 4, x: 0, y: 3)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct CalendarMonthTitleLabel: View {
    let title: String
    let monthsFromCurrent: Int
    var fontSize: CGFloat = 16

    private var tone: CalendarMonthTitleTone {
        CalendarMonthTitleTone(monthsFromCurrent: monthsFromCurrent)
    }

    var body: some View {
        Text(title)
            .font(FitUpFont.display(fontSize, weight: .heavy))
            .foregroundStyle(tone.color)
            .shadow(color: tone.glowColor, radius: 6, x: 0, y: 0)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .animation(.easeOut(duration: 0.22), value: monthsFromCurrent)
    }
}

struct CalendarMonthHeaderView: View {
    let monthTitle: String
    let centerLabel: String
    let monthsFromCurrent: Int
    let canGoNext: Bool
    var headerTitleSize: CGFloat = 20
    var navSize: CalendarMonthNavSize = .compact
    var showsMonthTitle: Bool = true
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if showsMonthTitle {
                CalendarMonthTitleLabel(
                    title: monthTitle,
                    monthsFromCurrent: monthsFromCurrent,
                    fontSize: headerTitleSize
                )
            }

            Spacer(minLength: 0)

            CalendarMonthNavControls(
                centerLabel: centerLabel,
                canGoNext: canGoNext,
                size: navSize,
                onPrevious: onPrevious,
                onNext: onNext,
                onToday: onToday
            )
        }
    }
}
