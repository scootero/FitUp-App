//
//  StatsUserStepsTodayHeroCard.swift
//  FitUp
//
//  Profile-neon hero at the top of Stats showing today's steps and intraday timeline.
//

import SwiftUI

struct StatsUserStepsTodayHeroCard: View {
    let stepsToday: Int
    let stepsGoal: Int
    let domain: StatsUserIntradayDomain?
    let isLoading: Bool
    let lastUpdatedAt: Date?
    var onShowMetricExplainer: (StatsMetricExplainerKind) -> Void = { _ in }
    var onEditStepsGoal: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedSteps: Int = 0
    @State private var displayedUpdatedMinutes: Int?
    @State private var introTask: Task<Void, Never>?
    @State private var introTargetSteps: Int = 0

    private let introDuration: Double = 2.5
    private let chartHeight: CGFloat = 104

    /// Prefer the intraday series endpoint when the headline HK read is stale, zero, or failed.
    private var resolvedStepsToday: Int {
        let fromDomain = domain?.liveStepCount ?? 0
        return max(stepsToday, fromDomain)
    }

    private var stepsValueTint: Color {
        BattleStatsTheme.blue
    }

    private var goalMet: Bool {
        stepsGoal > 0 && displayedSteps >= stepsGoal
    }

    var body: some View {
        BattleStatsTheme.battleStatsCard(accent: .cool) {
            VStack(alignment: .leading, spacing: 12) {
                headerRow

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        StatsHeroAnimatedStepCount(
                            value: displayedSteps,
                            tint: stepsValueTint
                        )

                        Text("Actual steps you've taken today")
                            .font(FitUpFont.body(BattleStatsTheme.Typography.bodySmall, weight: .semibold))
                            .foregroundStyle(BattleStatsTheme.textPrimary)
                    }

                    Spacer(minLength: 8)

                    goalCard
                }

                chartSection
            }
        }
        .statsCardMetricInfoCorner(kind: .stepsToday, accent: .cool, onShow: onShowMetricExplainer)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
        .onAppear {
            introTargetSteps = resolvedStepsToday
            runIntroAnimation()
        }
        .onDisappear {
            introTask?.cancel()
        }
        .onChange(of: stepsToday) { _, _ in
            syncDisplayedSteps(animated: introTask == nil)
        }
        .onChange(of: domain) { _, _ in
            syncDisplayedSteps(animated: introTask == nil)
        }
    }

    private var accessibilitySummary: String {
        var parts = ["Your steps today, \(displayedSteps)"]
        if stepsGoal > 0 {
            parts.append("goal \(stepsGoal)")
        }
        return parts.joined(separator: ", ")
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            BattleStatsTheme.sectionTitle("YOUR STEPS TODAY", accent: .cool)
            Spacer(minLength: 8)
        }
    }

    private var goalCard: some View {
        Button(action: onEditStepsGoal) {
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    Group {
                        if goalMet {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(FitUpColors.Neon.green)
                        } else {
                            Image(systemName: "target")
                                .foregroundStyle(BattleStatsTheme.gold)
                        }
                    }
                    .font(.system(size: BattleStatsTheme.Typography.bodySmall, weight: .semibold))

                    Text(stepsGoal > 0 ? "Goal" : "Set goal")
                        .font(FitUpFont.body(BattleStatsTheme.Typography.body, weight: .heavy))
                        .foregroundStyle(BattleStatsTheme.textPrimary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: BattleStatsTheme.Typography.caption, weight: .bold))
                        .foregroundStyle(BattleStatsTheme.gold.opacity(0.85))
                }

                if stepsGoal > 0 {
                    Text(stepsGoal.formatted())
                        .font(FitUpFont.display(21, weight: .heavy))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [BattleStatsTheme.gold, FitUpColors.Neon.yellow.opacity(0.92)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: BattleStatsTheme.gold.opacity(0.45), radius: 6, x: 0, y: 2)
                } else {
                    Text("—")
                        .font(FitUpFont.display(21, weight: .heavy))
                        .foregroundStyle(BattleStatsTheme.gold.opacity(0.7))
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(BattleStatsTheme.gold.opacity(0.12))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(BattleStatsTheme.gold.opacity(0.32), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(stepsGoal > 0 ? "Daily step goal \(stepsGoal), tap to edit" : "Set daily step goal")
    }

    private var chartMetadataRow: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Text("Updated: \(updatedRelativeLabel(relativeTo: context.date))")
                .font(FitUpFont.body(11, weight: .medium))
                .foregroundStyle(BattleStatsTheme.textLabel.opacity(0.45))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    private func updatedRelativeLabel(relativeTo now: Date = Date()) -> String {
        guard let lastUpdatedAt else { return "updating…" }
        let minutes: Int
        if introTask != nil, let displayedUpdatedMinutes {
            minutes = displayedUpdatedMinutes
        } else {
            minutes = max(0, Int(now.timeIntervalSince(lastUpdatedAt) / 60))
        }
        if minutes < 1 {
            return "<1 min ago"
        }
        if minutes == 1 {
            return "1 min ago"
        }
        return "\(minutes) min ago"
    }

    @ViewBuilder
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isLoading, domain == nil {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(FitUpColors.Neon.cyan)
                    Text("Updating...")
                        .font(FitUpFont.body(BattleStatsTheme.Typography.bodySmall, weight: .semibold))
                        .foregroundStyle(BattleStatsTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, minHeight: chartHeight, alignment: .center)
            } else if let domain {
                StatsUserIntradayTimelineChart(
                    domain: domain,
                    stepsGoal: stepsGoal,
                    liveStepsToday: resolvedStepsToday
                )
            } else {
                StatsUserIntradayTimelineChart(
                    domain: StatsUserIntradayDomain(
                        points: [],
                        dayStart: Date(),
                        dayEnd: Date().addingTimeInterval(86_400),
                        now: Date()
                    ),
                    stepsGoal: stepsGoal,
                    liveStepsToday: resolvedStepsToday
                )
            }

            chartMetadataRow
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 2)
        }
    }

    private func minutesSince(_ date: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(date) / 60))
    }

    private func syncDisplayedSteps(animated: Bool) {
        let target = resolvedStepsToday
        introTargetSteps = target

        guard introTask == nil else { return }

        let from = displayedSteps
        guard target != from else { return }

        if animated {
            animateSteps(from: from, to: target)
        } else {
            displayedSteps = target
        }
    }

    private func runIntroAnimation() {
        introTask?.cancel()
        introTask = nil

        let targetMinutes = lastUpdatedAt.map { minutesSince($0) }
        let startMinutes = max((targetMinutes ?? 0) + 3, 5)
        introTargetSteps = resolvedStepsToday

        if reduceMotion {
            displayedSteps = introTargetSteps
            displayedUpdatedMinutes = targetMinutes
            return
        }

        displayedSteps = 0
        displayedUpdatedMinutes = startMinutes

        let frames = 25
        introTask = Task { @MainActor in
            defer { introTask = nil }

            for frame in 0 ... frames {
                if Task.isCancelled { return }

                let progress = Double(frame) / Double(frames)
                let eased = progress * progress * progress
                let targetSteps = introTargetSteps

                displayedSteps = Int((Double(targetSteps) * eased).rounded(.down))

                if let targetMinutes {
                    let interpolated = Double(startMinutes) + (Double(targetMinutes) - Double(startMinutes)) * eased
                    displayedUpdatedMinutes = max(0, Int(interpolated.rounded()))
                }

                if frame < frames {
                    try? await Task.sleep(nanoseconds: UInt64(introDuration / Double(frames) * 1_000_000_000))
                }
            }

            displayedSteps = introTargetSteps
            displayedUpdatedMinutes = targetMinutes
        }
    }

    private func animateSteps(from oldValue: Int, to newValue: Int) {
        if reduceMotion {
            displayedSteps = newValue
        } else if newValue != oldValue {
            withAnimation(.linear(duration: 0.65)) {
                displayedSteps = newValue
            }
        }
    }
}

// MARK: - Animated gradient step count

private struct StatsHeroAnimatedStepCount: View {
    let value: Int
    let tint: Color

    var body: some View {
        Text(value, format: .number)
            .font(FitUpFont.display(36, weight: .heavy))
            .foregroundStyle(tint)
            .shadow(color: tint.opacity(0.45), radius: 6)
            .contentTransition(.numericText(countsDown: false))
            .animation(.linear(duration: 0.65), value: value)
    }
}
