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

    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewModel = ProfileViewModel()
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    // Paywall sheet presented from "Manage Plan" / Upgrade rows.
    @State private var showPaywall = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var proCardIsGlowing = false

    @State private var showEditDisplayName = false
    @State private var editDisplayNameDraft = ""
    @State private var isSavingDisplayName = false
    @State private var showFeedback = false

    @State private var showEditDailyStepGoal = false
    @State private var displayedDailyStepGoal: Int = ReadinessGoals.loadFromUserDefaults().stepsGoal

    var body: some View {
        NavigationStack {
            ZStack {
                // Profile owns an opaque dark canvas so it remains legible when iOS is in Light Mode.
                FitUpColors.Bg.base
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        titleHeader
                        heroCard
                        fitOffProCard
                        accountGroup
                        subscriptionGroup
                        healthDataInfoGroup
                        // App Store delivery: developer tools stay commented out so Profile looks production-ready.
                        // Uncomment `devSection` (and the block inside it) to restore local Debug tools.
                        // devSection
                        signOutRow
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    // Extra clearance so Sign Out rests above the floating tab bar.
                    .padding(.bottom, 80)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await viewModel.load(profile: profile)
                await subscriptionService.refresh()
                syncDisplayedDailyStepGoal()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView { showPaywall = false }
                    .environmentObject(sessionStore)
            }
            .sheet(isPresented: $showFeedback) {
                if let userId = profile?.id {
                    TesterFeedbackSheet(userId: userId, onSuccess: nil)
                }
            }
            .sheet(isPresented: $showEditDisplayName) {
                editDisplayNameSheet
            }
            .sheet(isPresented: $showEditDailyStepGoal) {
                EditDailyStepGoalSheet(initialGoal: displayedDailyStepGoal) { goal in
                    displayedDailyStepGoal = goal
                }
            }
        }
    }

    // MARK: - Title

    private var titleHeader: some View {
        Text("Profile")
            .font(FitUpFont.display(22, weight: .black))
            .fitUpGlobalTitleStyle(weight: .black, tracking: 0.3)
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

    // MARK: - FitOff Pro card

    private var fitOffProCard: some View {
        VStack(spacing: 14) {
            Button { showPaywall = true } label: {
                VStack(spacing: 9) {
                    Image(systemName: subscriptionService.isPremium ? "checkmark.seal.fill" : "crown.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(subscriptionService.isPremium ? FitUpColors.Neon.green : FitUpColors.Neon.yellow)
                        .frame(width: 44, height: 44)
                        .background(
                            (subscriptionService.isPremium ? FitUpColors.Neon.green : FitUpColors.Neon.yellow)
                                .opacity(0.14),
                            in: Circle()
                        )
                        .scaleEffect(proCardIsGlowing ? 1.06 : 1)

                    Text(SubscriptionConfig.displayName)
                        .font(FitUpFont.display(27, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    if subscriptionService.isPremium {
                        NeonBadge(label: "ACTIVE", color: FitUpColors.Neon.green)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Text("Run as many battles at once as you want.")
                .font(FitUpFont.body(14, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(FitUpColors.Text.primary)

            Button("See all benefits") { showPaywall = true }
                .font(FitUpFont.body(12, weight: .semibold))
                .foregroundStyle(FitUpColors.Neon.cyan)
                .underline()

            Text("\(profileProPriceText). Cancel anytime.")
                .font(FitUpFont.body(12, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.secondary)

            Button(subscriptionService.isPremium ? "View Plan" : "Continue") {
                showPaywall = true
            }
            .solidButton(color: FitUpColors.Neon.cyan)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                .fill(GlassCardVariant.base.fillGradient)
                .overlay {
                    RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [FitUpColors.Neon.cyan.opacity(0.9), FitUpColors.Neon.orange.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.4
                        )
                }
        )
        .shadow(color: FitUpColors.Neon.cyan.opacity(0.22), radius: 14, y: 6)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                proCardIsGlowing = true
            }
        }
    }

    private var profileProPriceText: String {
        guard let price = subscriptionService.monthlyDisplayPrice else {
            return SubscriptionConfig.monthlyPriceFallback
        }
        return "\(price)/month"
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
            NavigationLink {
                FriendsListView(profile: profile)
            } label: {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.07))
                                .frame(width: 28, height: 28)
                            Image(systemName: "person.2")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(FitUpColors.Text.secondary)
                        }
                        Text("Friends")
                            .font(FitUpFont.body(14))
                            .foregroundStyle(FitUpColors.Text.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FitUpColors.Text.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1)
                        .padding(.leading, 54)
                }
            }
            .buttonStyle(.plain)
            NavigationLink {
                MessagesInboxView(profile: profile)
            } label: {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.07))
                                .frame(width: 28, height: 28)
                            Image(systemName: "bubble.left.and.text.bubble.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(FitUpColors.Text.secondary)
                        }
                        Text("Messages")
                            .font(FitUpFont.body(14))
                            .foregroundStyle(FitUpColors.Text.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FitUpColors.Text.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1)
                        .padding(.leading, 54)
                }
            }
            .buttonStyle(.plain)
            NavigationLink {
                BlockedUsersView()
            } label: {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.07))
                                .frame(width: 28, height: 28)
                            Image(systemName: "hand.raised")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(FitUpColors.Text.secondary)
                        }
                        Text("Blocked Users")
                            .font(FitUpFont.body(14))
                            .foregroundStyle(FitUpColors.Text.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FitUpColors.Text.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).padding(.leading, 54)
                }
            }
            .buttonStyle(.plain)
            SettingsRowView(
                sfSymbol: "bubble.left.and.bubble.right",
                label: "Send feedback",
                showSeparator: true,
                action: .chevron { showFeedback = true }
            )
            NavigationLink {
                LiveActivitiesNotificationsSettingsView(profile: profile)
            } label: {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.07))
                                .frame(width: 28, height: 28)
                            Image(systemName: "bell.badge")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(FitUpColors.Text.secondary)
                        }
                        Text(NotificationPreferences.isLiveActivitiesFeatureAvailable ? "Live Activities & Notifications" : "Notifications")
                            .font(FitUpFont.body(14))
                            .foregroundStyle(FitUpColors.Text.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FitUpColors.Text.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1)
                        .padding(.leading, 54)
                }
            }
            .buttonStyle(.plain)
            SettingsRowView(
                sfSymbol: "shield",
                label: "Privacy",
                showSeparator: true,
                action: .chevron {
                    openURL(LegalLinks.privacy)
                }
            )
            NavigationLink {
                AccountDeletionRequestView(profile: profile)
            } label: {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.07))
                                .frame(width: 28, height: 28)
                            Image(systemName: "person.crop.circle.badge.minus")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(FitUpColors.Text.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Delete Account")
                                .font(FitUpFont.body(14))
                                .foregroundStyle(FitUpColors.Neon.pink)
                            Text("Permanently delete your FitOff account and associated data.")
                                .font(FitUpFont.body(11))
                                .foregroundStyle(FitUpColors.Text.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FitUpColors.Text.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - SUBSCRIPTION group

    private var subscriptionGroup: some View {
        SettingsGroupView(title: "SUBSCRIPTION") {
            if subscriptionService.isPremium {
                SettingsRowView(
                    sfSymbol: "crown",
                    label: "FitOff Pro · Active",
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

    // MARK: - DATA (Health)

    private var healthDataInfoGroup: some View {
        SettingsGroupView(title: "DATA") {
            SettingsRowView(
                sfSymbol: "figure.walk",
                label: "Daily Step Goal",
                detail: displayedDailyStepGoal.formatted(),
                showSeparator: true,
                action: .chevron {
                    showEditDailyStepGoal = true
                }
            )
            NavigationLink {
                HealthDataBreakdownView(profile: profile)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.07))
                            .frame(width: 28, height: 28)
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FitUpColors.Text.secondary)
                    }
                    Text("Health Data Info")
                        .font(FitUpFont.body(14))
                        .foregroundStyle(FitUpColors.Text.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Developer section (Debug builds only)
    //
    // Commented out for App Store delivery so Profile does not show local-only tools.
    // To bring them back on a Debug build, uncomment this whole block and the
    // `devSection` call in `body`.
    //
    // @ViewBuilder
    // private var devSection: some View {
    //     #if DEBUG
    //     VStack(alignment: .leading, spacing: 0) {
    //         SettingsGroupView(title: "DEVELOPER") {
    //             VStack(alignment: .leading, spacing: 10) {
    //                 Text("Subscription Access")
    //                     .font(FitUpFont.body(13, weight: .semibold))
    //                     .foregroundStyle(FitUpColors.Text.secondary)
    //
    //                 Picker("Subscription Access", selection: $subscriptionService.debugMode) {
    //                     ForEach(DebugSubscriptionMode.allCases) { mode in
    //                         Text(mode.title).tag(mode)
    //                     }
    //                 }
    //                 .pickerStyle(.segmented)
    //
    //                 Text(debugSubscriptionStatusLine)
    //                     .font(FitUpFont.body(11, weight: .medium))
    //                     .foregroundStyle(FitUpColors.Neon.green)
    //             }
    //             .padding(.horizontal, 14)
    //             .padding(.vertical, 12)
    //         }
    //
    //         NavigationLink {
    //             AnalyticsDebugView()
    //         } label: {
    //             HStack {
    //                 Text("Analytics (recent events)")
    //                     .font(FitUpFont.body(14, weight: .medium))
    //                     .foregroundStyle(FitUpColors.Text.primary)
    //                 Spacer()
    //                 Image(systemName: "chevron.right")
    //                     .font(.system(size: 13, weight: .semibold))
    //                     .foregroundStyle(FitUpColors.Text.tertiary)
    //             }
    //             .padding(14)
    //             .glassCard(.base)
    //         }
    //         .buttonStyle(.plain)
    //         .padding(.top, 8)
    //         .padding(.bottom, 8)
    //
    //         LogViewerView(viewModel: viewModel, profile: profile)
    //             .padding(.top, 8)
    //     }
    //     #endif
    // }
    //
    // #if DEBUG
    // private var debugSubscriptionStatusLine: String {
    //     switch subscriptionService.debugMode {
    //     case .pro:
    //         return "Debug Pro · feature access forced on · StoreKit still runs"
    //     case .free:
    //         return "Debug Free · feature access forced off · StoreKit still runs"
    //     case .system:
    //         return subscriptionService.isSubscribed
    //             ? "Debug System · following StoreKit · Pro active"
    //             : "Debug System · following StoreKit · Free"
    //     }
    // }
    // #endif

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
                Text("This is how other players see you. Sign in with Apple only shares your name the first time you authorize the app—if you see a placeholder like “FitOff …”, set your name here.")
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

    private func syncDisplayedDailyStepGoal() {
        displayedDailyStepGoal = ReadinessGoals.loadFromUserDefaults().stepsGoal
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
