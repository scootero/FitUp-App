//
//  LeaderboardView.swift
//  FitUp
//
//  Slice 11 — Leaderboard / Ranks tab root.
//

import SwiftUI

struct LeaderboardView: View {
    let profile: Profile?

    @StateObject private var viewModel = LeaderboardViewModel()
    @State private var peerProfileSheet: LeaderboardPeerProfileItem?

    var body: some View {
        ZStack {
        GeometryReader { scrollGeo in
            ZStack(alignment: .bottom) {
                LeaderboardArcadeBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header

                        if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(FitUpFont.body(12, weight: .semibold))
                                .foregroundStyle(FitUpColors.Neon.pink)
                                .shadow(color: FitUpColors.Neon.pink.opacity(0.4), radius: 6, x: 0, y: 0)
                                .padding(.bottom, 8)
                        }

                        tabToggle
                            .padding(.bottom, 20)

                        if viewModel.isLoading {
                            ProgressView()
                                .tint(FitUpColors.Neon.cyan)
                                .shadow(color: FitUpColors.Neon.cyan.opacity(0.5), radius: 10, x: 0, y: 0)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                        } else if viewModel.tab == .friends && viewModel.friendsHasNoFriends {
                            friendsEmptyState
                        } else if viewModel.podiumRows.isEmpty && viewModel.listRows.isEmpty {
                            emptyLeaderboardState
                        } else {
                            PodiumView(rows: viewModel.podiumRows) { row in
                                openPeerProfile(row)
                            }
                                .padding(.bottom, 22)

                            ForEach(viewModel.listRows) { row in
                                RankedRowView(row: row, scrollGeo: scrollGeo) {
                                    openPeerProfile(row)
                                }
                                .padding(.bottom, 10)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, viewModel.shouldShowPinnedUserBar ? 92 : 24)
                }
                .scrollIndicators(.hidden)

                if viewModel.shouldShowPinnedUserBar, let pinned = viewModel.pinnedUserRow() {
                    pinnedUserBar(pinned)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let item = peerProfileSheet, let profile {
                PeerProfileView(
                    peerId: item.peerId,
                    viewer: profile,
                    onClose: { peerProfileSheet = nil }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: peerProfileSheet != nil)
        .onPreferenceChange(LeaderboardUserRowVisibilityPreferenceKey.self) { visible in
            viewModel.isCurrentUserListRowVisible = visible
        }
        .onChange(of: viewModel.listRows) { _, rows in
            if !rows.contains(where: \.isCurrentUser) {
                viewModel.isCurrentUserListRowVisible = true
            }
        }
        .task(id: profile?.id) {
            await viewModel.load(profile: profile)
        }
        .onChange(of: viewModel.tab) { _, _ in
            viewModel.isCurrentUserListRowVisible = true
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                NeonPanelTitle(title: "Weekly Steps", style: .standard, accent: FitUpColors.Neon.pink)
                Text(viewModel.weekRangeLabel)
                    .font(FitUpFont.mono(11, weight: .semibold))
                    .foregroundStyle(HomePageStyle.muted)
            }
            Spacer(minLength: 0)
            NeonBadge(label: "MON–SUN", color: FitUpColors.Neon.cyan)
                .shadow(color: FitUpColors.Neon.cyan.opacity(0.35), radius: 8, x: 0, y: 0)
        }
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    private var tabToggle: some View {
        HStack(spacing: 8) {
            ForEach(LeaderboardViewModel.LeaderboardTab.allCases, id: \.self) { tab in
                NeonLeaderboardTabSegment(
                    title: tab.title,
                    isSelected: viewModel.tab == tab
                ) {
                    viewModel.tab = tab
                }
            }
        }
    }

    private var friendsEmptyState: some View {
        emptyStateCard(
            "Add friends from Profile to see them ranked here for this week."
        )
    }

    private var emptyLeaderboardState: some View {
        emptyStateCard(
            viewModel.tab == .friends
                ? "No friends have logged steps this week yet."
                : "No step totals yet this week."
        )
    }

    private func emptyStateCard(_ message: String) -> some View {
        Text(message)
            .font(FitUpFont.body(14, weight: .medium))
            .foregroundStyle(HomePageStyle.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .neonLeaderboardRow()
    }

    private func pinnedUserBar(_ row: LeaderboardDisplayRow) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(row.displayRank)")
                .font(FitUpFont.mono(13, weight: .bold))
                .foregroundStyle(FitUpColors.Neon.cyan)
                .shadow(color: FitUpColors.Neon.cyan.opacity(0.45), radius: 6, x: 0, y: 0)
                .frame(width: 22, alignment: .center)

            AvatarView(
                initials: row.initials,
                color: ProfileAccentColor.swiftUIColor(hex: row.colorHex),
                size: 38,
                glow: true
            )
            .overlay {
                Circle()
                    .strokeBorder(FitUpColors.Neon.cyan.opacity(0.85), lineWidth: 2)
                    .frame(width: 44, height: 44)
                    .shadow(color: FitUpColors.Neon.cyan.opacity(0.4), radius: 8, x: 0, y: 0)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("You")
                        .font(FitUpFont.body(13, weight: .bold))
                        .foregroundStyle(FitUpColors.Neon.cyan)
                    Text("ME")
                        .font(FitUpFont.mono(9, weight: .bold))
                        .foregroundStyle(FitUpColors.Neon.pink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            Capsule()
                                .fill(FitUpColors.Neon.pink.opacity(0.16))
                                .overlay {
                                    Capsule()
                                        .strokeBorder(FitUpColors.Neon.pink.opacity(0.45), lineWidth: 1)
                                }
                        }
                }
                Text("Weekly steps")
                    .font(FitUpFont.body(11, weight: .medium))
                    .foregroundStyle(HomePageStyle.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(formatSteps(row.totalSteps))
                .font(FitUpFont.mono(13, weight: .bold))
                .foregroundStyle(FitUpColors.Neon.cyan)
                .shadow(color: FitUpColors.Neon.cyan.opacity(0.35), radius: 6, x: 0, y: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .neonLeaderboardRow(isCurrentUser: true, isPinned: true)
    }

    private func formatSteps(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        let formatted = f.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formatted) steps"
    }

    private func openPeerProfile(_ row: LeaderboardDisplayRow) {
        guard !row.isCurrentUser else { return }
        if let uid = profile?.id {
            ProductAnalytics.track(
                ProductAnalytics.Event.opponentProfileViewed,
                userId: uid,
                properties: [
                    "opponent_user_id": row.id.uuidString,
                    "source": "leaderboard",
                ]
            )
        }
        peerProfileSheet = LeaderboardPeerProfileItem(peerId: row.id)
    }
}

private struct LeaderboardPeerProfileItem: Identifiable, Equatable {
    let peerId: UUID
    var id: UUID { peerId }
}
