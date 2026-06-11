//
//  StatsUserStepsTodayHeroCard.swift
//  FitUp
//
//  Profile-neon hero at the top of Stats showing today's steps and intraday timeline.
//

import SwiftUI

struct StatsUserStepsTodayHeroCard: View {
    let profileId: UUID?
    let profileTimeZoneIdentifier: String?
    let stepsToday: Int
    let stepsGoal: Int
    let domain: StatsUserIntradayDomain?
    let isLoading: Bool
    let lastUpdatedAt: Date?
    var onShowMetricExplainer: (StatsMetricExplainerKind) -> Void = { _ in }
    var onEditStepsGoal: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var displayedStepsValue: Double = 0
    @State private var displayedNowFraction: CGFloat = 0
    @State private var tailOriginSteps: Double = 0
    @State private var tailOriginFraction: CGFloat = 0
    @State private var catchUpTask: Task<Void, Never>?
    @State private var didSeedFromCache = false
    @State private var didCompleteInitialCatchUp = false

    private let catchUpDuration: Double = 2.4
    private let chartHeight: CGFloat = 104

    private var displayedStepsRounded: Int {
        max(0, Int(displayedStepsValue.rounded()))
    }

    /// Prefer the intraday series endpoint when the headline HK read is stale, zero, or failed.
    private var resolvedStepsToday: Int {
        let fromDomain = domain?.liveStepCount ?? 0
        return max(stepsToday, fromDomain)
    }

    private var resolvedNowFraction: CGFloat {
        domain?.nowFraction ?? displayedNowFraction
    }

    private var localDate: String {
        StatsStepsTodayLastDisplayedStore.localDateString(
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )
    }

    private var hasCachedDisplay: Bool {
        guard let profileId else { return false }
        return StatsStepsTodayLastDisplayedStore.load(profileId: profileId, localDate: localDate) != nil
    }

    /// Avoid catch-up until HealthKit / intraday data has landed so cached steps are not animated toward zero.
    private var hasLiveStepsRead: Bool {
        domain != nil || stepsToday > 0 || lastUpdatedAt != nil
    }

    private var stepsValueTint: Color {
        BattleStatsTheme.blue
    }

    var body: some View {
        BattleStatsTheme.battleStatsCard(accent: .cool) {
            VStack(alignment: .leading, spacing: 12) {
                headerRow

                VStack(alignment: .leading, spacing: 6) {
                    StatsSmoothStepCount(
                        value: displayedStepsValue,
                        fontSize: 36,
                        tint: stepsValueTint
                    )

                    HStack {
                        Spacer(minLength: 0)
                        StatsCompactGoalChip(
                            stepsGoal: stepsGoal,
                            goalMet: stepsGoal > 0 && displayedStepsRounded >= stepsGoal,
                            action: onEditStepsGoal
                        )
                    }
                }

                chartSection
            }
        }
        .statsCardMetricInfoCorner(kind: .stepsToday, accent: .cool, onShow: onShowMetricExplainer)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
        .onAppear {
            seedDisplayedValuesIfNeeded()
            scheduleCatchUpAnimation()
        }
        .onDisappear {
            catchUpTask?.cancel()
            persistDisplayedSnapshot()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .inactive || phase == .background {
                persistDisplayedSnapshot()
            }
        }
        .onChange(of: stepsToday) { _, _ in
            handleLiveStepsUpdate()
        }
        .onChange(of: domain) { _, _ in
            if !didSeedFromCache {
                seedDisplayedValuesIfNeeded()
            }
            handleLiveStepsUpdate()
        }
        .onChange(of: lastUpdatedAt) { _, _ in
            handleLiveStepsUpdate()
        }
        .onChange(of: profileId) { _, _ in
            catchUpTask?.cancel()
            didSeedFromCache = false
            didCompleteInitialCatchUp = false
            seedDisplayedValuesIfNeeded()
            handleLiveStepsUpdate()
        }
    }

    private var accessibilitySummary: String {
        var parts = ["Your steps today, \(displayedStepsRounded)"]
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
        let minutes = max(0, Int(now.timeIntervalSince(lastUpdatedAt) / 60))
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
            if isLoading, domain == nil, !hasCachedDisplay, displayedStepsRounded == 0 {
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
                    liveStepsToday: resolvedStepsToday,
                    displayedStepsValue: displayedStepsValue,
                    displayedNowFraction: displayedNowFraction,
                    tailOriginSteps: tailOriginSteps,
                    tailOriginFraction: tailOriginFraction
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
                    liveStepsToday: resolvedStepsToday,
                    displayedStepsValue: displayedStepsValue,
                    displayedNowFraction: displayedNowFraction,
                    tailOriginSteps: tailOriginSteps,
                    tailOriginFraction: tailOriginFraction
                )
            }

