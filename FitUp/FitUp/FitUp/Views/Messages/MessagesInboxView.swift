//
//  MessagesInboxView.swift
//  FitUp
//
//  Simple list of 1:1 threads (MVP).
//

import SwiftUI

struct MessagesInboxView: View {
    let profile: Profile?
    var initialPeerId: UUID?

    @State private var items: [InboxThreadItem] = []
    @State private var peers: [UUID: PeerPublicProfile] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var chatPeerId: UUID?

    private let repository = MessageRepository()
    private let profileRepo = ProfileRepository()

    var body: some View {
        ZStack {
            MessagingDiscoBackground()
            Group {
                if profile == nil {
                    Text("Sign in to use Messages.")
                        .font(FitUpFont.body(15, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage, !errorMessage.isEmpty {
                    VStack(spacing: 10) {
                        Text(errorMessage)
                            .font(FitUpFont.body(15, weight: .semibold))
                            .foregroundStyle(FitUpColors.Neon.pink)
                            .multilineTextAlignment(.center)
                        Button("Try again") {
                            Task { await load() }
                        }
                        .font(FitUpFont.body(14, weight: .bold))
                        .foregroundStyle(FitUpColors.Neon.cyan)
                    }
                    .padding(.horizontal, MessagingLayout.horizontalInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isLoading, items.isEmpty {
                    ProgressView()
                        .tint(FitUpColors.Neon.cyan)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    Text("No messages yet.")
                        .font(FitUpFont.display(26, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: FitUpColors.Neon.cyan.opacity(0.5), radius: 12)
                        .shadow(color: FitUpColors.Neon.orange.opacity(0.3), radius: 6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(items) { row in
                                if let profile {
                                    Button {
                                        chatPeerId = row.peerProfileId
                                    } label: {
                                        inboxRow(row)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, MessagingLayout.horizontalInset)
                        .padding(.vertical, MessagingLayout.verticalInset)
                    }
                }
            }
        }
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $chatPeerId) { peerId in
            if let profile {
                ChatThreadView(peerProfileId: peerId, viewer: profile, showCloseInToolbar: false)
            }
        }
        .task {
            await load()
            if let initialPeerId {
                chatPeerId = initialPeerId
            }
        }
        .refreshable {
            await load()
        }
        .onChange(of: chatPeerId) { _, new in
            if new == nil {
                Task { await load() }
            }
        }
    }

    private func inboxRow(_ row: InboxThreadItem) -> some View {
        let id = row.peerProfileId
        let peer = peers[id]
        let hex = ProfileAccentColor.hex(for: id)
        let color = ProfileAccentColor.swiftUIColor(hex: hex)
        let title = peer?.displayName ?? "Competitor"
        let initials = peer?.initials ?? String(id.uuidString.prefix(2)).uppercased()
        let unread = row.hasUnread

        return HStack(alignment: .center, spacing: 14) {
            ZStack(alignment: .topTrailing) {
                AvatarView(initials: initials, color: color, size: 54, glow: unread)
                if unread {
                    Circle()
                        .fill(FitUpColors.Neon.pink)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 1.5))
                        .offset(x: 4, y: -4)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(FitUpFont.display(unread ? 20 : 19, weight: unread ? .heavy : .bold))
                        .foregroundStyle(unread ? Color.white : FitUpColors.Text.primary)
                        .lineLimit(1)
                        .shadow(color: unread ? FitUpColors.Neon.cyan.opacity(0.45) : .clear, radius: 6)

                    Spacer(minLength: 4)

                    if let at = row.lastMessageAt {
                        Text(inboxTimestamp(at))
                            .font(FitUpFont.mono(12, weight: .bold))
                            .foregroundStyle(unread ? FitUpColors.Neon.cyan : FitUpColors.Text.secondary)
                            .shadow(color: unread ? FitUpColors.Neon.cyan.opacity(0.35) : .clear, radius: 4)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }

                if let preview = row.lastMessagePreview, !preview.isEmpty {
                    Text(preview)
                        .font(FitUpFont.body(16, weight: unread ? .bold : .semibold))
                        .foregroundStyle(unread ? FitUpColors.Neon.yellow : FitUpColors.Text.secondary)
                        .shadow(color: unread ? FitUpColors.Neon.yellow.opacity(0.35) : .clear, radius: 4)
                        .lineLimit(2)
                } else {
                    Text("Say hello")
                        .font(FitUpFont.body(16, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }

                if unread {
                    Text("NEW")
                        .font(FitUpFont.mono(11, weight: .heavy))
                        .foregroundStyle(FitUpColors.Neon.pink)
                        .shadow(color: FitUpColors.Neon.pink.opacity(0.5), radius: 5)
                        .padding(.top, 2)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(unread ? FitUpColors.Neon.cyan : FitUpColors.Text.tertiary)
                .padding(.leading, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(inboxRowBackground(unread: unread))
        .overlay(inboxRowBorder(unread: unread))
    }

    private func inboxTimestamp(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if cal.isDateInYesterday(date) {
            return "Yesterday"
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    @ViewBuilder
    private func inboxRowBackground(unread: Bool) -> some View {
        if unread {
            RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            FitUpColors.Neon.cyan.opacity(0.3),
                            FitUpColors.Neon.orange.opacity(0.18),
                            FitUpColors.Neon.purple.opacity(0.14),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                .fill(Color.white.opacity(0.1))
        }
    }

    @ViewBuilder
    private func inboxRowBorder(unread: Bool) -> some View {
        RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
            .strokeBorder(
                unread
                    ? LinearGradient(
                        colors: [
                            FitUpColors.Neon.cyan.opacity(0.9),
                            FitUpColors.Neon.orange.opacity(0.7),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    : LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                lineWidth: unread ? 1.5 : 1
            )
    }

    private func load() async {
        guard let profile else {
            items = []
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            items = try await repository.fetchInbox(currentProfileId: profile.id)
            let peerIds = items.map(\.peerProfileId)
            peers = (try? await profileRepo.fetchPeerPublicProfiles(ids: peerIds)) ?? [:]
        } catch {
            AppLogger.log(
                category: "messaging",
                level: .error,
                message: "inbox_load_failed",
                userId: profile.id,
                metadata: AppLogger.supabaseErrorMetadata(error)
            )
            errorMessage = MessageRepository.userFacingMessage(for: error)
            items = []
        }
    }
}

#Preview {
    NavigationStack {
        MessagesInboxView(
            profile: Profile(
                id: UUID(),
                authUserId: UUID(),
                displayName: "Me",
                initials: "ME",
                avatarURL: nil,
                subscriptionTier: "free",
                timezone: nil,
                notificationsEnabled: true,
                createdAt: Date(),
                updatedAt: Date()
            )
        )
    }
}
