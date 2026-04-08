//
//  ProfileView.swift
//  FitUp
//
//  Slice 14 — Full Profile screen matching JSX ProfileScreen.
//  Hero card · Stats · Settings groups · Upgrade banner · Dev Tools · Sign Out
//

import SwiftUI

struct ProfileView: View {
    let profile: Profile?
    var onSignOut: () -> Void
    var onOpenPaywall: () -> Void

    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewModel = ProfileViewModel()
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    @AppStorage("firstMatchWon") private var firstMatchWon = false

    // Notifications toggle — persisted to Supabase on change.
    @State private var notificationsEnabled = true

    // Paywall sheet presented from "Manage Plan" / Upgrade rows.
    @State private var showPaywall = false

    @State private var showEditDisplayName = false
    @State private var editDisplayNameDraft = ""
    @State private var isSavingDisplayName = false

#if DEBUG
    @AppStorage("devMode") private var devMode = false
#endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                titleHeader
                heroCard
                upgradeBannerIfNeeded
                accountGroup
                subscriptionGroup
                devSection
                signOutRow
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 40)
        }
        .task {
            await viewModel.load(profile: profile)
            if let enabled = profile?.notificationsEnabled {
                notificationsEnabled = enabled
            }
        }
        .onChange(of: notificationsEnabled) { _, newValue in
            guard let authUserId = profile?.authUserId else { return }
            Task {
                await ProfileRepository().updateNotificationsEnabled(newValue, authUserId: authUserId)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView { showPaywall = false }
        }
        .sheet(isPresented: $showEditDisplayName) {
            editDisplayNameSheet
        }
    }

    // MARK: - Title

    private var titleHeader: some View {
        Text("Profile")
            .font(FitUpFont.display(22, weight: .black))
            .foregroundStyle(FitUpColors.Text.primary)
            .padding(.top, 4)
    }

    // MARK: - Hero card

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Avatar row
            HStack(spacing: 16) {
                AvatarView(
                    initials: profile?.initials ?? "FU",
                    color: FitUpColors.Neon.cyan,
                    size: 62,
                    glow: true
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(profile?.displayName ?? "—")
                        .font(FitUpFont.display(20, weight: .black))
                        .foregroundStyle(FitUpColors.Text.primary)

                    Text("@\(usernameSlug) · Level 1")
                        .font(FitUpFont.body(12))
                        .foregroundStyle(FitUpColors.Text.secondary)

                    HStack(spacing: 6) {
                        if subscriptionService.isPremium {
                            NeonBadge(label: "PRO", color: FitUpColors.Neon.yellow)
                        }
                        if viewModel.stats.winCount > 0 {
                            NeonBadge(
                                label: "\(viewModel.stats.winCount) WINS",
                                color: FitUpColors.Neon.cyan
                            )
                        }
                    }
                }
            }
            .padding(.bottom, 16)

            // Stats grid
            HStack(spacing: 8) {
                statTile(value: "\(viewModel.stats.matchCount)", label: "Matches")
                statTile(value: "\(viewModel.stats.winCount)",   label: "Wins")
                statTile(
                    value: viewModel.stats.streak > 0 ? "\(viewModel.stats.streak)🔥" : "0",
                    label: "Streak"
                )
            }
        }
        .padding(20)
        .glassCard(.win)
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(FitUpFont.display(18, weight: .black))
                .foregroundStyle(FitUpColors.Text.primary)
            Text(label)
                .font(FitUpFont.body(10))
                .foregroundStyle(FitUpColors.Text.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: FitUpRadius.sm))
    }

    // MARK: - Upgrade banner

    @ViewBuilder
    private var upgradeBannerIfNeeded: some View {
        if !subscriptionService.isPremium && firstMatchWon {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready to go Pro?")
                        .font(FitUpFont.body(14, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.primary)
                    Text("Unlimited matches, streak bonuses & more.")
                        .font(FitUpFont.body(12))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }
                Spacer()
                Button("Upgrade") { showPaywall = true }
                    .solidButton(color: FitUpColors.Neon.cyan)
            }
            .padding(16)
            .glassCard(.pending)
        }
    }

    // MARK: - ACCOUNT group

    private var accountGroup: some View {
        SettingsGroupView(title: "ACCOUNT") {
            SettingsRowView(
                sfSymbol: "person.text.rectangle",
                label: "Display name",
                showSeparator: true,
                action: .chevron {
                    sessionStore.authErrorMessage = nil
                    editDisplayNameDraft = profile?.displayName ?? ""
                    showEditDisplayName = true
                }
            )
            SettingsRowView(
                sfSymbol: "bell",
                label: "Notifications",
                showSeparator: true,
                action: .toggle($notificationsEnabled)
            )
            SettingsRowView(
                sfSymbol: "shield",
                label: "Privacy",
                showSeparator: true,
                action: .chevron()
            )
            SettingsRowView(
                sfSymbol: "gear",
                label: "Connected Apps",
                showSeparator: false,
                action: .chevron()
            )
        }
    }

    // MARK: - SUBSCRIPTION group

    private var subscriptionGroup: some View {
        SettingsGroupView(title: "SUBSCRIPTION") {
            if subscriptionService.isPremium {
                SettingsRowView(
                    sfSymbol: "crown",
                    label: "FitUp Pro · Active",
                    showSeparator: true,
                    action: .badge("PRO", FitUpColors.Neon.yellow)
                )
            } else {
                SettingsRowView(
                    sfSymbol: "crown",
                    label: "Upgrade to Pro",
                    showSeparator: true,
                    action: .chevron { showPaywall = true }
                )
            }
            SettingsRowView(
                sfSymbol: "star",
                label: "Manage Plan",
                showSeparator: false,
                action: .chevron { showPaywall = true }
            )
        }
    }

    // MARK: - Developer section (#if DEBUG)

    @ViewBuilder
    private var devSection: some View {
#if DEBUG
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroupView(title: "DEVELOPER") {
                SettingsRowView(
                    sfSymbol: "chevron.left.forwardslash.chevron.right",
                    label: "Dev Mode",
                    showSeparator: false,
                    action: .toggle($devMode)
                )
            }

            if devMode {
                Text("Paywall bypassed · Premium tier active")
                    .font(FitUpFont.body(11, weight: .medium))
                    .foregroundStyle(FitUpColors.Neon.green)
                    .padding(.top, 6)
                    .padding(.leading, 4)
                    .padding(.bottom, 4)

                LogViewerView(viewModel: viewModel, profile: profile)
                    .padding(.top, 8)
            }
        }
