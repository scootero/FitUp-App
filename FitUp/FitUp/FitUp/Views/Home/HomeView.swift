//
//  HomeView.swift
//  FitUp
//
//  Slice 3 Home shell and ordered sections.
//

import SwiftUI

private let useEnergyBeamHomeHero = true
/// Approximates loaded energy beam hero height (card + beam + chart + day bar) for skeleton parity.
private let homeEnergyBeamHeroSkeletonHeight: CGFloat = 500
/// Horizontal inset for the energy beam hero only (slightly tighter than the rest of Home).
private let homeHeroHorizontalPadding: CGFloat = 15

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    let profile: Profile?
    let showOnboardingSearching: Bool
    var onOpenChallenge: (ChallengePrefillOpponent?) -> Void
    var onOpenMatchDetails: (UUID, String) -> Void
    var onOpenLeaderboard: () -> Void

    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var homeFirstRenderAt: Date?
    @State private var hasLoggedFirstRender = false
    @State private var hasLoggedHeroFirstRender = false
    @State private var hasLoggedFirstDataLoaded = false
    @State private var isPastMatchesExpanded = false
    @State private var inviteWaitingPulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Crossfade from outgoing featured hero → incoming (0…1, linear with blur fade-out).
    @State private var handoffCrossfadeProgress: CGFloat = 0
    @State private var handoffRevealingNewHero = false
    @State private var handoffIntroKickoff = UUID()
    @State private var handoffOpponentRevealKickoff = UUID()
    @State private var handoffKeepOpponentBlackedOut = false
    @State private var handoffFinishTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            StaticPageGradientBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if viewModel.isHeroLoading {
                        skeletonBlock(height: homeEnergyBeamHeroSkeletonHeight)
                            .homeLiquidGlassCard(.base)
                            .redacted(reason: .placeholder)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                            .padding(.top, 10)
                            .padding(.horizontal, homeHeroHorizontalPadding)
                    } else {
                        if useEnergyBeamHomeHero {
                            energyBeamHeroSection
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
                            .padding(.horizontal, 16)
                        } else {
                            HomeBattleHeroCard(
                                matches: heroSortedStepMatches,
                                featuredMatch: nil
                            )
                            .padding(.top, 10)
                            .padding(.horizontal, 16)
                        }
                    }

                    Group {
                        heroSummaryLine
                        battleStatusStrip
                        ActiveBattlesNeonSection(
                            matches: viewModel.isInitialLoading ? [] : viewModel.sortedActiveMatchesForHome,
                            summary: viewModel.battleSummaryStats,
                            leaderboardRankDisplay: viewModel.globalLeaderboardRankDisplay,
                            onOpenMatch: { match in
                                onOpenMatchDetails(match.id, match.opponent.displayName)
                            },
                            onOpenWinningMatch: {
                                guard let match = viewModel.primaryWinningMatchForHome else { return }
                                onOpenMatchDetails(match.id, match.opponent.displayName)
                            },
                            onOpenLosingMatch: {
                                guard let match = viewModel.primaryLosingMatchForHome else { return }
                                onOpenMatchDetails(match.id, match.opponent.displayName)
                            },
                            onOpenLeaderboard: onOpenLeaderboard
                        )

                        if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(FitUpFont.body(14, weight: .semibold))
                                .foregroundStyle(FitUpColors.Neon.pink)
                                .padding(.horizontal, 2)
                        }

                        if viewModel.isInitialLoading {
                            deferredSectionsLoadingSkeleton
                        } else {
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
                }
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
            if viewModel.hasMemoryState, !viewModel.isHeroLoading {
                Task { await viewModel.refreshOnForeground() }
            } else {
                Task { await viewModel.reload(force: true) }
            }
        }
        .onDisappear {
            isPastMatchesExpanded = false
            viewModel.pauseLivePipeline()
        }
    }

    private var energyBeamHeroActiveMatch: HomeActiveMatch? {
        let handoff = viewModel.heroOpponentHandoff
        if let handoff {
            if handoffRevealingNewHero { return handoff.newMatch }
            return handoff.previousMatch ?? handoff.newMatch
        }
        return viewModel.featuredHomeStepMatch
    }

    @ViewBuilder
    private func energyBeamHeroCard(
        match: HomeActiveMatch?,
        handoffRevealActive: Bool = false,
        handoffIntroKickoff: UUID = UUID(),
        handoffOpponentRevealKickoff: UUID = UUID(),
        handoffKeepOpponentBlackedOut: Bool = false,
        onStartBattle: (() -> Void)? = nil
    ) -> some View {
        HomeEnergyBeamHeroCard(
            match: match,
            profile: profile,
            sparklineUserValues: viewModel.heroSparklineUserSeries,
            sparklineOpponentValues: viewModel.heroSparklineOpponentSeries,
            viewerIntradayHealthKitSyncedAt: viewModel.heroViewerHealthKitStepsReadAt,
            opponentIntradayLatestTickAt: viewModel.heroOpponentIntradayLatestTickAt,
            handoffRevealActive: handoffRevealActive,
            handoffIntroKickoff: handoffIntroKickoff,
            handoffOpponentRevealKickoff: handoffOpponentRevealKickoff,
            handoffKeepOpponentBlackedOut: handoffKeepOpponentBlackedOut,
            onStartBattle: onStartBattle
        )
    }

    @ViewBuilder
    private var energyBeamHeroHandoffStack: some View {
        let handoff = viewModel.heroOpponentHandoff
        let activeMatch = energyBeamHeroActiveMatch

        ZStack {
            if let handoff, let previous = handoff.previousMatch, handoffRevealingNewHero {
                energyBeamHeroCard(match: previous)
                    .opacity(1 - handoffCrossfadeProgress)
                    .allowsHitTesting(false)
            }

            if let activeMatch {
                Button {
                    onOpenMatchDetails(activeMatch.id, activeMatch.opponent.displayName)
                } label: {
                    energyBeamHeroCard(
                        match: activeMatch,
                        handoffRevealActive: handoff != nil && handoffRevealingNewHero,
                        handoffIntroKickoff: handoffIntroKickoff,
                        handoffOpponentRevealKickoff: handoffOpponentRevealKickoff,
                        handoffKeepOpponentBlackedOut: handoffKeepOpponentBlackedOut
                    )
                    .id(activeMatch.id)
                }
                .buttonStyle(.plain)
                .transaction { $0.disablesAnimations = false }
                .opacity(handoff != nil && handoffRevealingNewHero ? handoffCrossfadeProgress : 1)
                .overlay {
                    if handoff != nil, handoffRevealingNewHero {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.black)
                            .opacity(1 - handoffCrossfadeProgress)
                            .allowsHitTesting(false)
                    }
                }
                .allowsHitTesting(handoff == nil)
            } else {
                skeletonBlock(height: homeEnergyBeamHeroSkeletonHeight)
                    .homeLiquidGlassCard(.base)
                    .allowsHitTesting(false)
            }
        }
    }

    /// Overlay fully gone — un-suppress rival column, fade in from black, then clear handoff state.
    private func finishHandoffAfterOverlayDismissed() {
        handoffFinishTask?.cancel()
        let revealDuration: TimeInterval = reduceMotion ? 0.2 : 1.05
        handoffKeepOpponentBlackedOut = false
        handoffOpponentRevealKickoff = UUID()
        handoffFinishTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(revealDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            handoffRevealingNewHero = false
            handoffCrossfadeProgress = 0
            handoffKeepOpponentBlackedOut = false
            viewModel.completeHeroOpponentHandoff()
        }
    }

    @ViewBuilder
    private var energyBeamHeroSection: some View {
        let handoff = viewModel.heroOpponentHandoff
        let activeMatch = energyBeamHeroActiveMatch

        if activeMatch != nil || handoff != nil {
            energyBeamHeroHandoffStack
                .overlay {
                    if let handoff {
                        HomeFeaturedOpponentHandoffOverlay(
                            newOpponentName: handoff.newMatch.opponent.displayName,
                            reduceMotion: reduceMotion,
                            crossfadeProgress: $handoffCrossfadeProgress,
                            onBeginReveal: {
                                handoffFinishTask?.cancel()
                                handoffKeepOpponentBlackedOut = true
                                handoffRevealingNewHero = true
                                handoffCrossfadeProgress = 0
                                handoffIntroKickoff = UUID()
                            },
                            onComplete: {
                                finishHandoffAfterOverlayDismissed()
                            }
                        )
                    }
                }
                .padding(.top, 10)
                .padding(.horizontal, homeHeroHorizontalPadding)
                .onAppear {
                    handoffRevealingNewHero = false
                    handoffCrossfadeProgress = 0
                    handoffKeepOpponentBlackedOut = viewModel.heroOpponentHandoff != nil
                }
                .onChange(of: viewModel.heroOpponentHandoff?.newMatch.id) { _, newId in
                    handoffFinishTask?.cancel()
                    handoffRevealingNewHero = false
                    handoffCrossfadeProgress = 0
                    handoffKeepOpponentBlackedOut = newId != nil
                }
                .onDisappear {
                    handoffFinishTask?.cancel()
                }
        } else {
            energyBeamHeroCard(match: nil, onStartBattle: { onOpenChallenge(nil) })
                .padding(.top, 10)
                .padding(.horizontal, homeHeroHorizontalPadding)
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
                    .font(FitUpFont.body(14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [HomePageStyle.muted, FitUpColors.Neon.cyan.opacity(0.92)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
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
                .font(FitUpFont.body(14, weight: .semibold))
                .foregroundStyle(HomePageStyle.offWhite)
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

    private var heroSortedStepMatches: [HomeActiveMatch] {
        viewModel.sortedActiveMatchesForHome.filter { $0.metricType != "active_calories" }
    }

    private var zeroState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No battles yet")
                .font(FitUpFont.display(24, weight: .black))
            .fitUpGlobalTitleStyle(weight: .black, tracking: 0.25)
            Text("Start a battle to compete today.")
                .font(FitUpFont.body(15, weight: .medium))
                .foregroundStyle(HomePageStyle.muted)
            Button("New Battle") {
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

    private func prefillOpponent(from user: HomeDiscoverUser) -> ChallengePrefillOpponent {
        ChallengePrefillOpponent(
            id: user.id,
            displayName: user.displayName,
            initials: user.initials,
            colorHex: user.colorHex
        )
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
                Text("BATTLE DECLINED")
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
        .accessibilityLabel("Battle declined, tap to dismiss")
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