            chartMetadataRow
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 2)
        }
    }

    private func seedDisplayedValuesIfNeeded() {
        guard !didSeedFromCache else { return }

        if let profileId,
           let cached = StatsStepsTodayLastDisplayedStore.load(profileId: profileId, localDate: localDate) {
            displayedStepsValue = Double(cached.steps)
            displayedNowFraction = CGFloat(min(1, max(0, cached.nowFraction)))
        } else {
            displayedStepsValue = Double(resolvedStepsToday)
            displayedNowFraction = resolvedNowFraction
        }

        tailOriginSteps = displayedStepsValue
        tailOriginFraction = displayedNowFraction
        didSeedFromCache = true
    }

    private func handleLiveStepsUpdate() {
        guard hasLiveStepsRead else { return }

        if !didCompleteInitialCatchUp {
            scheduleCatchUpAnimation()
            return
        }

        syncDisplayedValues(animated: catchUpTask == nil)
    }

    private func syncDisplayedValues(animated: Bool) {
        guard catchUpTask == nil else { return }

        let targetSteps = Double(resolvedStepsToday)
        let targetFraction = resolvedNowFraction

        let stepsChanged = abs(targetSteps - displayedStepsValue) > 0.5
        let fractionChanged = abs(targetFraction - displayedNowFraction) > 0.0005
        guard stepsChanged || fractionChanged else { return }

        if animated, !reduceMotion {
            runCatchUpAnimation(toSteps: targetSteps, toFraction: targetFraction)
        } else {
            displayedStepsValue = targetSteps
            displayedNowFraction = targetFraction
            tailOriginSteps = targetSteps
            tailOriginFraction = targetFraction
        }
    }

    private func scheduleCatchUpAnimation() {
        guard hasLiveStepsRead else { return }
        runCatchUpAnimation(
            toSteps: Double(resolvedStepsToday),
            toFraction: resolvedNowFraction
        )
    }

    private func runCatchUpAnimation(toSteps targetSteps: Double, toFraction targetFraction: CGFloat) {
        catchUpTask?.cancel()
        catchUpTask = nil

        tailOriginSteps = displayedStepsValue
        tailOriginFraction = displayedNowFraction

        let startSteps = displayedStepsValue
        let startFraction = displayedNowFraction
        let stepsDelta = targetSteps - startSteps
        let fractionDelta = targetFraction - startFraction

        if abs(stepsDelta) < 0.5, abs(fractionDelta) < 0.0005 {
            displayedStepsValue = targetSteps
            displayedNowFraction = targetFraction
            tailOriginSteps = targetSteps
            tailOriginFraction = targetFraction
            didCompleteInitialCatchUp = true
            return
        }

        if reduceMotion {
            displayedStepsValue = targetSteps
            displayedNowFraction = targetFraction
            tailOriginSteps = targetSteps
            tailOriginFraction = targetFraction
            didCompleteInitialCatchUp = true
            return
        }

        catchUpTask = Task { @MainActor in
            defer { catchUpTask = nil }

            let tickNanos: UInt64 = 1_000_000_000 / 120
            let startedAt = Date()
            var latestTargetSteps = targetSteps
            var latestTargetFraction = targetFraction

            while !Task.isCancelled {
                latestTargetSteps = Double(resolvedStepsToday)
                latestTargetFraction = resolvedNowFraction

                let elapsed = Date().timeIntervalSince(startedAt)
                let progress = min(1, max(0, elapsed / catchUpDuration))

                let stepDeltaNow = latestTargetSteps - startSteps
                let fractionDeltaNow = latestTargetFraction - startFraction

                displayedStepsValue = startSteps + stepDeltaNow * progress
                displayedNowFraction = startFraction + fractionDeltaNow * progress

                if progress >= 1 { break }
                try? await Task.sleep(nanoseconds: tickNanos)
            }

            if Task.isCancelled { return }

            displayedStepsValue = latestTargetSteps
            displayedNowFraction = latestTargetFraction
            tailOriginSteps = latestTargetSteps
            tailOriginFraction = latestTargetFraction
            didCompleteInitialCatchUp = true
        }
    }

    private func persistDisplayedSnapshot() {
        guard let profileId else { return }
        StatsStepsTodayLastDisplayedStore.save(
            steps: displayedStepsRounded,
            nowFraction: Double(displayedNowFraction),
            profileId: profileId,
            localDate: localDate
        )
    }
}

// MARK: - Smooth step count (no per-digit flip)

struct StatsSmoothStepCount: View {
    let value: Double
    var fontSize: CGFloat = 36
    let tint: Color

    var body: some View {
        Text(max(0, Int(value.rounded())), format: .number)
            .font(FitUpFont.display(fontSize, weight: .heavy))
            .foregroundStyle(tint)
            .shadow(color: tint.opacity(fontSize >= 30 ? 0.45 : 0.35), radius: fontSize >= 30 ? 6 : 4)
            .monospacedDigit()
    }
}
