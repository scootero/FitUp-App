//
//  HomeView.swift
//  FitUp
//
//  Slice 3 Home shell and ordered sections.
//

import SwiftUI

private let useEnergyBeamHomeHero = true
/// Approximates loaded energy beam hero height (card + beam + chart + day bar) for skeleton parity.
private let homeEnergyBeamHeroSkeletonHeight: CGFloat = 400

struct HomeView: View {
    let profile: Profile?
    let showOnboardingSearching: Bool
    var onOpenChallenge: (ChallengePrefillOpponent?) -> Void
    var onOpenMatchDetails: (UUID, String) -> Void

    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var notificationService: NotificationService
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = HomeViewModel()
    @State private var isNotificationInboxVisible = false
    @State private var markReadTask: Task<Void, Never>?
    @State private var homeFirstRenderAt: Date?
    @State private var hasLoggedFirstRender = false
    @State private var hasLoggedHeroFirstRender = false
    @State private var hasLoggedFirstDataLoaded = false
    @State private var isPastMatchesExpanded = false
    @State private var inviteWaitingPulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

#if DEBUG
    @State private var beamLabUseBeamPreviewOffset = false
    @State private var beamLabSliderOffset: Double = 0
#endif

    var body: some View {
        ZStack {
            StaticPageGradientBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    #if DEBUG
                    if useEnergyBeamHomeHero, !viewModel.isHeroLoading {
                        homeEnergyBeamDebugLabStrip
                    }
                    #endif

                    header

                    if viewModel.isHeroLoading {
                        skeletonBlock(height: homeEnergyBeamHeroSkeletonHeight)
                            .homeLiquidGlassCard(.base)
                            .redacted(reason: .placeholder)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                            .padding(.top, 10)
                    } else {
                        if useEnergyBeamHomeHero {
                            if let handoff = viewModel.heroOpponentHandoff {
                                ZStack {
                                    skeletonBlock(height: homeEnergyBeamHeroSkeletonHeight)
                                        .homeLiquidGlassCard(.base)
                                        .opacity(0.5)
                                        .allowsHitTesting(false)
                                    HomeFeaturedOpponentHandoffOverlay(
                                        newOpponentName: handoff.newMatch.opponent.displayName,
                                        reduceMotion: reduceMotion,
                                        onComplete: {
                                            viewModel.completeHeroOpponentHandoff()
                                        }
                                    )
                                }
                                .padding(.top, 10)
                            } else if let primaryMatch = viewModel.featuredHomeStepMatch {
                                // Match details title uses raw `displayName` (may be empty) to stay consistent with other Home entry points.
                                Button {
                                    onOpenMatchDetails(primaryMatch.id, primaryMatch.opponent.displayName)
                                } label: {
                                    HomeEnergyBeamHeroCard(
                                        match: primaryMatch,
                                        profile: profile,
                                        sparklineUserValues: viewModel.heroSparklineUserSeries,
                                        sparklineOpponentValues: viewModel.heroSparklineOpponentSeries,
                                        viewerIntradayHealthKitSyncedAt: viewModel.heroViewerHealthKitStepsReadAt,
                                        opponentIntradayLatestTickAt: viewModel.heroOpponentIntradayLatestTickAt,
                                        beamCollisionMarginOverride: beamCollisionOverrideForDebug(match: primaryMatch)
                                    )
                                }
                                .buttonStyle(.plain)
                                .transaction { $0.disablesAnimations = false }
                                .padding(.top, 10)
                            } else {
                                HomeEnergyBeamHeroCard(
                                    match: nil,
                                    profile: profile,
                                    sparklineUserValues: viewModel.heroSparklineUserSeries,
                                    sparklineOpponentValues: viewModel.heroSparklineOpponentSeries,
                                    viewerIntradayHealthKitSyncedAt: viewModel.heroViewerHealthKitStepsReadAt,
                                    opponentIntradayLatestTickAt: viewModel.heroOpponentIntradayLatestTickAt,
                                    beamCollisionMarginOverride: nil
                                )
                                .padding(.top, 10)
                            }
                        } else if let primaryMatch = viewModel.featuredHomeStepMatch {
                            Button {
                                onOpenMatchDetails(primaryMatch.id, primaryMatch.opponent.displayName)
                            } label: {
                                HomeBattleHeroCard(
                                    matches: heroSortedStepMatches,
                                    featuredMatch: primaryMatch
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 10)
                        } else {
                            HomeBattleHeroCard(
                                matches: heroSortedStepMatches,
                                featuredMatch: nil
                            )
                            .padding(.top, 10)
                        }
                    }

                    heroSummaryLine
                    battleStatusStrip
                    battleMiniStatsGrid

                    if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(FitUpFont.body(12, weight: .semibold))
                            .foregroundStyle(FitUpColors.Neon.pink)
                            .padding(.horizontal, 2)
                    }

                    if viewModel.isInitialLoading {
                        deferredSectionsLoadingSkeleton
                    } else {
                        ActiveSection(
                            matches: viewModel.sortedActiveMatchesForHome,
                            onOpenMatch: { match in
                                onOpenMatchDetails(match.id, match.opponent.displayName)
                            }
                        )

                        pendingAndSearchingSection

                        if !viewModel.hasAnyContent, !viewModel.isLoading {
                            zeroState
                        }

                        HealthPastMatchesCard(
                            matches: viewModel.completedMatches,
                            isExpanded: isPastMatchesExpanded,
                            isLoading: viewModel.isLoadingCompletedMatches,
                            onToggleExpanded: {
                                isPastMatchesExpanded.toggle()
                                if isPastMatchesExpanded {
                                    Task { await viewModel.loadCompletedMatchesIfNeeded() }
                                }
                            },
                            onOpenMatch: { match in
                                onOpenMatchDetails(match.id, match.opponentName)
                            }
                        )
                        .padding(.top, 4)
                    }

                    #if DEBUG
                    HomeStepAveragesDebugCard(
                        profileId: profile?.id,
                        featuredStepMatch: viewModel.featuredHomeStepMatch
                    )
                    #endif
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await viewModel.reload(force: true)
            }

            if let celebration = viewModel.matchFoundCelebration {
                MatchFoundCelebrationOverlay(
                    opponentName: celebration.opponent.displayName,
                    onDismiss: { viewModel.dismissMatchFoundCelebration() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(1)
            }

            if let liveMatch = viewModel.matchActiveCelebration {
                MatchLiveCelebrationOverlay(
                    opponentName: liveMatch.opponent.displayName,
                    dayNumber: liveMatch.dayPips.first(where: { $0.state == .today })?.dayNumber ?? 1,
                    durationDays: liveMatch.durationDays,
                    onDismiss: { viewModel.dismissMatchActiveCelebration() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(2)
            }

            if let declinedOpponent = viewModel.declineFeedbackOpponentName {
                VStack {
                    Spacer()
                    ChallengeDeclinedToast(opponentName: declinedOpponent) {
                        viewModel.dismissDeclineFeedback()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }

            friendNotificationTopStack

            if isNotificationInboxVisible {
                notificationInboxOverlay
            }
        }
        .transaction { transaction in
            transaction.disablesAnimations = true
            transaction.animation = nil
        }
        .task(id: profile?.id) {
            viewModel.start(profile: profile, showOnboardingSearching: showOnboardingSearching, sessionStore: sessionStore)
            viewModel.syncHeroMetricWithActiveMatches()
        }
        .onAppear {
            if !hasLoggedFirstRender {
                hasLoggedFirstRender = true
                homeFirstRenderAt = Date()
                AppLogger.log(
                    category: "home_perf",
                    level: .info,
                    message: "home_first_render",
                    userId: profile?.id
                )
            }
            viewModel.resumeHomeLivePipeline(profile: profile, sessionStore: sessionStore)
            clearSearchingFlagIfHasMatch()
            viewModel.syncHeroMetricWithActiveMatches()
            startInviteWaitingPulse()
        }
        .onChange(of: sessionStore.homeSnapshotRefreshToken) { _, _ in
            Task { await viewModel.reload(force: true) }
        }
        .onChange(of: profile?.id) { _, _ in
            hasLoggedHeroFirstRender = false
            hasLoggedFirstDataLoaded = false
            homeFirstRenderAt = Date()
        }
        .onChange(of: viewModel.isHeroLoading) { _, isHeroLoading in
            guard !isHeroLoading, !hasLoggedHeroFirstRender else { return }
            hasLoggedHeroFirstRender = true
            let elapsedMs: Int
            if let startedAt = homeFirstRenderAt {
                elapsedMs = max(0, Int(Date().timeIntervalSince(startedAt) * 1000))
            } else {
                elapsedMs = 0
            }
            AppLogger.log(
                category: "home_perf",
                level: .info,
                message: "hero_first_render",
                userId: profile?.id,
                metadata: ["elapsed_ms_from_first_render": "\(elapsedMs)"]
            )
        }
        .onChange(of: viewModel.isInitialLoading) { _, isInitialLoading in
            guard !isInitialLoading, !hasLoggedFirstDataLoaded else { return }
            hasLoggedFirstDataLoaded = true
            let elapsedMs: Int
            if let startedAt = homeFirstRenderAt {
                elapsedMs = max(0, Int(Date().timeIntervalSince(startedAt) * 1000))
            } else {
                elapsedMs = 0
            }
            AppLogger.log(
                category: "home_perf",
                level: .info,
                message: "home_data_loaded",
                userId: profile?.id,
                metadata: ["elapsed_ms_from_first_render": "\(elapsedMs)"]
            )
        }
        .onChange(of: viewModel.pendingMatches.count) { _, _ in
            clearSearchingFlagIfHasMatch()
        }
        .onChange(of: viewModel.invitesWaitingCount) { _, _ in
            startInviteWaitingPulse()
        }
        .onChange(of: reduceMotion) { _, _ in
            startInviteWaitingPulse()
        }
        .onChange(of: viewModel.activeMatches.count) { _, _ in
            clearSearchingFlagIfHasMatch()
        }
        .onChange(of: viewModel.activeMatches.map(\.metricType)) { _, _ in
            viewModel.syncHeroMetricWithActiveMatches()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, profile?.id != nil else { return }
            Task { await viewModel.reload(force: true) }
        }
        .onDisappear {
            markReadTask?.cancel()
            isPastMatchesExpanded = false
            viewModel.stop()
        }
        .onChange(of: notificationService.shouldPresentHomeInbox) { _, shouldPresent in
            guard shouldPresent else { return }
            _ = notificationService.consumePresentHomeInbox()
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                isNotificationInboxVisible = true
            }
            scheduleInboxAutoRead()
        }
    }

    @ViewBuilder
    private var pendingAndSearchingSection: some View {
        if viewModel.activeSearchCount > 0 || viewModel.invitesWaitingCount > 0 || viewModel.waitingOnOpponentCount > 0 {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Pending & Searching")

                if !viewModel.receivedPendingMatches.isEmpty {
                    PendingSection(
                        title: "Invites waiting",
                        matches: viewModel.receivedPendingMatches,
                        mode: .actionRequired,
                        activeActionMatchID: viewModel.activeActionPendingMatchID,
                        onOpenMatch: { pendingMatch in
                            onOpenMatchDetails(pendingMatch.id, pendingMatch.opponent.displayName)
                        },
                        onAccept: { pendingMatch in
                            Task { await viewModel.acceptPendingMatch(pendingMatch) }
                        },
                        onDecline: { pendingMatch in
                            Task { await viewModel.declinePendingMatch(pendingMatch) }
                        }
                    )
                }

                if !viewModel.searchingRequests.isEmpty {
                    SearchingSection(
                        requests: viewModel.searchingRequests,
                        isCancellingSearchId: viewModel.activeActionSearchID,
                        onCancel: { searchId in
                            Task { await viewModel.cancelSearch(searchId) }
                        }
                    )
                }

                if !viewModel.sentPendingMatchesWaitingOnOpponent.isEmpty {
                    PendingSection(
                        title: "Waiting on opponent",
                        matches: viewModel.sentPendingMatchesWaitingOnOpponent,
                        mode: .waitingOnOpponent,
                        activeActionMatchID: viewModel.activeActionPendingMatchID,
                        onOpenMatch: { pendingMatch in
                            onOpenMatchDetails(pendingMatch.id, pendingMatch.opponent.displayName)
                        },
                        onAccept: { pendingMatch in
                            Task { await viewModel.acceptPendingMatch(pendingMatch) }
                        },
                        onDecline: { pendingMatch in
                            Task { await viewModel.declinePendingMatch(pendingMatch) }
                        }
                    )
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.96)),
                            removal: .opacity
                        )
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var friendNotificationTopStack: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let incoming = activeIncomingFriendRequest {
                FriendRequestRetroCard(
                    fromName: incoming.fromName,
                    isLoading: viewModel.isFriendRequestActionLoading,
                    onAccept: {
                        Task {
                            if let prefill = await viewModel.acceptFriendRequestBackground(peerId: incoming.peerId) {
                                sessionStore.setBecameFriendsChallenge(prefill)
                            }
                        }
                    },
                    onLater: {
                        if let p = sessionStore.friendRequestBannerFromPush {
                            sessionStore.dismissFriendRequestFromPush()
                            viewModel.markFriendPeerDismissedForLater(peerId: p.0)
                        } else {
                            viewModel.markFriendPeerDismissedForLater(peerId: incoming.peerId)
                        }
                    },
                    onOpenFriends: { sessionStore.requestOpenFriendsListSheet() }
                )
            }

            if let accepted = sessionStore.friendAcceptedYourRequestBanner {
                FriendAcceptedRetroBanner(
                    accepterName: accepted.1,
                    onCompete: {
                        Task {
                            if let prefill = await viewModel.makePrefillForPeer(accepted.0) {
                                sessionStore.dismissFriendAcceptedYourRequestBanner()
                                onOpenChallenge(prefill)
                            }
                        }
                    },
                    onDismiss: { sessionStore.dismissFriendAcceptedYourRequestBanner() }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .zIndex(5)
    }

    private var activeIncomingFriendRequest: (peerId: UUID, fromName: String)? {
        if let push = sessionStore.friendRequestBannerFromPush {
            return (push.0, push.1)
        }
        if let poll = viewModel.polledIncomingFriend {
            return (poll.peerId, poll.fromName)
        }
        return nil
    }

    private func clearSearchingFlagIfHasMatch() {
        if !viewModel.pendingMatches.isEmpty || !viewModel.activeMatches.isEmpty {
            sessionStore.clearSearchingCardOnHomeFlag()
        }
    }

    private var heroSummaryLine: some View {
        Group {
            if let text = viewModel.heroSummaryText {
                Text(text)
                    .font(FitUpFont.body(12, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [FitUpColors.Text.secondary, FitUpColors.Neon.cyan.opacity(0.86)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.horizontal, 2)
            }
        }
    }

    @ViewBuilder
    private var battleStatusStrip: some View {
        let hasInviteWaiting = viewModel.invitesWaitingCount > 0
        if hasInviteWaiting {
            Button {
                openOldestPendingInvite()
            } label: {
                battleStatusStripContent(showInviteAffordance: true)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Tap to open invite from \(viewModel.oldestReceivedPendingMatch?.opponent.displayName ?? "opponent")")
        } else {
            battleStatusStripContent(showInviteAffordance: false)
        }
    }

    private func battleStatusStripContent(showInviteAffordance: Bool) -> some View {
        let state = viewModel.statusStripState
        return HStack(spacing: 10) {
            Circle()
                .fill(statusDotColor(for: state))
                .frame(width: 8, height: 8)
            Text(viewModel.statusStripMessage)
                .font(FitUpFont.body(12, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            if showInviteAffordance {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FitUpColors.Neon.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .homeLiquidGlassCard(.base)
        .overlay(
            Group {
                if showInviteAffordance {
                    RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                        .strokeBorder(FitUpColors.Neon.orange, lineWidth: 1.4)
                        .opacity(inviteWaitingPulse ? 0.95 : 0.25)
                        .shadow(color: FitUpColors.Neon.orange.opacity(0.55), radius: inviteWaitingPulse ? 10 : 2)
                        .allowsHitTesting(false)
                }
            }
        )
        .contentShape(Rectangle())
    }

    private func openOldestPendingInvite() {
        guard let oldest = viewModel.oldestReceivedPendingMatch else { return }
        onOpenMatchDetails(oldest.id, oldest.opponent.displayName)
    }

    private func startInviteWaitingPulse() {
        guard viewModel.invitesWaitingCount > 0 else {
            inviteWaitingPulse = false
            return
        }
        guard !reduceMotion else {
            inviteWaitingPulse = true
            return
        }
        inviteWaitingPulse = false
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            inviteWaitingPulse = true
        }
    }

    private var battleMiniStatsGrid: some View {
        let summary = viewModel.battleSummaryStats
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            miniStatCard(
                label: "Winning",
                value: summary.winningCount.map(String.init) ?? "--",
                accent: FitUpColors.Neon.green
            )
            miniStatCard(
                label: "Losing",
                value: summary.losingCount.map(String.init) ?? "--",
                accent: FitUpColors.Neon.orange
            )
            miniStatCard(
                label: "Closest Lead",
                value: summary.closestLead.map(formattedSignedMargin) ?? "--",
                accent: FitUpColors.Neon.cyan
            )
            miniStatCard(
                label: "Closest Deficit",
                value: summary.closestDeficit.map { abs($0).formatted() } ?? "--",
                accent: FitUpColors.Neon.red
            )
        }
    }

    private func miniStatCard(label: String, value: String, accent: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(FitUpFont.display(15, weight: .black))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(label.uppercased())
                .font(FitUpFont.mono(8, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.tertiary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .homeLiquidGlassCard(.base)
    }

    private func statusDotColor(for state: HomeViewModel.StatusStripState) -> Color {
        switch state {
        case .searching:
            return FitUpColors.Neon.cyan
        case .invitesWaiting:
            return FitUpColors.Neon.orange
        case .waitingOnOpponent(_):
            return FitUpColors.Neon.purple
        case .noActiveBattles:
            return FitUpColors.Neon.yellow
        case .allBattlesActive:
            return FitUpColors.Neon.green
        }
    }

    private func formattedSignedMargin(_ value: Int) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)\(abs(value).formatted())"
    }

    private func beamCollisionOverrideForDebug(match: HomeActiveMatch?) -> Int? {
        #if DEBUG
        guard useEnergyBeamHomeHero, beamLabUseBeamPreviewOffset, let m = match else { return nil }
        let delta = Int(beamLabSliderOffset.rounded())
        return min(10_000, max(-10_000, m.comparableMargin + delta))
        #else
        return nil
        #endif
    }

    @ViewBuilder
    private var homeEnergyBeamDebugLabStrip: some View {
        #if DEBUG
        VStack(alignment: .leading, spacing: 6) {
            Text("DEBUG — Beam collision lab")
                .font(FitUpFont.body(10, weight: .heavy))
                .foregroundStyle(Color.white.opacity(0.4))
                .tracking(1)

            Toggle("Use Beam Preview Offset", isOn: $beamLabUseBeamPreviewOffset)
                .font(FitUpFont.body(12, weight: .semibold))
                .controlSize(.small)
                .tint(FitUpColors.Neon.cyan)

            Slider(
                value: $beamLabSliderOffset,
                in: -10_000 ... 10_000,
                step: 1
            )
            .controlSize(.small)
            .tint(FitUpColors.Neon.cyan)
            .disabled(!beamLabUseBeamPreviewOffset)

            HStack(spacing: 6) {
                beamLabPresetButton(title: "Center") {
                    beamLabSliderOffset = 0
                }
                beamLabPresetButton(title: "User Push") {
                    beamLabSliderOffset = 2_500
                }
                beamLabPresetButton(title: "Opponent Push") {
                    beamLabSliderOffset = -2_500
                }
            }

            Button {
                viewModel.debugPreviewHeroOpponentHandoff()
            } label: {
                Text("Preview opponent handoff (Slice 7)")
                    .font(FitUpFont.body(11, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(FitUpColors.Neon.orange.opacity(0.15))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(FitUpColors.Neon.orange.opacity(0.45), lineWidth: 1)
                            )
                    )
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.heroOpponentHandoff != nil || viewModel.featuredHomeStepMatch == nil)

            Text("Adjusts beam collision only; scores and copy stay live.")
                .font(FitUpFont.body(10, weight: .medium))
                .foregroundStyle(FitUpColors.Text.tertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        #else
        EmptyView()
        #endif
    }

#if DEBUG
    private func beamLabPresetButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(FitUpFont.body(11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.vertical, 5)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                )
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .buttonStyle(.plain)
    }
#endif

    private var heroSortedStepMatches: [HomeActiveMatch] {
        viewModel.sortedActiveMatchesForHome.filter { $0.metricType != "active_calories" }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text("FIT")
                        .font(FitUpFont.display(27, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("UP")
                        .font(FitUpFont.display(27, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [FitUpColors.Neon.orange, FitUpColors.Neon.yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                Text("Let's go, \(firstName)")
                    .font(FitUpFont.body(12, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)

                Text("It's battle time. Check your edge before you jump in.")
                    .font(FitUpFont.body(12, weight: .semibold))
                    .lineSpacing(1.2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [FitUpColors.Neon.cyan.opacity(0.92), FitUpColors.Neon.blue.opacity(0.88)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: FitUpColors.Neon.blue.opacity(0.32), radius: 2, x: 2, y: 6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 3)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                bellButton

                Button {
                    onOpenChallenge(nil)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(FitUpColors.Neon.cyan)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(FitUpColors.Neon.cyan.opacity(0.14))
                                .overlay(Circle().strokeBorder(FitUpColors.Neon.cyan.opacity(0.28), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var zeroState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No battles yet")
                .font(FitUpFont.display(24, weight: .black))
            .fitUpGlobalTitleStyle(weight: .black, tracking: 0.25)
            Text("Start a match to compete today.")
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
            Button("Find Your First Match") {
                onOpenChallenge(nil)
            }
            .solidButton(color: FitUpColors.Neon.cyan)
        }
        .padding(20)
        .homeLiquidGlassCard(.base)
    }

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 14) {
            skeletonBlock(height: 212)
                .homeLiquidGlassCard(.base)

            skeletonSectionTitle
            skeletonBlock(height: 156)
                .homeLiquidGlassCard(.base)

            skeletonSectionTitle
            skeletonBlock(height: 130)
                .homeLiquidGlassCard(.base)

            skeletonSectionTitle
            skeletonBlock(height: 114)
                .homeLiquidGlassCard(.base)

            skeletonSectionTitle
            skeletonBlock(height: 84)
                .homeLiquidGlassCard(.base)
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var deferredSectionsLoadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 14) {
            skeletonSectionTitle
            skeletonBlock(height: 118)
                .homeLiquidGlassCard(.base)

            skeletonSectionTitle
            skeletonBlock(height: 96)
                .homeLiquidGlassCard(.base)
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var skeletonSectionTitle: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.white.opacity(0.14))
            .frame(width: 148, height: 16)
            .padding(.top, 2)
    }

    private func skeletonBlock(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }

    private var firstName: String {
        let full = profile?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Athlete"
        return full.split(separator: " ").first.map(String.init) ?? full
    }

    private func prefillOpponent(from user: HomeDiscoverUser) -> ChallengePrefillOpponent {
        ChallengePrefillOpponent(
            id: user.id,
            displayName: user.displayName,
            initials: user.initials,
            colorHex: user.colorHex
        )
    }

    private var bellButton: some View {
        Button {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                isNotificationInboxVisible.toggle()
            }
            if isNotificationInboxVisible {
                scheduleInboxAutoRead()
            } else {
                markReadTask?.cancel()
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .frame(width: 36, height: 36)
                    .homeLiquidGlassCard(.base)

                if notificationService.unreadInboxCount > 0 {
                    Circle()
                        .fill(FitUpColors.Neon.pink)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.9), lineWidth: 1)
                        )
                        .offset(x: 3, y: -3)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Notifications")
    }

    private var notificationInboxOverlay: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.87)) {
                        isNotificationInboxVisible = false
                    }
                }

            VStack(alignment: .leading, spacing: 8) {
                Text("Notifications")
                    .font(FitUpFont.mono(12, weight: .heavy))
                    .foregroundStyle(FitUpColors.Neon.cyan)
                    .fitUpGlobalTitleStyle(weight: .heavy, tracking: 0.5)

                if notificationService.inboxItems.isEmpty {
                    Text("No alerts yet.")
                        .font(FitUpFont.body(13, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(notificationService.inboxItems) { item in
                                inboxRow(for: item)
                                    .onTapGesture { handleInboxTap(item) }
                            }
                        }
                    }
                    .frame(maxHeight: 320)
                }
            }
            .padding(12)
            .frame(width: min(UIScreen.main.bounds.width - 32, 330))
            .background(
                RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                    .fill(Color(rgb: 0x0A1020).opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        FitUpColors.Neon.cyan.opacity(0.85),
                                        FitUpColors.Neon.purple.opacity(0.45),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
            )
            .shadow(color: FitUpColors.Neon.cyan.opacity(0.18), radius: 14, y: 6)
            .padding(.top, 56)
            .padding(.trailing, 16)
            .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.98, anchor: .topTrailing)))
        }
        .zIndex(8)
    }

    private func inboxRow(for item: InAppNotificationItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName(for: item))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor(for: item))
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(iconColor(for: item).opacity(item.isRead ? 0.14 : 0.22))
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.title)
                        .font(FitUpFont.body(13, weight: .bold))
                        .foregroundStyle(item.isRead ? FitUpColors.Text.secondary : FitUpColors.Text.primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if !item.isRead {
                        Text("UNREAD")
                            .font(FitUpFont.mono(9, weight: .heavy))
                            .foregroundStyle(FitUpColors.Neon.orange)
                    }
                }
                Text(item.body)
                    .font(FitUpFont.body(12, weight: .medium))
                    .foregroundStyle(item.isRead ? FitUpColors.Text.tertiary : FitUpColors.Text.secondary)
                    .lineLimit(2)
                Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(FitUpFont.mono(9, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
                .fill(item.isRead ? Color.white.opacity(0.04) : FitUpColors.Neon.cyan.opacity(0.11))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
                .strokeBorder(
                    item.isRead ? Color.white.opacity(0.05) : FitUpColors.Neon.cyan.opacity(0.4),
                    lineWidth: 1
                )
        )
        .animation(.easeInOut(duration: 0.26), value: item.isRead)
    }

    private func iconName(for item: InAppNotificationItem) -> String {
        switch item.eventType {
        case "match_found", "challenge_received", "match_active":
            return "bolt.fill"
        case "friend_request_received", "friend_request_accepted":
            return "person.2.fill"
        default:
            return "bell.fill"
        }
    }

    private func iconColor(for item: InAppNotificationItem) -> Color {
        switch item.eventType {
        case "match_found", "challenge_received", "match_active":
            return item.isRead ? FitUpColors.Neon.blue : FitUpColors.Neon.cyan
        case "friend_request_received", "friend_request_accepted":
            return item.isRead ? FitUpColors.Neon.purple : FitUpColors.Neon.green
        default:
            return item.isRead ? FitUpColors.Text.tertiary : FitUpColors.Neon.orange
        }
    }

    private func scheduleInboxAutoRead() {
        markReadTask?.cancel()
        markReadTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.32)) {
                notificationService.markAllInboxItemsRead()
            }
        }
    }

    private func handleInboxTap(_ item: InAppNotificationItem) {
        notificationService.markInboxItemRead(item.id)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isNotificationInboxVisible = false
        }

        if let matchId = item.matchId {
            onOpenMatchDetails(matchId, "Match")
            return
        }

        if item.eventType == "friend_request_received" || item.deepLinkTarget == "friends" {
            sessionStore.requestOpenFriendsListSheet()
        }
    }

}

// MARK: - Challenge declined toast (retro)

private struct ChallengeDeclinedToast: View {
    let opponentName: String
    var onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        Button(action: onDismiss) {
            VStack(spacing: 6) {
                Text("CHALLENGE DECLINED")
                    .font(FitUpFont.mono(13, weight: .heavy))
                    .foregroundStyle(FitUpColors.Neon.pink)
                    .shadow(color: FitUpColors.Neon.pink.opacity(0.45), radius: 8)
                Text("VS \(opponentName.uppercased())")
                    .font(FitUpFont.mono(11, weight: .semibold))
                    .foregroundStyle(FitUpColors.Neon.yellow.opacity(0.95))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                    .fill(Color(rgb: 0x0A1020).opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        FitUpColors.Neon.pink.opacity(0.85),
                                        FitUpColors.Neon.purple.opacity(0.5),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(color: FitUpColors.Neon.pink.opacity(0.2), radius: 16)
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Challenge declined, tap to dismiss")
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }
}

// MARK: - Match live celebration (retro)

private struct MatchLiveCelebrationOverlay: View {
    let opponentName: String
    let dayNumber: Int
    let durationDays: Int
    var onDismiss: () -> Void

    @State private var cardAppeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.56)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            scanlineField

            VStack(spacing: 14) {
                Text("MATCH INITIATED!")
                    .font(FitUpFont.mono(17, weight: .heavy))
                    .foregroundStyle(FitUpColors.Neon.cyan)
                    .shadow(color: FitUpColors.Neon.cyan.opacity(0.5), radius: 10)
                    .multilineTextAlignment(.center)

                Text("GO GO GO")
                    .font(FitUpFont.mono(15, weight: .heavy))
                    .foregroundStyle(FitUpColors.Neon.green)
                    .shadow(color: FitUpColors.Neon.green.opacity(0.45), radius: 8)

                Text("VS \(opponentName.uppercased())")
                    .font(FitUpFont.mono(13, weight: .semibold))
                    .foregroundStyle(FitUpColors.Neon.yellow)
                    .multilineTextAlignment(.center)

                Text("DAY \(dayNumber) OF \(durationDays)")
                    .font(FitUpFont.mono(11, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .padding(.top, 2)

                Text("TAP TO CONTINUE")
                    .font(FitUpFont.mono(10, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.tertiary)
                    .padding(.top, 6)
            }
            .padding(28)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: FitUpRadius.lg)
                    .fill(Color(rgb: 0x0A1020).opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: FitUpRadius.lg)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        FitUpColors.Neon.cyan,
                                        FitUpColors.Neon.green,
                                        FitUpColors.Neon.yellow,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            )
            .shadow(color: FitUpColors.Neon.green.opacity(0.22), radius: 22)
            .scaleEffect(cardAppeared ? 1 : 0.9)
            .opacity(cardAppeared ? 1 : 0)
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
            .onTapGesture { onDismiss() }
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                cardAppeared = true
            }
        }
    }

    private var scanlineField: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let lineH: CGFloat = 1
                let gap: CGFloat = 6
                var y: CGFloat = 0
                while y < size.height {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: lineH)
                    context.fill(Path(rect), with: .color(Color.white.opacity(0.04)))
                    y += gap + lineH
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Match found celebration (retro)

private struct MatchFoundCelebrationOverlay: View {
    let opponentName: String
    var onDismiss: () -> Void

    @State private var cardAppeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.56)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            scanlineField

            VStack(spacing: 14) {
                Text("YOU'VE BEEN MATCHED!")
                    .font(FitUpFont.mono(17, weight: .heavy))
                    .foregroundStyle(FitUpColors.Neon.green)
                    .shadow(color: FitUpColors.Neon.green.opacity(0.5), radius: 10)
                    .multilineTextAlignment(.center)

                Text("VS \(opponentName.uppercased())")
                    .font(FitUpFont.mono(13, weight: .semibold))
                    .foregroundStyle(FitUpColors.Neon.yellow)
                    .multilineTextAlignment(.center)

                Text("TAP TO CONTINUE")
                    .font(FitUpFont.mono(10, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.tertiary)
                    .padding(.top, 6)
            }
            .padding(28)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: FitUpRadius.lg)
                    .fill(Color(rgb: 0x0A1020).opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: FitUpRadius.lg)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        FitUpColors.Neon.cyan,
                                        FitUpColors.Neon.purple,
                                        FitUpColors.Neon.green,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            )
            .shadow(color: FitUpColors.Neon.cyan.opacity(0.25), radius: 22)
            .scaleEffect(cardAppeared ? 1 : 0.9)
            .opacity(cardAppeared ? 1 : 0)
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
            .onTapGesture { onDismiss() }
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                cardAppeared = true
            }
        }
    }

    private var scanlineField: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let lineH: CGFloat = 1
                let gap: CGFloat = 6
                var y: CGFloat = 0
                while y < size.height {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: lineH)
                    context.fill(Path(rect), with: .color(Color.white.opacity(0.04)))
                    y += gap + lineH
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
