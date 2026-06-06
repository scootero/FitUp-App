//
//  StatsMetricInfoButton.swift
//  FitUp
//

import SwiftUI
import UIKit

enum StatsRivalMetricExplainer: String, Identifiable {
    case avgStepsBattleDays
    case yourWinRate
    case avgMargin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .avgStepsBattleDays: return "Avg Steps · Battle Days"
        case .yourWinRate: return "Your Win %"
        case .avgMargin: return "Avg Margin"
        }
    }

    var bodyText: String {
        switch self {
        case .avgStepsBattleDays:
            return "Your average steps on finalized days you competed against this opponent."
        case .yourWinRate:
            return "How often you win completed matches against this opponent. Ties may appear in the record but are not counted in this percentage."
        case .avgMargin:
            return "Average step difference between you and this opponent for the relevant rival category."
        }
    }
}

struct StatsMetricInfoButton: View {
    let explainer: StatsRivalMetricExplainer
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BattleStatsTheme.textGradient(.label))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("About \(explainer.title)")
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(explainer.title)
                    .battleStatsStyle(.primary, weight: .bold)
                Text(explainer.bodyText)
                    .battleStatsStyle(.secondary, size: BattleStatsTheme.Typography.bodySmall)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: 260, alignment: .leading)
            .presentationCompactAdaptation(.popover)
        }
    }
}

// MARK: - Card info affordance (Steps Today style)

enum StatsCardInfoCornerMetrics {
    static let topInset: CGFloat = 10
    static let trailingInset: CGFloat = 10
}

struct StatsCardInfoButton: View {
    enum Style {
        case prominent
        case subtle
        case cardCorner
    }

    var style: Style = .prominent
    var accent: BattleStatsTheme.SectionAccent = .cool
    var accessibilityTitle: String = "this metric"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                switch style {
                case .prominent:
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                        .frame(width: 44, height: 44)
                case .subtle:
                    Image(systemName: "info.circle")
                        .font(.system(size: BattleStatsTheme.Typography.caption, weight: .medium))
                        .foregroundStyle(BattleStatsTheme.textGradient(.label, accent: accent))
                        .frame(width: 28, height: 28)
                case .cardCorner:
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(BattleStatsTheme.textGradient(.sectionTitle, accent: accent))
                        .shadow(color: Color.black.opacity(0.38), radius: 2, y: 1)
                        .shadow(color: accentHighlight.opacity(0.32), radius: 10)
                        .frame(width: 52, height: 52)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("What is \(accessibilityTitle)?")
    }

    private var accentHighlight: Color {
        switch accent {
        case .neutral: return Color(red: 1, green: 0.94, blue: 0.78)
        case .warm: return BattleStatsTheme.gold
        case .cool: return BattleStatsTheme.blue
        case .mint: return BattleStatsTheme.green
        }
    }
}

struct StatsMetricExplainerButton: View {
    let kind: StatsMetricExplainerKind
    var style: StatsCardInfoButton.Style = .cardCorner
    var accent: BattleStatsTheme.SectionAccent = .cool
    var onShow: (StatsMetricExplainerKind) -> Void

    var body: some View {
        StatsCardInfoButton(
            style: style,
            accent: accent,
            accessibilityTitle: kind.accessibilityTitle
        ) {
            onShow(kind)
        }
    }
}

extension View {
    func statsCardMetricInfoCorner(
        kind: StatsMetricExplainerKind,
        accent: BattleStatsTheme.SectionAccent = .cool,
        onShow: @escaping (StatsMetricExplainerKind) -> Void
    ) -> some View {
        overlay(alignment: .topTrailing) {
            StatsMetricExplainerButton(kind: kind, accent: accent, onShow: onShow)
                .padding(.top, StatsCardInfoCornerMetrics.topInset)
                .padding(.trailing, StatsCardInfoCornerMetrics.trailingInset)
        }
    }
}

// MARK: - Full-screen metric explainers

enum StatsMetricExplainerKind: Equatable {
    case stepsToday
    case battleMargin
    case todaysBattleSteps
    case allTimeBattleSteps
    case avgBattleDay
    case battlesCompleted
    case daysCompeted
    case extraBattleImpact
    case personalRecords
    case bestBattleDayRecord
    case biggestWinMargin
    case closestBattle
    case longestWinStreak
    case battleDayEffect

    var accessibilityTitle: String {
        switch self {
        case .stepsToday: return "your steps today"
        case .battleMargin: return "battle margin"
        case .todaysBattleSteps: return "today's battle steps"
        case .allTimeBattleSteps: return "all-time battle steps"
        case .avgBattleDay: return "average battle day"
        case .battlesCompleted: return "battles completed"
        case .daysCompeted: return "days competed"
        case .extraBattleImpact: return "extra steps from battles"
        case .personalRecords: return "personal records"
        case .bestBattleDayRecord: return "best battle day"
        case .biggestWinMargin: return "biggest win margin"
        case .closestBattle: return "closest battle"
        case .longestWinStreak: return "longest win streak"
        case .battleDayEffect: return "battle day effect"
        }
    }

    var title: String {
        switch self {
        case .stepsToday: return "Your steps today"
        case .battleMargin: return "Battle margin"
        case .todaysBattleSteps: return "Today's battle steps"
        case .allTimeBattleSteps: return "All-time battle steps"
        case .avgBattleDay: return "Avg battle day"
        case .battlesCompleted: return "Battles completed"
        case .daysCompeted: return "Days competed"
        case .extraBattleImpact: return "Extra steps from battles"
        case .personalRecords: return "Personal records"
        case .bestBattleDayRecord: return "Best battle day"
        case .biggestWinMargin: return "Biggest win margin"
        case .closestBattle: return "Closest battle"
        case .longestWinStreak: return "Longest win streak"
        case .battleDayEffect: return "Battle day effect"
        }
    }

