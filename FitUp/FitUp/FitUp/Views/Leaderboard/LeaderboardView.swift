//
//  LeaderboardView.swift
//  FitUp
//
//  Slice 11 — Leaderboard / Ranks tab root.
//

import SwiftUI

struct LeaderboardView: View {
    let profile: Profile?
    var onChallengeUser: (ChallengePrefillOpponent) -> Void

    @StateObject private var viewModel = LeaderboardViewModel()

    var body: some View {
        GeometryReader { scrollGeo in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header

                        if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(FitUpFont.body(12, weight: .semibold))
                                .foregroundStyle(FitUpColors.Neon.pink)
                                .padding(.bottom, 8)
                        }

                        tabToggle
                            .padding(.bottom, 18)

                        if viewModel.isLoading {
                            ProgressView()
                                .tint(FitUpColors.Neon.cyan)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        } else if viewModel.tab == .friends && viewModel.friendsHasNoOpponents {
                            friendsEmptyState
                        } else if viewModel.podiumRows.isEmpty && viewModel.listRows.isEmpty {
                            emptyLeaderboardState
                        } else {
                            PodiumView(rows: viewModel.podiumRows)
                                .padding(.bottom, 20)

                            ForEach(viewModel.listRows) { row in
                                RankedRowView(row: row, scrollGeo: scrollGeo) {
                                    onChallengeUser(
                                        ChallengePrefillOpponent(
                                            id: row.id,
                                            displayName: row.displayName,
                                            initials: row.initials,
                                            colorHex: row.colorHex
                                        )
                                    )
                                }
                                .padding(.bottom, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, viewModel.shouldShowPinnedUserBar ? 88 : 20)
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
            VStack(alignment: .leading, spacing: 2) {
                Text("Leaderboard")
                    .font(FitUpFont.display(22, weight: .heavy))
                    .foregroundStyle(FitUpColors.Text.primary)
                Text(viewModel.weekRangeLabel)
                    .font(FitUpFont.body(11, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
            }
            Spacer(minLength: 0)
            NeonBadge(label: "LIVE", color: FitUpColors.Neon.green)
        }
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var tabToggle: some View {
        HStack(spacing: 6) {
            ForEach(LeaderboardViewModel.LeaderboardTab.allCases, id: \.self) { tab in
                LeaderboardTabSegmentButton(
                    tab: tab,
                    isSelected: viewModel.tab == tab
                ) {
                    viewModel.tab = tab
                }
            }
        }
    }

    private var friendsEmptyState: some View {
        Text("Play matches to see friends on this board.")
            .font(FitUpFont.body(14, weight: .medium))
            .foregroundStyle(FitUpColors.Text.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassCard(.base)
    }

    private var emptyLeaderboardState: some View {
        Text("No scores yet this week.")
            .font(FitUpFont.body(14, weight: .medium))
            .foregroundStyle(FitUpColors.Text.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassCard(.base)
    }

    private func pinnedUserBar(_ row: LeaderboardDisplayRow) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(row.displayRank)")
                .font(FitUpFont.body(13, weight: .bold))
                .foregroundStyle(FitUpColors.Neon.cyan)
                .frame(width: 20, alignment: .center)

            AvatarView(
                initials: row.initials,
                color: ProfileAccentColor.swiftUIColor(hex: row.colorHex),
                size: 38,
                glow: true
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("You")
                    .font(FitUpFont.body(13, weight: .bold))
                    .foregroundStyle(FitUpColors.Neon.cyan)
                Text("\(row.wins)W · \(row.losses)L · 🔥\(row.streak)")
                    .font(FitUpFont.body(11, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(formatPoints(row.points))
                .font(FitUpFont.body(14, weight: .bold))
                .foregroundStyle(FitUpColors.Neon.cyan)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard(.win)
        .overlay {
            RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                .strokeBorder(FitUpColors.Neon.cyan.opacity(0.25), lineWidth: 1)
        }
    }

    private func formatPoints(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Global / Friends segmented control (extracted for faster type-checking)

private struct LeaderboardTabSegmentButton: View {
    let tab: LeaderboardViewModel.LeaderboardTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tab.title)
                .font(FitUpFont.body(12, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .foregroundStyle(isSelected ? FitUpColors.Neon.cyan : FitUpColors.Text.secondary)
                .background {
                    Capsule()
                        .fill(isSelected ? FitUpColors.Neon.cyanDim : Color.white.opacity(0.05))
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    isSelected
                                        ? FitUpColors.Neon.cyan.opacity(0.31)
                                        : Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        }
                }
        }
        .buttonStyle(.plain)
    }
}
