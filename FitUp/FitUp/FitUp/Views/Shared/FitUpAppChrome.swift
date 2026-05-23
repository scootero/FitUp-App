//
//  FitUpAppChrome.swift
//  FitUp
//
//  Sticky top bar (FIT UP · alerts · messages · new battle) shared across main tabs and full-screen flows.
//

import SwiftUI

// MARK: - Brand mark

struct FitUpBrandMark: View {
    var fontSize: CGFloat = 27

    var body: some View {
        HStack(spacing: 0) {
            Text("FIT")
                .font(FitUpFont.display(fontSize, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Text("UP")
                .font(FitUpFont.display(fontSize, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [FitUpColors.Neon.orange, FitUpColors.Neon.yellow],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("FitUp")
    }
}

// MARK: - Top bar

struct FitUpAppTopBar: View {
    @EnvironmentObject private var notificationService: NotificationService

    var firstName: String
    var showsGreeting: Bool = true
    var unreadMessageCount: Int = 0
    var onNotifications: () -> Void
    var onMessages: () -> Void
    var onNewBattle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: showsGreeting ? 5 : 0) {
            HStack(alignment: .center, spacing: 10) {
                FitUpBrandMark()
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    notificationsButton
                    messagesButton
                    newBattleButton
                }
            }

            if showsGreeting {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Let's go, \(firstName)")
                        .font(FitUpFont.body(11, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)

                    Text("It's battle time. Check your edge before you jump in.")
                        .font(FitUpFont.body(11, weight: .semibold))
                        .lineSpacing(1.1)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    FitUpColors.Neon.cyan.opacity(0.92),
                                    FitUpColors.Neon.blue.opacity(0.88),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: FitUpColors.Neon.blue.opacity(0.28), radius: 2, x: 1, y: 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.trailing, 8)
            }
        }
        .accessibilityElement(children: .contain)
    }

    static func firstName(from profile: Profile?) -> String {
        let full = profile?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Athlete"
        return full.split(separator: " ").first.map(String.init) ?? full
    }

    private var notificationsButton: some View {
        Button(action: onNotifications) {
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

    private var messagesButton: some View {
        Button(action: onMessages) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(unreadMessageCount > 0 ? FitUpColors.Neon.cyan : FitUpColors.Text.secondary)
                    .frame(width: 36, height: 36)
                    .homeLiquidGlassCard(.base)

                if unreadMessageCount > 0 {
                    Text(unreadMessageCount > 9 ? "9+" : "\(unreadMessageCount)")
                        .font(FitUpFont.mono(9, weight: .heavy))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(FitUpColors.Neon.pink)
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.85), lineWidth: 1))
                        )
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unreadMessageCount > 0 ? "Messages, \(unreadMessageCount) unread" : "Messages")
    }

    private var newBattleButton: some View {
        Button(action: onNewBattle) {
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
        .accessibilityLabel("New battle")
    }
}

// MARK: - Chrome container

struct FitUpAppChromeContainer<Content: View>: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var notificationService: NotificationService

    let profile: Profile?
    var showsGreeting: Bool = true
    var onOpenChallenge: () -> Void
    var onOpenMatchDetails: (UUID, String) -> Void
    @ViewBuilder var content: () -> Content

    @State private var isNotificationInboxVisible = false
    @State private var recapCardsInInbox: [RecapMatchCard] = []
    @State private var unreadMessageCount = 0
    @State private var markReadTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content()

            if isNotificationInboxVisible {
                FitUpNotificationInboxOverlay(
                    recapCards: recapCardsInInbox,
                    onDismiss: { dismissNotificationInbox() },
                    onRecapTap: handleRecapCardTap,
                    onInboxItemTap: handleInboxTap
                )
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            FitUpAppTopBar(
                firstName: FitUpAppTopBar.firstName(from: profile),
                showsGreeting: showsGreeting,
                unreadMessageCount: unreadMessageCount,
                onNotifications: { toggleNotificationInbox() },
                onMessages: { openMessages() },
                onNewBattle: onOpenChallenge
            )
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, showsGreeting ? 10 : 6)
            .background(chromeBarBackground)
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { sessionStore.shouldPresentMessages },
                set: { new in
                    if !new { sessionStore.dismissMessagesPresentation() }
                }
            )
        ) {
            messagesCover
        }
        .task(id: profile?.id) {
            await refreshUnreadMessageCount()
        }
        .onChange(of: sessionStore.shouldPresentMessages) { _, open in
            if open { Task { await refreshUnreadMessageCount() } }
        }
        .onChange(of: notificationService.shouldPresentHomeInbox) { _, shouldPresent in
            guard shouldPresent else { return }
            _ = notificationService.consumePresentHomeInbox()
            let recap = notificationService.consumeRecapCards()
            if !recap.isEmpty {
                recapCardsInInbox = recap
            }
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                isNotificationInboxVisible = true
            }
            scheduleInboxAutoRead()
        }
        .onDisappear {
            markReadTask?.cancel()
        }
    }

    private var chromeBarBackground: some View {
        Color(rgb: 0x0A1020)
            .opacity(0.92)
            .ignoresSafeArea(edges: .top)
    }

    @ViewBuilder
    private var messagesCover: some View {
        NavigationStack {
            MessagesInboxView(
                profile: profile,
                initialPeerId: sessionStore.pendingMessagesPeerId
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        sessionStore.dismissMessagesPresentation()
                        Task { await refreshUnreadMessageCount() }
                    }
                }
            }
        }
        .trackProductScreen("messages_inbox", userId: profile?.id)
    }

    private func openMessages() {
        if let uid = profile?.id {
            ProductAnalytics.track(
                ProductAnalytics.Event.messagesOpened,
                userId: uid,
                properties: ["source": "app_top_bar"]
            )
        }
        sessionStore.requestOpenMessages(peerId: nil)
    }

    private func refreshUnreadMessageCount() async {
        guard let profile else {
            unreadMessageCount = 0
            return
        }
        let items = (try? await MessageRepository().fetchInbox(currentProfileId: profile.id)) ?? []
        unreadMessageCount = MessageReadStore.unreadCount(profileId: profile.id, items: items)
    }

    private func toggleNotificationInbox() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            isNotificationInboxVisible.toggle()
        }
        if isNotificationInboxVisible {
            scheduleInboxAutoRead()
        } else {
            markReadTask?.cancel()
        }
    }

    private func dismissNotificationInbox() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.87)) {
            isNotificationInboxVisible = false
        }
        markReadTask?.cancel()
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

    private func handleRecapCardTap(_ card: RecapMatchCard) {
        recapCardsInInbox = []
        dismissNotificationInbox()
        onOpenMatchDetails(card.matchId, card.rivalDisplayName)
    }

    private func handleInboxTap(_ item: InAppNotificationItem) {
        notificationService.markInboxItemRead(item.id)
        dismissNotificationInbox()

        if let matchId = item.matchId {
            onOpenMatchDetails(matchId, "Match")
            return
        }

        if item.eventType == "friend_request_received" || item.deepLinkTarget == "friends" {
            sessionStore.requestOpenFriendsListSheet()
            return
        }

        if item.eventType == "message_received" || item.deepLinkTarget == "messages" {
            sessionStore.requestOpenMessages(peerId: item.peerProfileId)
        }
    }
}

