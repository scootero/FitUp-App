//
//  MatchDetailsView.swift
//  FitUp
//
//  Match Details — v2 layout for active/completed; legacy pending UI preserved.
//

import SwiftUI

struct MatchDetailsView: View {
    var onClose: () -> Void
    var onRematch: (ChallengeLaunchContext) -> Void

    @StateObject private var viewModel: MatchDetailsViewModel
    @State private var showingLiveMatch = false
    @State private var hoveredDayBreakdownDayNumber: Int?
    @State private var tappedDayBreakdownDayNumber: Int?
    private let profile: Profile?

    private var activeBreakdownDayNumber: Int? {
        hoveredDayBreakdownDayNumber ?? tappedDayBreakdownDayNumber
    }

    init(
        matchId: UUID,
        profile: Profile?,
        onClose: @escaping () -> Void,
        onRematch: @escaping (ChallengeLaunchContext) -> Void
    ) {
        self.onClose = onClose
        self.onRematch = onRematch
        self.profile = profile
        _viewModel = StateObject(
            wrappedValue: MatchDetailsViewModel(
                matchId: matchId,
                profile: profile,
                detailsRepository: MatchDetailsRepository(),
                homeRepository: HomeRepository()
            )
        )
    }

    var body: some View {
        ZStack {
            BackgroundGradientView()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    topBar

                    if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(FitUpFont.body(12, weight: .semibold))
                            .foregroundStyle(FitUpColors.Neon.pink)
                            .padding(.horizontal, 4)
                    }

                    if let snapshot = viewModel.snapshot, snapshot.state == .pending {
                        legacyPendingHero(snapshot: snapshot)
                    } else if let dm = viewModel.displayModel, dm.snapshot.state != .pending {
                        activeCompletedContent(dm: dm)
                    } else if viewModel.isLoading, viewModel.snapshot == nil {
                        ProgressView("Loading match...")
                            .font(FitUpFont.body(14, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.secondary)
                            .tint(FitUpColors.Neon.cyan)
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard(.base)
                    } else {
                        Text("Match unavailable.")
                            .font(FitUpFont.body(14, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.secondary)
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard(.base)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .task {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
        .fullScreenCover(isPresented: $showingLiveMatch) {
            LiveMatchView(
                matchId: viewModel.matchId,
                profile: profile
            ) {
                showingLiveMatch = false
            }
        }
        .screenTransition()
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                onClose()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FitUpColors.Neon.cyan)
            }
            .buttonStyle(.plain)

            Spacer()

            if let shareURL = URL(string: "https://fitup.app/match/\(viewModel.matchId.uuidString)") {
                ShareLink(item: shareURL) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.secondary)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Pending (legacy)

    private func legacyPendingHero(snapshot: MatchDetailsSnapshot) -> some View {
        let accent = accentColor(for: snapshot)
        let heroVariant = glassVariant(for: snapshot)
        let isPending = true

        return VStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.55), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)

            VStack(spacing: 12) {
                NeonBadge(
                    label: badgeLabel(for: snapshot),
                    color: isPending ? FitUpColors.Neon.blue : accent
                )

                HStack(alignment: .center, spacing: 8) {
                    VStack(spacing: 6) {
                        AvatarView(
                            initials: snapshot.me.initials,
                            color: FitUpColors.Neon.cyan,
                            size: 52,
                            glow: false
                        )
                        Text("You")
                            .font(FitUpFont.display(14, weight: .bold))
                            .foregroundStyle(FitUpColors.Text.primary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 5) {
                        Text("VS")
                            .font(FitUpFont.display(20, weight: .black))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [accent, accent.opacity(0.55)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }

                    VStack(spacing: 6) {
                        AvatarView(
                            initials: snapshot.opponent.initials,
                            color: color(from: snapshot.opponent.colorHex),
                            size: 52,
                            glow: false
                        )
                        Text(snapshot.opponent.displayName)
                            .font(FitUpFont.display(14, weight: .bold))
                            .foregroundStyle(FitUpColors.Text.primary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }

                pendingActions(snapshot: snapshot)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .glassCard(heroVariant)
    }

    @ViewBuilder
    private func pendingActions(snapshot: MatchDetailsSnapshot) -> some View {
        if snapshot.canRespondToPending {
            HStack(spacing: 10) {
                Button {
                    Task {
                        let shouldClose = await viewModel.declinePendingChallenge()
                        if shouldClose {
                            onClose()
                        }
                    }
                } label: {
                    Text("Decline")
                        .font(FitUpFont.body(14, weight: .bold))
                        .foregroundStyle(FitUpColors.Neon.pink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                                .fill(FitUpColors.Neon.pink.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                                        .strokeBorder(FitUpColors.Neon.pink.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)

                Button {
                    Task { await viewModel.acceptPendingChallenge() }
                } label: {
                    Label("Accept Challenge", systemImage: "bolt.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .solidButton(color: FitUpColors.Neon.cyan)
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.isSubmittingAction)
            .opacity(viewModel.isSubmittingAction ? 0.65 : 1)
        } else {
            Text("Waiting for both players to accept.")
                .font(FitUpFont.body(12, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }

    private func badgeLabel(for snapshot: MatchDetailsSnapshot) -> String {
        let core = "\(snapshot.sportLabel.uppercased()) · \(snapshot.seriesLabel.uppercased())"
        if snapshot.state == .pending {
            return "INCOMING · \(core)"
        }
        return core
    }

    private func accentColor(for snapshot: MatchDetailsSnapshot) -> Color {
        if snapshot.state == .pending { return FitUpColors.Neon.blue }
        return snapshot.isWinning ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange
    }

    private func glassVariant(for snapshot: MatchDetailsSnapshot) -> GlassCardVariant {
        if snapshot.state == .pending { return .base }
        return snapshot.isWinning ? .win : .lose
    }

    // MARK: - Active / completed v2

    @ViewBuilder
    private func activeCompletedContent(dm: MatchDetailDisplayModel) -> some View {
        metaPillsRow(dm: dm)
        heroCardV2(dm: dm)
        if dm.snapshot.state == .active {
            todayBattleRow(dm: dm)
            alertBanner(dm: dm)
        }
        if dm.snapshot.state == .active, !viewModel.intradaySeries.isEmpty {
            IntradayCumulativeChartView(
                points: viewModel.intradaySeries,
                opponentTotal: dm.theirToday,
                isCalories: dm.metricIsCalories,
                opponentColor: color(from: dm.snapshot.opponent.colorHex)
            )
        }
        dayByDayChart(dm: dm)
        matchStatsSection(dm: dm)
        headToHeadCard(dm: dm)
        actionButtons(dm: dm)
    }

    private func metaPillsRow(dm: MatchDetailDisplayModel) -> some View {
        HStack(spacing: 6) {
            Text(dm.metricPillLabel)
                .font(FitUpFont.body(10, weight: .heavy))
                .foregroundStyle(dm.metricIsCalories ? FitUpColors.Neon.yellow : FitUpColors.Neon.cyan)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(dm.metricIsCalories ? FitUpColors.Neon.yellow.opacity(0.08) : FitUpColors.Neon.cyan.opacity(0.08))
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    dm.metricIsCalories ? FitUpColors.Neon.yellow.opacity(0.25) : FitUpColors.Neon.cyan.opacity(0.25),
                                    lineWidth: 1
                                )
                        )
                )

            Text(dm.formatDurationPill)
                .font(FitUpFont.body(10, weight: .heavy))
                .foregroundStyle(FitUpColors.Text.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                )

            if dm.snapshot.state == .active {
                HStack(spacing: 5) {
                    Circle()
                        .fill(FitUpColors.Neon.green)
                        .frame(width: 7, height: 7)
                        .shadow(color: FitUpColors.Neon.green.opacity(0.6), radius: 4)
                    Text("LIVE")
                        .font(FitUpFont.body(10, weight: .heavy))
                        .foregroundStyle(FitUpColors.Neon.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(FitUpColors.Neon.greenDim)
                        .overlay(Capsule().strokeBorder(FitUpColors.Neon.green.opacity(0.25), lineWidth: 1))
                )
            }
        }
    }

    private func heroCardV2(dm: MatchDetailDisplayModel) -> some View {
        let variant = dm.glassVariant
        let accent = dm.isAheadToday ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange
        return VStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.55), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Text(dm.statusLabel)
                        .font(FitUpFont.body(10, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(dm.isAheadToday ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange)

                    Spacer()

                    Text(dm.dayBadgeLabel)
                        .font(FitUpFont.mono(10, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                }

                HStack(alignment: .top, spacing: 6) {
                    playerHeroColumn(
                        name: "You",
                        initials: dm.snapshot.me.initials,
                        border: FitUpColors.Neon.cyan,
                        score: dm.snapshot.myScore,
                        today: dm.myTodayDisplay,
                        win: dm.myTodayDisplay >= dm.theirToday,
                        pulse: dm.snapshot.state == .active,
                        staleHint: dm.healthKitStale ? "May be stale" : nil
                    )

                    VStack(spacing: 4) {
                        Spacer().frame(height: 28)
                        Text("VS")
                            .font(FitUpFont.display(15, weight: .heavy))
                            .foregroundStyle(FitUpColors.Text.tertiary)
                            .tracking(2)
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 1, height: 24)
                    }
                    .frame(width: 28)

                    playerHeroColumn(
                        name: dm.snapshot.opponent.displayName,
                        initials: dm.snapshot.opponent.initials,
                        border: color(from: dm.snapshot.opponent.colorHex),
                        score: dm.snapshot.theirScore,
                        today: dm.theirToday,
                        win: dm.theirToday > dm.myTodayDisplay,
                        pulse: false,
                        staleHint: nil
                    )
                }

                if let sync = dm.lastSyncedRelativeLabel {
                    Text(sync)
                        .font(FitUpFont.mono(9, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                recordDotsRow(dm: dm)

                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, geo.size.width * dm.seriesProgressFraction))
                        }
                    }
                    .frame(height: 5)

                    HStack {
                        Text(dm.daysRemainingLabel)
                            .font(FitUpFont.mono(9, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.tertiary)
                        Spacer()
                        Text(dm.percentCompleteLabel)
                            .font(FitUpFont.mono(9, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.tertiary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .glassCard(variant)
    }

    private func playerHeroColumn(
        name: String,
        initials: String,
        border: Color,
        score: Int,
        today: Int,
        win: Bool,
        pulse: Bool,
        staleHint: String?
    ) -> some View {
        VStack(spacing: 6) {
            ZStack {
                if pulse {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(FitUpColors.Neon.cyan.opacity(0.28), lineWidth: 2)
                        .frame(width: 64, height: 64)
                }
                AvatarView(initials: initials, color: border, size: 54, glow: pulse)
            }
            Text(name)
                .font(FitUpFont.body(12, weight: .bold))
                .foregroundStyle(FitUpColors.Text.primary)
                .lineLimit(1)

            Text("\(score)")
                .font(FitUpFont.display(56, weight: .black))
                .foregroundStyle(FitUpColors.Text.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text("\(today)")
                .font(FitUpFont.mono(11, weight: .bold))
                .foregroundStyle(win ? FitUpColors.Neon.cyan : FitUpColors.Neon.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(win ? FitUpColors.Neon.cyan.opacity(0.1) : FitUpColors.Neon.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(
                                    win ? FitUpColors.Neon.cyan.opacity(0.2) : FitUpColors.Neon.red.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                )

            if let staleHint {
                Text(staleHint)
                    .font(FitUpFont.mono(8, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func recordDotsRow(dm: MatchDetailDisplayModel) -> some View {
        HStack(spacing: 5) {
            ForEach(dm.mergedDayRows) { day in
                recordDot(day: day, dm: dm)
            }
        }
    }

    private func recordDot(day: MatchDetailsDayRow, dm: MatchDetailDisplayModel) -> some View {
        let label: String
        let bg: Color
        let fg: Color
        if day.isFuture {
            label = "F"
            bg = Color.white.opacity(0.04)
            fg = FitUpColors.Text.tertiary
        } else if day.isToday {
            label = "NOW"
            bg = Color.white.opacity(0.08)
            fg = FitUpColors.Text.secondary
        } else if day.isTie {
            label = "T"
            bg = Color.white.opacity(0.06)
            fg = FitUpColors.Text.tertiary
        } else if day.myWon == true {
            label = "W"
            bg = FitUpColors.Neon.cyan.opacity(0.15)
            fg = FitUpColors.Neon.cyan
        } else if day.myWon == false {
            label = "L"
            bg = FitUpColors.Neon.orange.opacity(0.15)
            fg = FitUpColors.Neon.orange
        } else {
            label = "·"
            bg = Color.white.opacity(0.06)
            fg = FitUpColors.Text.tertiary
        }

        return Text(label)
            .font(FitUpFont.body(9, weight: .heavy))
            .foregroundStyle(fg)
            .frame(minWidth: 22, minHeight: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(bg))
    }

    private func todayBattleRow(dm: MatchDetailDisplayModel) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dm.metricIsCalories ? "ACTIVE CALORIES" : "STEPS TODAY")
                    .font(FitUpFont.body(10, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(FitUpColors.Text.tertiary)

                Text("\(dm.myTodayDisplay)")
                    .font(FitUpFont.display(26, weight: .heavy))
                    .foregroundStyle(dm.isAheadToday ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange)

                Text(dm.todayDeltaLabel)
                    .font(FitUpFont.body(12, weight: .bold))
                    .foregroundStyle(dm.todayDelta >= 0 ? FitUpColors.Neon.cyan : FitUpColors.Neon.red)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(FitUpColors.Neon.green)
                        .frame(width: 7, height: 7)
                    Text("LIVE")
                        .font(FitUpFont.body(11, weight: .heavy))
                        .foregroundStyle(FitUpColors.Neon.green)
                }
                Text("\(dm.theirToday)")
                    .font(FitUpFont.display(20, weight: .heavy))
                    .foregroundStyle(FitUpColors.Neon.orange)
                Text(dm.snapshot.opponent.displayName)
                    .font(FitUpFont.body(11, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func alertBanner(dm: MatchDetailDisplayModel) -> some View {
        let winning = dm.isAheadToday
        return HStack(alignment: .top, spacing: 10) {
            Text(winning ? "✓" : "!")
                .font(FitUpFont.body(16, weight: .bold))
            Text(winning ? dm.winningAlertText : dm.losingAlertText)
                .font(FitUpFont.body(12, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(winning ? FitUpColors.Neon.cyan.opacity(0.06) : FitUpColors.Neon.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            winning ? FitUpColors.Neon.cyan.opacity(0.18) : FitUpColors.Neon.orange.opacity(0.2),
                            lineWidth: 1
                        )
                )
        )
    }

    private func formatBreakdownMetricValue(_ value: Int, calories: Bool) -> String {
        if calories {
            return "\(value.formatted()) kcal"
        }
        return value.formatted()
    }

    @ViewBuilder
    private func dayBreakdownCallout(day: MatchDetailsDayRow, dm: MatchDetailDisplayModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(MatchDurationCopy.dayProgress(current: day.dayNumber, total: dm.snapshot.durationDays))
                .font(FitUpFont.body(10, weight: .heavy))
                .foregroundStyle(FitUpColors.Text.tertiary)
            if day.isFuture {
                Text("Not started yet.")
                    .font(FitUpFont.body(12, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
            } else {
                HStack {
                    Text("You")
                        .font(FitUpFont.body(12, weight: .semibold))
                        .foregroundStyle(FitUpColors.Neon.cyan)
                    Spacer()
                    Text(formatBreakdownMetricValue(dm.myValue(for: day), calories: dm.metricIsCalories))
                        .font(FitUpFont.mono(12, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.primary)
                }
                HStack {
                    Text(dm.opponentFirstName)
                        .font(FitUpFont.body(12, weight: .semibold))
                        .foregroundStyle(color(from: dm.snapshot.opponent.colorHex))
                    Spacer()
                    Text(formatBreakdownMetricValue(day.theirValue, calories: dm.metricIsCalories))
                        .font(FitUpFont.mono(12, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.primary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func dayBreakdownAccessibilityLabel(day: MatchDetailsDayRow, dm: MatchDetailDisplayModel) -> String {
        let progress = MatchDurationCopy.dayProgress(current: day.dayNumber, total: dm.snapshot.durationDays)
        if day.isFuture {
            return "\(progress), not started yet"
        }
        let mine = formatBreakdownMetricValue(dm.myValue(for: day), calories: dm.metricIsCalories)
        let theirs = formatBreakdownMetricValue(day.theirValue, calories: dm.metricIsCalories)
        return "\(progress), you \(mine), \(dm.opponentFirstName) \(theirs)"
    }

    private func dayByDayChart(dm: MatchDetailDisplayModel) -> some View {
        let opponentTint = color(from: dm.snapshot.opponent.colorHex)
        return VStack(alignment: .leading, spacing: 14) {
            Text("DAY-BY-DAY BREAKDOWN")
                .font(FitUpFont.body(10, weight: .heavy))
                .tracking(2)
                .foregroundStyle(FitUpColors.Text.tertiary)

            if let dayNum = activeBreakdownDayNumber,
               let row = dm.mergedDayRows.first(where: { $0.dayNumber == dayNum }) {
                dayBreakdownCallout(day: row, dm: dm)
            }

            GeometryReader { outer in
                let dayCount = max(dm.mergedDayRows.count, 1)
                let slotW = outer.size.width / CGFloat(dayCount)
                let barW = max(10, min(slotW * (dayCount == 1 ? 0.36 : 0.20), 58))
                let maxH: CGFloat = 80
                VStack(spacing: 8) {
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(dm.mergedDayRows) { day in
                            let isColumnHighlighted =
                                hoveredDayBreakdownDayNumber == day.dayNumber
                                || tappedDayBreakdownDayNumber == day.dayNumber
                            VStack(spacing: 0) {
                                HStack(alignment: .bottom, spacing: 3) {
                                    if day.isFuture {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(Color.white.opacity(0.06))
                                            .frame(width: barW, height: maxH)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                    .strokeBorder(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                            )
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(Color.white.opacity(0.06))
                                            .frame(width: barW, height: maxH)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                    .strokeBorder(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                            )
                                    } else {
                                        let h = max(3, CGFloat(Double(dm.myValue(for: day)) / dm.chartMaxValue) * maxH)
                                        let th = max(3, CGFloat(Double(day.theirValue) / dm.chartMaxValue) * maxH)
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(FitUpColors.Neon.cyan.opacity(0.85))
                                            .frame(width: barW, height: h)
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(opponentTint.opacity(0.85))
                                            .frame(width: barW, height: th)
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(isColumnHighlighted ? Color.white.opacity(0.06) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(
                                            Color.white.opacity(isColumnHighlighted ? 0.22 : 0),
                                            lineWidth: 1
                                        )
                                )
                                .frame(height: maxH, alignment: .bottom)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if tappedDayBreakdownDayNumber == day.dayNumber {
                                    tappedDayBreakdownDayNumber = nil
                                } else {
                                    tappedDayBreakdownDayNumber = day.dayNumber
                                }
                            }
                            .onHover { inside in
                                if inside {
                                    hoveredDayBreakdownDayNumber = day.dayNumber
                                } else if hoveredDayBreakdownDayNumber == day.dayNumber {
                                    hoveredDayBreakdownDayNumber = nil
                                }
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(dayBreakdownAccessibilityLabel(day: day, dm: dm))
                            .accessibilityHint(
                                dm.metricIsCalories
                                    ? "Tap to show or hide active calorie totals for this day."
                                    : "Tap to show or hide step totals for this day."
                            )
                            .accessibilityAddTraits(.isButton)
                        }
                    }
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(dm.mergedDayRows) { day in
                            Text(day.dayLabel)
                                .font(FitUpFont.mono(9, weight: .medium))
                                .foregroundStyle(FitUpColors.Text.tertiary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .frame(height: 110)

            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(FitUpColors.Neon.cyan)
                        .frame(width: 10, height: 10)
                    Text("You")
                        .font(FitUpFont.body(11, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(opponentTint)
                        .frame(width: 10, height: 10)
                    Text(dm.snapshot.opponent.displayName)
                        .font(FitUpFont.body(11, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.top, 10)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .offset(y: -10)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func matchStatsSection(dm: MatchDetailDisplayModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MATCH STATS")
                .font(FitUpFont.body(11, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(FitUpColors.Text.tertiary)
                .padding(.horizontal, 4)

            HStack(spacing: 8) {
                statHeaderPill(text: "You", tint: FitUpColors.Neon.cyan)
                statHeaderPill(text: "\(dm.opponentFirstName)'s", tint: FitUpColors.Neon.orange)
            }

            statStatRow(
                title: "Daily Avg",
                left: formatStatNumber(dm.dailyAverageMine, calories: dm.metricIsCalories),
                right: formatStatNumber(dm.dailyAverageTheirs, calories: dm.metricIsCalories)
            )
            statStatRow(
                title: "Best Day",
                left: "\(dm.bestDayMine)",
                right: "\(dm.bestDayTheirs)"
            )
            statStatRow(
                title: dm.metricIsCalories ? "Total Calories" : "Total Steps",
                left: "\(dm.totalMine)",
                right: "\(dm.totalTheirs)"
            )
            statStatRow(
                title: "Days Won · Win %",
                left: "\(dm.daysWonFractionLabel) · \(Int(dm.winRateMinePercent.rounded()))%",
                right: "\(MatchDurationCopy.daysWonFraction(won: dm.snapshot.theirScore, totalDays: dm.snapshot.durationDays)) · \(Int(dm.winRateTheirsPercent.rounded()))%"
            )
        }
    }

    private func statHeaderPill(text: String, tint: Color) -> some View {
        Text(text.uppercased())
            .font(FitUpFont.body(11, weight: .heavy))
            .tracking(1)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(tint.opacity(0.2), lineWidth: 1)
                    )
            )
    }

    private func statStatRow(title: String, left: String, right: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(FitUpFont.body(9, weight: .heavy))
                .foregroundStyle(FitUpColors.Text.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                Text(left)
                    .font(FitUpFont.display(22, weight: .heavy))
                    .foregroundStyle(FitUpColors.Neon.cyan)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(12)
                    .background(statCellBackground(cyan: true))
                Text(right)
                    .font(FitUpFont.display(22, weight: .heavy))
                    .foregroundStyle(FitUpColors.Neon.orange)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(12)
                    .background(statCellBackground(cyan: false))
            }
        }
    }

    private func statCellBackground(cyan: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(cyan ? FitUpColors.Neon.cyan.opacity(0.04) : FitUpColors.Neon.orange.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        cyan ? FitUpColors.Neon.cyan.opacity(0.14) : FitUpColors.Neon.orange.opacity(0.14),
                        lineWidth: 1
                    )
            )
    }

    private func formatStatNumber(_ value: Double, calories: Bool) -> String {
        if calories {
            return String(format: "%.0f", value)
        }
        return String(format: "%.0f", value)
    }

    private func headToHeadCard(dm: MatchDetailDisplayModel) -> some View {
        let fr = dm.headToHeadBarFractions
        return VStack(alignment: .leading, spacing: 12) {
            Text("ALL-TIME VS \(dm.snapshot.opponent.displayName.uppercased())")
                .font(FitUpFont.body(10, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(FitUpColors.Text.tertiary)

            if let h = dm.headToHead {
                HStack {
                    VStack {
                        Text("\(h.viewerWins)")
                            .font(FitUpFont.display(32, weight: .heavy))
                            .foregroundStyle(FitUpColors.Neon.cyan)
                        Text("You")
                            .font(FitUpFont.body(11, weight: .semibold))
                            .foregroundStyle(FitUpColors.Text.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    VStack {
                        Text("\(h.seriesTies)")
                            .font(FitUpFont.display(32, weight: .heavy))
                            .foregroundStyle(FitUpColors.Text.secondary)
                        Text("Ties")
                            .font(FitUpFont.body(11, weight: .semibold))
                            .foregroundStyle(FitUpColors.Text.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    VStack {
                        Text("\(h.opponentWins)")
                            .font(FitUpFont.display(32, weight: .heavy))
                            .foregroundStyle(FitUpColors.Neon.orange)
                        Text("Them")
                            .font(FitUpFont.body(11, weight: .semibold))
                            .foregroundStyle(FitUpColors.Text.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                GeometryReader { geo in
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(FitUpColors.Neon.cyan.opacity(0.85))
                            .frame(width: geo.size.width * fr.mine)
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: geo.size.width * fr.tie)
                        Rectangle()
                            .fill(FitUpColors.Neon.orange.opacity(0.85))
                            .frame(width: geo.size.width * fr.theirs)
                    }
                }
                .frame(height: 8)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                Text("Loading history…")
                    .font(FitUpFont.body(12, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func actionButtons(dm: MatchDetailDisplayModel) -> some View {
        HStack(spacing: 10) {
            if dm.snapshot.state == .active {
                Button {
                    showingLiveMatch = true
                } label: {
                    Text(dm.primaryCTATitle)
                        .font(FitUpFont.body(14, weight: .heavy))
                        .foregroundStyle(FitUpColors.Text.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .solidButton(color: FitUpColors.Neon.cyan)
            }

            if dm.snapshot.state == .completed {
                Button {
                    if let context = viewModel.makeRematchLaunchContext() {
                        onRematch(context)
                    }
                } label: {
                    Text("Rematch")
                        .font(FitUpFont.body(14, weight: .bold))
                        .foregroundStyle(FitUpColors.Neon.cyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .ghostButton(color: FitUpColors.Neon.cyan)
            } else if dm.snapshot.state == .active {
                Button {
                    if let context = viewModel.makeRematchLaunchContext() {
                        onRematch(context)
                    }
                } label: {
                    Text("Rematch")
                        .font(FitUpFont.body(14, weight: .bold))
                        .foregroundStyle(FitUpColors.Neon.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .ghostButton(color: FitUpColors.Neon.orange)
            }
        }
    }

    private func color(from hex: String) -> Color {
        guard let value = UInt32(hex, radix: 16) else {
            return FitUpColors.Neon.orange
        }
        return Color(rgb: value)
    }
}
