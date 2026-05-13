//
//  MessagesInboxView.swift
//  FitUp
//
//  Simple list of 1:1 threads (MVP).
//

import SwiftUI

struct MessagesInboxView: View {
    let profile: Profile?

    @State private var items: [InboxThreadItem] = []
    @State private var peers: [UUID: PeerPublicProfile] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let repository = MessageRepository()
    private let profileRepo = ProfileRepository()

    var body: some View {
        ZStack {
            BackgroundGradientView()
            Group {
                if profile == nil {
                    Text("Sign in to use Messages.")
                        .font(FitUpFont.body(14, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isLoading, items.isEmpty {
                    ProgressView()
                        .tint(FitUpColors.Neon.cyan)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    Text("No messages yet.")
                        .font(FitUpFont.body(15, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(items) { row in
                                if let profile {
                                    NavigationLink {
                                        ChatThreadView(peerProfileId: row.peerProfileId, viewer: profile, showCloseInToolbar: false)
                                    } label: {
                                        inboxRow(row)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func inboxRow(_ row: InboxThreadItem) -> some View {
        let id = row.peerProfileId
        let peer = peers[id]
        let hex = ProfileAccentColor.hex(for: id)
        let color = ProfileAccentColor.swiftUIColor(hex: hex)
        let title = peer?.displayName ?? "Competitor"
        let initials = peer?.initials ?? String(id.uuidString.prefix(2)).uppercased()
        return HStack(alignment: .center, spacing: 12) {
            AvatarView(initials: initials, color: color, size: 44, glow: false)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(FitUpFont.body(15, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.primary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if let at = row.thread.lastMessageAt {
                        Text(at.formatted(date: .abbreviated, time: .shortened))
                            .font(FitUpFont.mono(10, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.tertiary)
                    }
                }
                if let preview = row.lastMessagePreview, !preview.isEmpty {
                    Text(preview)
                        .font(FitUpFont.body(12))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                        .lineLimit(2)
                } else {
                    Text("Say hello")
                        .font(FitUpFont.body(12))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(.base)
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
            if let msg = (error as? LocalizedError)?.errorDescription {
                errorMessage = msg
            }
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