// MARK: - Notification inbox overlay

struct FitUpNotificationInboxOverlay: View {
    @EnvironmentObject private var notificationService: NotificationService

    let recapCards: [RecapMatchCard]
    var onDismiss: () -> Void
    var onRecapTap: (RecapMatchCard) -> Void
    var onInboxItemTap: (InAppNotificationItem) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 8) {
                Text("Notifications")
                    .font(FitUpFont.mono(12, weight: .heavy))
                    .foregroundStyle(FitUpColors.Neon.cyan)
                    .fitUpGlobalTitleStyle(weight: .heavy, tracking: 0.5)

                if recapCards.isEmpty && notificationService.inboxItems.isEmpty {
                    Text("No alerts yet.")
                        .font(FitUpFont.body(13, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            if !recapCards.isEmpty {
                                Text("YESTERDAY'S RESULTS")
                                    .font(FitUpFont.mono(10, weight: .heavy))
                                    .foregroundStyle(FitUpColors.Neon.orange)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                ForEach(recapCards) { card in
                                    recapCardRow(card)
                                        .onTapGesture { onRecapTap(card) }
                                }
                            }
                            ForEach(notificationService.inboxItems) { item in
                                inboxRow(for: item)
                                    .onTapGesture { onInboxItemTap(item) }
                            }
                        }
                    }
                    .frame(maxHeight: 360)
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
            .padding(.top, 100)
            .padding(.trailing, 16)
            .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.98, anchor: .topTrailing)))
        }
        .zIndex(8)
    }

    private func recapCardRow(_ card: RecapMatchCard) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("vs \(card.rivalDisplayName)")
                    .font(FitUpFont.body(13, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.primary)
                Spacer(minLength: 0)
                if card.isFinalDay {
                    Text("FINAL DAY")
                        .font(FitUpFont.mono(9, weight: .heavy))
                        .foregroundStyle(FitUpColors.Neon.orange)
                }
            }
            if let yesterday = card.yesterdaySummary {
                Text(yesterday)
                    .font(FitUpFont.body(12, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
            }
            Text("Series \(card.seriesLabel) · \(card.daysLeftLabel)")
                .font(FitUpFont.mono(10, weight: .semibold))
                .foregroundStyle(FitUpColors.Neon.cyan)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
                .fill(FitUpColors.Neon.orange.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
                .strokeBorder(FitUpColors.Neon.orange.opacity(0.45), lineWidth: 1)
        )
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
        case "yesterday_recap", "final_day_comeback":
            return "sportscourt.fill"
        case "friend_request_received", "friend_request_accepted":
            return "person.2.fill"
        case "message_received":
            return "bubble.left.and.text.bubble.right.fill"
        default:
            return "bell.fill"
        }
    }

    private func iconColor(for item: InAppNotificationItem) -> Color {
        switch item.eventType {
        case "match_found", "challenge_received", "match_active":
            return item.isRead ? FitUpColors.Neon.blue : FitUpColors.Neon.cyan
        case "yesterday_recap", "final_day_comeback":
            return item.isRead ? FitUpColors.Neon.orange.opacity(0.7) : FitUpColors.Neon.orange
        case "friend_request_received", "friend_request_accepted":
            return item.isRead ? FitUpColors.Neon.purple : FitUpColors.Neon.green
        case "message_received":
            return item.isRead ? FitUpColors.Neon.blue : FitUpColors.Neon.cyan
        default:
            return item.isRead ? FitUpColors.Text.tertiary : FitUpColors.Neon.orange
        }
    }
}
