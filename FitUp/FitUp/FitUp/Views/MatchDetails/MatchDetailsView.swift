//
//  MatchDetailsView.swift
//  FitUp
//
//  Match Details — v2 layout for active/completed; legacy pending UI preserved.
//

import SwiftUI

private enum MatchDetailsMessagingAlert: Identifiable, Equatable {
    /// Chat is gated until friendship is accepted.
    case blockedNotFriend
    /// Messaging errors (thread creation failures, backend messages).
    case generic(body: String)

    var id: String {
        switch self {
        case .blockedNotFriend: return "blockedNotFriend"
        case .generic(let body): return "generic|\(body)"
        }
    }
}

/// Actual-steps chip in the hero: strict lead (ties use neutral styling).
private enum HeroTodayPillStyle {
    case leading
    case trailing
    case tied

    var foreground: Color {
        switch self {
        case .leading: FitUpColors.Neon.cyan
        case .trailing: FitUpColors.Neon.red
        case .tied: FitUpColors.Text.secondary
        }
    }

    var fill: Color {
        switch self {
        case .leading: FitUpColors.Neon.cyan.opacity(0.1)
        case .trailing: FitUpColors.Neon.red.opacity(0.1)
        case .tied: Color.white.opacity(0.06)
        }
    }

    var stroke: Color {
        switch self {
        case .leading: FitUpColors.Neon.cyan.opacity(0.2)
        case .trailing: FitUpColors.Neon.red.opacity(0.2)
        case .tied: Color.white.opacity(0.1)
        }
    }
}

struct MatchDetailsView: View {
    var onClose: () -> Void
    var onRematch: (ChallengeLaunchContext) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: MatchDetailsViewModel
    @State private var hoveredDayBreakdownDayNumber: Int?
    @State private var tappedDayBreakdownDayNumber: Int?
    @State private var didTrackMatchViewed = false
    @State private var didTrackMatchCompleted = false
    @State private var peerProfileSheet: PeerProfileSheetItem?
    @State private var opponentFriendshipPhase: PeerFriendshipPhase = .unknown
    /// Message-related alert (blocked chat vs backend error text).
    @State private var messagingAlertKind: MatchDetailsMessagingAlert?
    @State private var friendRequestBusy = false
    @State private var showFriendRequestSentToast = false
    @State private var friendRequestToastTask: Task<Void, Never>?
    @State private var chatThreadPresentation: MatchChatPresentation?
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
            .refreshable {
                await viewModel.refresh(showLoading: false)
            }