#endif
    }

    // MARK: - Sign Out row

    private var signOutRow: some View {
        SettingsRowView(
            sfSymbol: "rectangle.portrait.and.arrow.right",
            label: "Sign Out",
            isDanger: true,
            showSeparator: false,
            action: .chevron { onSignOut() }
        )
        .background(
            RoundedRectangle(cornerRadius: FitUpRadius.md)
                .fill(GlassCardVariant.base.fillGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: FitUpRadius.md)
                        .strokeBorder(GlassCardVariant.base.borderColor, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: FitUpRadius.md))
    }

    // MARK: - Edit display name

    private var editDisplayNameSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("This is how other players see you. Sign in with Apple only shares your name the first time you authorize the app—if you see a placeholder like “FitUp …”, set your name here.")
                    .font(FitUpFont.body(13))
                    .foregroundStyle(FitUpColors.Text.secondary)

                TextField("Display name", text: $editDisplayNameDraft)
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .foregroundStyle(FitUpColors.Text.primary)
                    .background(
                        RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                            .fill(FitUpColors.Bg.base.opacity(0.55))
                            .overlay(
                                RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )

                if let err = sessionStore.authErrorMessage, !err.isEmpty {
                    Text(err)
                        .font(FitUpFont.body(13, weight: .medium))
                        .foregroundStyle(FitUpColors.Neon.pink)
                }

                Spacer()
            }
            .padding(20)
            .background(BackgroundGradientView())
            .navigationTitle("Display name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        sessionStore.authErrorMessage = nil
                        showEditDisplayName = false
                    }
                    .disabled(isSavingDisplayName)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isSavingDisplayName = true
                            defer { isSavingDisplayName = false }
                            await sessionStore.updateDisplayName(editDisplayNameDraft)
                            if sessionStore.authErrorMessage == nil {
                                showEditDisplayName = false
                            }
                        }
                    }
                    .disabled(isSavingDisplayName || editDisplayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: - Helpers

    private var usernameSlug: String {
        guard let name = profile?.displayName else { return "user" }
        return name.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .prefix(20)
            .description
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        BackgroundGradientView()
        ProfileView(
            profile: nil,
            onSignOut: {},
            onOpenPaywall: {}
        )
        .environmentObject(SessionStore())
    }
}