    var bodyText: String {
        switch self {
        case .stepsToday:
            return "Your real step count from Apple Health for today—not match scores or rival comparisons."
        case .battleMargin:
            return "Each day we compare your full-day steps to the closest rival affecting your standing. Positive means ahead; negative means behind."
        case .todaysBattleSteps:
            return "Your HealthKit steps today when you have an active steps battle. Only counts on battle days."
        case .allTimeBattleSteps:
            return "Sum of your steps on every finalized battle day, plus today's live count while you're in a match."
        case .avgBattleDay:
            return "Average steps on completed battle days. Today isn't included until the day finalizes."
        case .battlesCompleted:
            return "Finished step matches you've played—each completed challenge counts once."
        case .daysCompeted:
            return "Unique calendar days with a finalized battle step total. Multiple matches on one day still count once."
        case .extraBattleImpact:
            return "Estimated bonus steps from walking more on battle days compared with your normal-day average."
        case .personalRecords:
            return "Your standout highs from the last year of battle days and completed matches."
        case .bestBattleDayRecord:
            return "Your highest step total on a single battle day in the last year."
        case .biggestWinMargin:
            return "The largest step lead you had over your closest rival on a single battle day."
        case .closestBattle:
            return "The smallest step lead you still won by on a battle day—your nail-biter."
        case .longestWinStreak:
            return "Most consecutive completed matches you've won in a row."
        case .battleDayEffect:
            return "Compares your average steps on battle days versus normal non-battle days."
        }
    }

    var exampleText: String {
        switch self {
        case .stepsToday:
            return "Example: 8,432 steps by 6pm—the chart shows when those steps landed each hour."
        case .battleMargin:
            return "Example: +1,240 on Tuesday and −600 on Wednesday gives a +640 net margin for that week."
        case .todaysBattleSteps:
            return "Example: You're in a 7-day match—today's 8,420 steps show here until the day finalizes."
        case .allTimeBattleSteps:
            return "Example: 12 past battle days plus today's steps add up to your all-time total."
        case .avgBattleDay:
            return "Example: 9,850 average across 12 finalized battle days."
        case .battlesCompleted:
            return "Example: A 7-day challenge you finished counts as one completed battle."
        case .daysCompeted:
            return "Example: Two active matches on the same Tuesday still count as one competed day."
        case .extraBattleImpact:
            return "Example: You walk ~800 more steps per battle day—that adds up to extra miles over time."
        case .personalRecords:
            return "Example: Best day, biggest win, closest call, and longest streak—all from your recent history."
        case .bestBattleDayRecord:
            return "Example: 14,200 steps on Mar 12—your peak battle-day effort."
        case .biggestWinMargin:
            return "Example: You beat your rival by +2,400 steps on a single day."
        case .closestBattle:
            return "Example: You won by just +42 steps—still counts."
        case .longestWinStreak:
            return "Example: Five wins in a row across different rivals."
        case .battleDayEffect:
            return "Example: 10,200 avg on battle days vs 8,900 on normal days—a +15% uplift."
        }
    }

    var accentColor: Color {
        switch self {
        case .stepsToday: return FitUpColors.Neon.cyan
        case .battleMargin: return FitUpColors.Neon.green
        case .todaysBattleSteps: return BattleStatsTheme.green
        case .allTimeBattleSteps: return BattleStatsTheme.blue
        case .avgBattleDay: return BattleStatsTheme.gold
        case .battlesCompleted: return BattleStatsTheme.purple
        case .daysCompeted: return BattleStatsTheme.orange
        case .extraBattleImpact: return BattleStatsTheme.green
        case .personalRecords: return BattleStatsTheme.gold
        case .bestBattleDayRecord: return BattleStatsTheme.gold
        case .biggestWinMargin: return BattleStatsTheme.green
        case .closestBattle: return BattleStatsTheme.orange
        case .longestWinStreak: return BattleStatsTheme.orange
        case .battleDayEffect: return BattleStatsTheme.green
        }
    }

    static func personalRecordKind(forRowId rowId: String) -> StatsMetricExplainerKind? {
        switch rowId {
        case "best_day": return .bestBattleDayRecord
        case "biggest_win": return .biggestWinMargin
        case "closest": return .closestBattle
        case "longest_streak": return .longestWinStreak
        default: return nil
        }
    }
}

struct StatsMetricExplainerOverlay: View {
    let kind: StatsMetricExplainerKind
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Text(kind.title)
                        .font(FitUpFont.display(22, weight: .heavy))
                        .foregroundStyle(FitUpColors.Text.primary)
                    Spacer(minLength: 8)
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(FitUpColors.Text.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }

                Text(kind.bodyText)
                    .font(FitUpFont.body(13, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(kind.accentColor)
                        .padding(.top, 2)
                    Text(kind.exampleText)
                        .font(FitUpFont.body(12, weight: .semibold))
                        .foregroundStyle(kind.accentColor.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(kind.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous))

                Text("Tap anywhere to close")
                    .font(FitUpFont.body(11, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(18)
            .frame(maxWidth: min(UIScreen.main.bounds.width - 40, 340))
            .background(
                RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                    .fill(Color(rgb: 0x0A1020).opacity(0.97))
                    .overlay(
                        RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                            .strokeBorder(kind.accentColor.opacity(0.45), lineWidth: 1.1)
                    )
            )
            .shadow(color: kind.accentColor.opacity(0.22), radius: 16, y: 8)
            .onTapGesture { }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
        .zIndex(20)
    }
}