            if showFriendRequestSentToast {
                VStack {
                    Spacer()
                    FriendRequestSentMatchDetailsToast(onDismiss: { dismissFriendRequestSentToastImmediately() })
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(true)
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: showFriendRequestSentToast)
        .task {
            viewModel.start()
        }
        .onChange(of: viewModel.snapshot) { _, snap in
            guard let snap, let uid = profile?.id else { return }
            if !didTrackMatchViewed {
                didTrackMatchViewed = true
                ProductAnalytics.track(
                    ProductAnalytics.Event.matchViewed,
                    userId: uid,
                    properties: [
                        "match_id": snap.matchId.uuidString,
                        "state": snap.state.rawValue,
                    ]
                )
            }
            if snap.state == .completed, !didTrackMatchCompleted {
                didTrackMatchCompleted = true
                ProductAnalytics.track(
                    ProductAnalytics.Event.completedMatchViewed,
                    userId: uid,
                    properties: [
                        "match_id": snap.matchId.uuidString,
                        "won": snap.isWinning ? "true" : "false",
                    ]
                )
            }
        }
        .onDisappear {
            friendRequestToastTask?.cancel()
            friendRequestToastTask = nil
            viewModel.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await viewModel.refresh(showLoading: false) }
        }
        .task(id: viewModel.snapshot?.opponent.id) {
            await refreshOpponentFriendshipPhase()
        }
        .sheet(item: $peerProfileSheet) { item in
            if let profile {
                PeerProfileView(peerId: item.peerId, viewer: profile)
            }
        }
        .onChange(of: peerProfileSheet) { _, new in
            if new == nil {
                Task { await refreshOpponentFriendshipPhase() }
            }
        }
        .alert(
            "Message",
            isPresented: Binding(
                get: { messagingAlertKind != nil },
                set: { if !$0 { messagingAlertKind = nil } }
            ),
            presenting: messagingAlertKind,
            actions: { kind in
                switch kind {
                case .blockedNotFriend:
                    Button("Add Friend") {
                        messagingAlertKind = nil
                        Task { await sendFriendRequestToOpponent(showSuccessToast: true) }
                    }
                    Button("OK", role: .cancel) {
                        messagingAlertKind = nil
                    }
                case .generic:
                    Button("OK", role: .cancel) {
                        messagingAlertKind = nil
                    }
                }
            },
            message: { kind in
                switch kind {
                case .blockedNotFriend:
                    Text("Add this person as a friend to message them.")
                case .generic(let body):
                    Text(body)
                }
            }
        )
        .fullScreenCover(item: $chatThreadPresentation) { ctx in
            if let profile {
                NavigationStack {
                    ChatThreadView(peerProfileId: ctx.peerId, viewer: profile)
                }
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

            if profile != nil, viewModel.snapshot != nil {
                HStack(spacing: 8) {
                    Button {
                        messageCompetitorTapped()
                    } label: {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FitUpColors.Text.secondary)
                            .frame(width: 34, height: 34)
                            .background(topBarChromeBackground)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Message competitor")

                    Button {
                        friendIconTapped()
                    } label: {
                        Image(systemName: friendTopBarSymbolName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(friendIconForegroundStyle)
                            .frame(width: 34, height: 34)
                            .background(topBarChromeBackground)
                    }
                    .buttonStyle(.plain)
                    .disabled(friendIconDisabled || friendRequestBusy)
                    .opacity(friendIconDisabled && opponentFriendshipPhase != .incomingPending ? 0.55 : 1)
                    .accessibilityLabel(friendIconAccessibilityLabel)

                    Button {
                        openOpponentPeerProfileFromTopBar()
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FitUpColors.Text.secondary)
                            .frame(width: 34, height: 34)
                            .background(topBarChromeBackground)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View competitor profile")
                }
            }

            if let shareURL = URL(string: "https://fitup.app/match/\(viewModel.matchId.uuidString)") {
                ShareLink(item: shareURL) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.secondary)
                        .frame(width: 34, height: 34)
                        .background(topBarChromeBackground)
                }
                .padding(.leading, 6)
            }
        }
        .padding(.horizontal, 4)
    }

    /// Shared glass capsule background for trailing top-bar icons.
    private var topBarChromeBackground: some View {
        RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    /// Friend icon disabled when nothing to send (`Friends` / `Request sent`).
    private var friendIconDisabled: Bool {
        opponentFriendshipPhase == .outgoingPending || opponentFriendshipPhase == .accepted
    }

    private var friendTopBarSymbolName: String {
        switch opponentFriendshipPhase {
        case .accepted:
            return "person.2.fill"
        case .outgoingPending:
            return "paperplane.fill"
        case .incomingPending:
            return "person.crop.circle.badge.plus"
        case .none, .unknown:
            return "person.badge.plus"
        }
    }

    private var friendIconForegroundStyle: Color {
        switch opponentFriendshipPhase {
        case .accepted:
            return FitUpColors.Neon.green
        case .outgoingPending:
            return FitUpColors.Text.tertiary
        default:
            return FitUpColors.Text.secondary
        }
    }

    private var friendIconAccessibilityLabel: String {
        switch opponentFriendshipPhase {
        case .accepted:
            return "Friends with competitor"
        case .outgoingPending:
            return "Friend request sent"
        case .incomingPending:
            return "Open competitor profile to accept friend request"
        case .none, .unknown:
            return "Send friend request to competitor"
        }
    }

    private func messageCompetitorTapped() {
        guard let viewer = profile, let oid = viewModel.snapshot?.opponent.id else { return }
        guard viewer.id != oid else { return }
        if opponentFriendshipPhase == .accepted {
            Task {
                do {
                    _ = try await MessageRepository().ensureThread(
                        peerProfileId: oid,
                        currentProfileId: viewer.id
                    )
                    chatThreadPresentation = MatchChatPresentation(peerId: oid)
                } catch {
                    let msg = (error as? LocalizedError)?.errorDescription ?? ""
                    messagingAlertKind = .generic(body: msg.isEmpty
                        ? "Messaging is not ready yet. Please try again later."
                        : msg)
                }
            }
            return
        }
        messagingAlertKind = .blockedNotFriend
    }

    private func friendIconTapped() {
        switch opponentFriendshipPhase {
        case .incomingPending:
            openOpponentPeerProfileFromTopBar()
        case .accepted, .outgoingPending:
            return
        case .none, .unknown:
            Task { await sendFriendRequestToOpponent(showSuccessToast: true) }
        }
    }

    private func openOpponentPeerProfileFromTopBar() {
        guard profile != nil, let oid = viewModel.snapshot?.opponent.id else { return }
        peerProfileSheet = PeerProfileSheetItem(peerId: oid)
    }

    @MainActor
    private func sendFriendRequestToOpponent(showSuccessToast: Bool) async {
        guard let viewer = profile, let oid = viewModel.snapshot?.opponent.id else { return }
        guard viewer.id != oid else { return }
        guard opponentFriendshipPhase != .accepted,
              opponentFriendshipPhase != .outgoingPending
        else { return }

        friendRequestBusy = true
        defer { friendRequestBusy = false }
        do {
            try await FriendshipRepository().sendFriendRequest(from: viewer.id, to: oid)
            await refreshOpponentFriendshipPhase()
            if showSuccessToast {
                presentFriendRequestSentToast()
            }
        } catch {
            messagingAlertKind = .generic(body: "Could not send friend request.")
        }
    }

    private func dismissFriendRequestSentToastImmediately() {
        friendRequestToastTask?.cancel()
        friendRequestToastTask = nil
        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            showFriendRequestSentToast = false
        }
    }

    private func presentFriendRequestSentToast() {
        friendRequestToastTask?.cancel()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            showFriendRequestSentToast = true
        }
        friendRequestToastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            dismissFriendRequestSentToastImmediately()
        }
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

                    Button {
                        guard profile != nil else { return }
                        peerProfileSheet = PeerProfileSheetItem(peerId: snapshot.opponent.id)
                    } label: {
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
                    .buttonStyle(.plain)
                    .accessibilityLabel("View \(snapshot.opponent.displayName) profile")
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
        battleModeExplainerBlock(dm: dm)
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

            if let scoringPill = dm.snapshot.scoringModePillLabel {
                Text(scoringPill)
                    .font(FitUpFont.body(10, weight: .heavy))
                    .foregroundStyle(FitUpColors.Neon.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(FitUpColors.Neon.blue.opacity(0.08))
                            .overlay(Capsule().strokeBorder(FitUpColors.Neon.blue.opacity(0.22), lineWidth: 1))
                    )
            }

            if let diffPill = dm.snapshot.rawDifficultyPillLabel {
                Text(diffPill)
                    .font(FitUpFont.body(10, weight: .heavy))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.05))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                    )
            }

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

    private func battleModeExplainerBlock(dm: MatchDetailDisplayModel) -> some View {
        let expl = dm.snapshot.stepsBattleModeExplainer
        let foot = dm.snapshot.matchmakingResolutionFootnote
        let hasAny = !(expl?.isEmpty ?? true) || !(foot?.isEmpty ?? true)
        return Group {
            if hasAny {
                VStack(alignment: .leading, spacing: 6) {
                    if let expl, !expl.isEmpty {
                        Text(expl)
                            .font(FitUpFont.body(12, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let foot, !foot.isEmpty {
                        Text(foot)
                            .font(FitUpFont.mono(10, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
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
                    let myBattle = dm.snapshot.isBalancedStepsBattle
                        ? HomeActiveMatch.battleScore(
                            actualSteps: dm.myTodayDisplay,
                            myBaseline: dm.snapshot.myBaselineSteps,
                            theirBaseline: dm.snapshot.theirBaselineSteps
                        )
                        : nil
                    let theirBattle = dm.snapshot.isBalancedStepsBattle
                        ? HomeActiveMatch.battleScore(
                            actualSteps: dm.theirToday,
                            myBaseline: dm.snapshot.theirBaselineSteps,
                            theirBaseline: dm.snapshot.myBaselineSteps
                        )
                        : nil
                    let myPill = heroTodayPillStyle(dm: dm, forOpponent: false, myBattle: myBattle, theirBattle: theirBattle)
                    let theirPill = heroTodayPillStyle(dm: dm, forOpponent: true, myBattle: myBattle, theirBattle: theirBattle)
                    playerHeroColumn(
                        name: "You",
                        initials: dm.snapshot.me.initials,
                        border: FitUpColors.Neon.cyan,
                        seriesScore: dm.snapshot.myScore,
                        todaySteps: dm.myTodayDisplay,
                        todayPillStyle: myPill,
                        pulse: dm.snapshot.state == .active,
                        staleHint: dm.healthKitStale ? "May be stale" : nil,
                        primaryBattleScore: myBattle
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
                        seriesScore: dm.snapshot.theirScore,
                        todaySteps: dm.theirToday,
                        todayPillStyle: theirPill,
                        pulse: false,
                        staleHint: nil,
                        primaryBattleScore: theirBattle,
                        onTap: profile == nil
                            ? nil
                            : {
                                peerProfileSheet = PeerProfileSheetItem(peerId: dm.snapshot.opponent.id)
                            }
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

    private func heroTodayPillStyle(dm: MatchDetailDisplayModel, forOpponent: Bool, myBattle: Int?, theirBattle: Int?) -> HeroTodayPillStyle {
        switch dm.snapshot.state {
        case .pending:
            return forOpponent ? .trailing : .leading
        case .completed:
            if forOpponent {
                return dm.snapshot.isWinning ? .trailing : .leading
            }
            return dm.snapshot.isWinning ? .leading : .trailing
        case .active:
            if dm.snapshot.isBalancedStepsBattle, let mb = myBattle, let tb = theirBattle {
                if forOpponent {
                    if tb > mb { return .leading }
                    if mb > tb { return .trailing }
                    return .tied
                }
                if mb > tb { return .leading }
                if tb > mb { return .trailing }
                return .tied
            }
            if forOpponent {
                if dm.theirToday > dm.myTodayDisplay { return .leading }
                if dm.myTodayDisplay > dm.theirToday { return .trailing }
                return .tied
            }
            if dm.myTodayDisplay > dm.theirToday { return .leading }
            if dm.theirToday > dm.myTodayDisplay { return .trailing }
            return .tied
        }
    }

    private func playerHeroColumn(
        name: String,
        initials: String,
        border: Color,
        seriesScore: Int,
        todaySteps: Int,
        todayPillStyle: HeroTodayPillStyle,
        pulse: Bool,
        staleHint: String?,
        primaryBattleScore: Int? = nil,
        onTap: (() -> Void)? = nil
    ) -> some View {
        let inner = VStack(spacing: 6) {
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

            Text("Series wins \(seriesScore)")
                .font(FitUpFont.mono(9, weight: .medium))
                .foregroundStyle(FitUpColors.Text.tertiary)

            if let battle = primaryBattleScore {
                Text("\(battle)")
                    .font(FitUpFont.display(56, weight: .black))
                    .foregroundStyle(FitUpColors.Neon.cyan)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("Battle Score")
                    .font(FitUpFont.mono(10, weight: .bold))
                    .foregroundStyle(FitUpColors.Neon.cyan.opacity(0.85))
                    .padding(.top, -4)

                VStack(spacing: 2) {
                    Text("Actual Steps")
                        .font(FitUpFont.mono(9, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                    Text("\(todaySteps)")
                        .font(FitUpFont.mono(11, weight: .bold))
                        .foregroundStyle(todayPillStyle.foreground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(todayPillStyle.fill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(todayPillStyle.stroke, lineWidth: 1)
                                )
                        )
                }
                .padding(.top, 2)
            } else {
                Text("\(seriesScore)")
                    .font(FitUpFont.display(56, weight: .black))
                    .foregroundStyle(FitUpColors.Text.primary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("\(todaySteps)")
                    .font(FitUpFont.mono(11, weight: .bold))
                    .foregroundStyle(todayPillStyle.foreground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(todayPillStyle.fill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(todayPillStyle.stroke, lineWidth: 1)
                            )
                    )
            }

            if let staleHint {
                Text(staleHint)
                    .font(FitUpFont.mono(8, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.tertiary)
            }
        }
        .frame(maxWidth: .infinity)

        return Group {
            if let onTap {
                Button(action: onTap) {
                    inner
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View \(name) profile")
            } else {
                inner
            }
        }
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

    @ViewBuilder
    private func todayBattleRow(dm: MatchDetailDisplayModel) -> some View {
        if dm.snapshot.isBalancedStepsBattle {
            balancedTodayBattleRow(dm: dm)
        } else {
            rawOrCalorieTodayBattleRow(dm: dm)
        }
    }

    private func balancedTodayBattleRow(dm: MatchDetailDisplayModel) -> some View {
        let myB = HomeActiveMatch.battleScore(
            actualSteps: dm.myTodayDisplay,
            myBaseline: dm.snapshot.myBaselineSteps,
            theirBaseline: dm.snapshot.theirBaselineSteps
        )
        let theirB = HomeActiveMatch.battleScore(
            actualSteps: dm.theirToday,
            myBaseline: dm.snapshot.theirBaselineSteps,
            theirBaseline: dm.snapshot.myBaselineSteps
        )
        let myBalance = String(
            format: "%.1f×",
            HomeActiveMatch.balanceMultiplier(
                myEffective: HomeActiveMatch.effectiveBaselineSteps(baseline: dm.snapshot.myBaselineSteps),
                theirEffective: HomeActiveMatch.effectiveBaselineSteps(baseline: dm.snapshot.theirBaselineSteps)
            )
        )
        let theirBalance = String(
            format: "%.1f×",
            HomeActiveMatch.balanceMultiplier(
                myEffective: HomeActiveMatch.effectiveBaselineSteps(baseline: dm.snapshot.theirBaselineSteps),
                theirEffective: HomeActiveMatch.effectiveBaselineSteps(baseline: dm.snapshot.myBaselineSteps)
            )
        )
        let deltaTint: Color = myB == theirB
            ? FitUpColors.Text.secondary
            : (dm.isAheadToday ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("You")
                        .font(FitUpFont.body(11, weight: .heavy))
                        .foregroundStyle(FitUpColors.Neon.cyan)
                    Text("Actual Steps")
                        .font(FitUpFont.mono(9, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                    Text("\(dm.myTodayDisplay)")
                        .font(FitUpFont.display(18, weight: .heavy))
                        .foregroundStyle(FitUpColors.Text.secondary)
                    Text("Battle Score")
                        .font(FitUpFont.mono(9, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                    Text("\(myB)")
                        .font(FitUpFont.display(28, weight: .black))
                        .foregroundStyle(FitUpColors.Neon.cyan)
                    Text("Daily Avg")
                        .font(FitUpFont.mono(9, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                    Text(formatBaselineSteps(dm.snapshot.myBaselineSteps))
                        .font(FitUpFont.display(16, weight: .heavy))
                        .foregroundStyle(FitUpColors.Text.secondary)
                    Text("Balance")
                        .font(FitUpFont.mono(9, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                    Text(myBalance)
                        .font(FitUpFont.display(16, weight: .heavy))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(FitUpColors.Neon.green)
                            .frame(width: 7, height: 7)
                        Text("LIVE")
                            .font(FitUpFont.body(11, weight: .heavy))
                            .foregroundStyle(FitUpColors.Neon.green)
                    }
                    Text(dm.snapshot.opponent.displayName)
                        .font(FitUpFont.body(11, weight: .heavy))
                        .foregroundStyle(FitUpColors.Text.secondary)
                        .lineLimit(1)
                    Text("Actual Steps")
                        .font(FitUpFont.mono(9, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                    Text("\(dm.theirToday)")
                        .font(FitUpFont.display(18, weight: .heavy))
                        .foregroundStyle(FitUpColors.Text.secondary)
                    Text("Battle Score")
                        .font(FitUpFont.mono(9, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                    Text("\(theirB)")
                        .font(FitUpFont.display(28, weight: .black))
                        .foregroundStyle(FitUpColors.Neon.cyan.opacity(0.92))
                    Text("Daily Avg")
                        .font(FitUpFont.mono(9, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                    Text(formatBaselineSteps(dm.snapshot.theirBaselineSteps))
                        .font(FitUpFont.display(16, weight: .heavy))
                        .foregroundStyle(FitUpColors.Text.secondary)
                    Text("Balance")
                        .font(FitUpFont.mono(9, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                    Text(theirBalance)
                        .font(FitUpFont.display(16, weight: .heavy))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Text(dm.todayDeltaLabel)
                .font(FitUpFont.body(12, weight: .bold))
                .foregroundStyle(deltaTint)
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

    private func rawOrCalorieTodayBattleRow(dm: MatchDetailDisplayModel) -> some View {
        let deltaTint = dm.todayDelta >= 0 ? FitUpColors.Neon.cyan : FitUpColors.Neon.red
        let showRawStepsMeta = !dm.metricIsCalories && dm.snapshot.metricType == "steps" && dm.snapshot.scoringMode == "raw"
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dm.metricIsCalories ? "ACTIVE CALORIES" : "STEPS TODAY")
                    .font(FitUpFont.body(10, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(FitUpColors.Text.tertiary)

                Text("\(dm.myTodayDisplay)")
                    .font(FitUpFont.display(26, weight: .heavy))
                    .foregroundStyle(dm.isAheadToday ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange)

                if showRawStepsMeta {
                    Text("Daily Avg")
                        .font(FitUpFont.mono(9, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                    Text(formatBaselineSteps(dm.snapshot.myBaselineSteps))
                        .font(FitUpFont.display(16, weight: .heavy))
                        .foregroundStyle(FitUpColors.Text.secondary)
                    if let diff = dm.snapshot.rawDifficultyPillLabel {
                        Text("Difficulty")
                            .font(FitUpFont.mono(9, weight: .bold))
                            .foregroundStyle(FitUpColors.Text.tertiary)
                        Text(diff)
                            .font(FitUpFont.display(16, weight: .heavy))
                            .foregroundStyle(FitUpColors.Text.secondary)
                    }
                }

                Text(dm.todayDeltaLabel)
                    .font(FitUpFont.body(12, weight: .bold))
                    .foregroundStyle(deltaTint)
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
                if showRawStepsMeta {
                    Text("Daily Avg")
                        .font(FitUpFont.mono(9, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                    Text(formatBaselineSteps(dm.snapshot.theirBaselineSteps))
                        .font(FitUpFont.display(16, weight: .heavy))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }
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

            if dm.snapshot.isBalancedStepsBattle {
                statStatRow(
                    title: "Daily Avg",
                    left: formatBaselineSteps(dm.snapshot.myBaselineSteps),
                    right: formatBaselineSteps(dm.snapshot.theirBaselineSteps)
                )
                statStatRow(
                    title: "Series daily avg",
                    left: formatStatNumber(dm.dailyAverageMine, calories: false),
                    right: formatStatNumber(dm.dailyAverageTheirs, calories: false)
                )
            } else {
                statStatRow(
                    title: "Daily Avg",
                    left: formatStatNumber(dm.dailyAverageMine, calories: dm.metricIsCalories),
                    right: formatStatNumber(dm.dailyAverageTheirs, calories: dm.metricIsCalories)
                )
                if dm.snapshot.metricType == "steps", let diff = dm.snapshot.rawDifficultyPillLabel {
                    statStatRow(title: "Difficulty", left: diff, right: diff)
                }
            }

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

    private func formatBaselineSteps(_ baseline: Double?) -> String {
        guard let baseline, baseline > 0 else { return "—" }
        return "\(Int(baseline.rounded()))"
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

    private func refreshOpponentFriendshipPhase() async {
        guard let viewer = profile, let oid = viewModel.snapshot?.opponent.id else {
            opponentFriendshipPhase = .unknown
            return
        }
        opponentFriendshipPhase =
            (try? await FriendshipRepository().friendshipPhase(currentProfileId: viewer.id, peerProfileId: oid))
            ?? .unknown
    }
}

// MARK: - Friend request toast (match details)

private struct FriendRequestSentMatchDetailsToast: View {
    var onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        Button(action: onDismiss) {
            VStack(spacing: 6) {
                Text("FRIEND REQUEST SENT")
                    .font(FitUpFont.mono(13, weight: .heavy))
                    .foregroundStyle(FitUpColors.Neon.green)
                    .shadow(color: FitUpColors.Neon.green.opacity(0.38), radius: 8)

                Text("Tap to dismiss")
                    .font(FitUpFont.mono(10, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.tertiary)
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
                                        FitUpColors.Neon.green.opacity(0.82),
                                        FitUpColors.Neon.cyan.opacity(0.42),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.4
                            )
                    )
            )
            .shadow(color: FitUpColors.Neon.green.opacity(0.16), radius: 16)
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Friend request sent")
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }
}

private struct PeerProfileSheetItem: Identifiable, Equatable {
    let peerId: UUID
    var id: UUID { peerId }
}

private struct MatchChatPresentation: Identifiable, Equatable {
    let peerId: UUID
    var id: UUID { peerId }
}
