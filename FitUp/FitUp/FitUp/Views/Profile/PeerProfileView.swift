//
//  PeerProfileView.swift
//  FitUp
//
//  Lightweight public view of another competitor — friendship + messaging placeholders.
//

import SwiftUI

struct PeerProfileView: View {
    let peerId: UUID
    let viewer: Profile

    @Environment(\.dismiss) private var dismiss

    @State private var peer: PeerPublicProfile?
    @State private var phase: PeerFriendshipPhase = .unknown
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var actionBusy = false
    @State private var messagingAlertBody: String?
    @State private var showChatThread = false

    private let profileRepo = ProfileRepository()
    private let friendshipRepo = FriendshipRepository()

    private var colorHex: String { ProfileAccentColor.hex(for: peerId) }
    private var accent: Color { ProfileAccentColor.swiftUIColor(hex: colorHex) }

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradientView()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(FitUpFont.body(12, weight: .semibold))
                                .foregroundStyle(FitUpColors.Neon.pink)
                        }

                        if peerId == viewer.id {
                            Text("This is you.")
                                .font(FitUpFont.body(14, weight: .medium))
                                .foregroundStyle(FitUpColors.Text.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 40)
                        } else if isLoading {
                            ProgressView()
                                .tint(FitUpColors.Neon.cyan)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else if let peer {
                            headerSection(peer: peer)

                            friendshipPrimaryButton

                            messageButton
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Competitor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(FitUpColors.Neon.cyan)
                }
            }
        }
        .task(id: peerId) {
            await load()
        }
        .fullScreenCover(isPresented: $showChatThread) {
            NavigationStack {
                ChatThreadView(peerProfileId: peerId, viewer: viewer)
            }
        }
        .alert("Message", isPresented: messagingAlertPresented) {
            Button("OK", role: .cancel) {
                messagingAlertBody = nil
            }
        } message: {
            Text(messagingAlertBody ?? "")
        }
    }

    private var messagingAlertPresented: Binding<Bool> {
        Binding(
            get: { messagingAlertBody != nil },
            set: { if !$0 { messagingAlertBody = nil } }
        )
    }

    private func avatarSection(for peer: PeerPublicProfile) -> some View {
        Group {
            if let urlStr = peer.avatarURL, let url = URL(string: urlStr), url.scheme == "https" {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        AvatarView(initials: peer.initials, color: accent, size: 96, glow: true)
                            .overlay { ProgressView().tint(FitUpColors.Neon.cyan) }
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(accent.opacity(0.35), lineWidth: 2)
                            }
                    case .failure:
                        AvatarView(initials: peer.initials, color: accent, size: 96, glow: true)
                    @unknown default:
                        AvatarView(initials: peer.initials, color: accent, size: 96, glow: true)
                    }
                }
            } else {
                AvatarView(initials: peer.initials, color: accent, size: 96, glow: true)
            }
        }
    }

    private func headerSection(peer: PeerPublicProfile) -> some View {
        VStack(spacing: 14) {
            avatarSection(for: peer)
                .frame(maxWidth: .infinity)

            Text(peer.displayName)
                .font(FitUpFont.display(22, weight: .black))
                .foregroundStyle(FitUpColors.Text.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text("FitUp competitor")
                .font(FitUpFont.body(12))
                .foregroundStyle(FitUpColors.Text.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassCard(.base)
    }

    @ViewBuilder
    private var friendshipPrimaryButton: some View {
        let disabled = peerId == viewer.id || actionBusy || phase == .outgoingPending || phase == .accepted

        Button {
            Task {
                guard peerId != viewer.id else { return }
                actionBusy = true
                defer { actionBusy = false }

                switch phase {
                case .none, .unknown:
                    do {
                        try await friendshipRepo.sendFriendRequest(from: viewer.id, to: peerId)
                        phase = (try? await friendshipRepo.friendshipPhase(currentProfileId: viewer.id, peerProfileId: peerId)) ?? phase
                        errorMessage = nil
                    } catch {
                        errorMessage = "Could not send friend request."
                    }
                case .incomingPending:
                    let (a, b) = FriendshipRepository.orderedPair(viewer.id, peerId)
                    do {
                        try await friendshipRepo.acceptRequest(aId: a, bId: b)
                        phase = (try? await friendshipRepo.friendshipPhase(currentProfileId: viewer.id, peerProfileId: peerId)) ?? phase
                        errorMessage = nil
                    } catch {
                        errorMessage = "Could not accept friend request."
                    }
                case .outgoingPending, .accepted:
                    break
                }
            }
        } label: {
            Text(friendshipButtonTitle)
                .font(FitUpFont.body(15, weight: .bold))
                .frame(maxWidth: .infinity)
        }
        .solidButton(color: FitUpColors.Neon.cyan)
        .opacity(disabled && phase != .none && phase != .unknown ? 0.55 : 1)
        .disabled(disabled)
    }

    private var friendshipButtonTitle: String {
        switch phase {
        case .unknown:
            return "Add Friend"
        case .none:
            return "Add Friend"
        case .incomingPending:
            return "Accept Friend"
        case .outgoingPending:
            return "Request Sent"
        case .accepted:
            return "Friends"
        }
    }

    private var messageButton: some View {
        Button {
            Task { await messageTapped() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 16, weight: .semibold))
                Text("Message")
                    .font(FitUpFont.body(15, weight: .bold))
                Spacer()
                if phase != .accepted {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                }
            }
            .foregroundStyle(FitUpColors.Text.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(peerId == viewer.id)
        .opacity(peerId == viewer.id ? 0.35 : 1)
    }

    private func messageTapped() async {
        guard peerId != viewer.id else { return }
        if phase != .accepted {
            messagingAlertBody = "Add this person as a friend to message them."
            return
        }
        do {
            _ = try await MessageRepository().ensureThread(
                peerProfileId: peerId,
                currentProfileId: viewer.id
            )
            showChatThread = true
            errorMessage = nil
        } catch {
            let msg: String
            if let m = (error as? LocalizedError)?.errorDescription, !m.isEmpty {
                msg = m
            } else {
                msg = "Messaging is not ready yet. Please try again later."
            }
            errorMessage = msg
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil

        guard peerId != viewer.id else {
            isLoading = false
            phase = .none
            return
        }

        do {
            let p = try await profileRepo.fetchPeerPublicProfile(id: peerId)
            peer = p
            phase = if p != nil {
                (try? await friendshipRepo.friendshipPhase(currentProfileId: viewer.id, peerProfileId: peerId)) ?? .unknown
            } else {
                .none
            }
            if p == nil {
                errorMessage = "Could not load this profile."
            }
        } catch {
            peer = nil
            errorMessage = "Could not load this profile."
            phase = .unknown
        }
        isLoading = false
    }
}

#Preview("Peer Profile") {
    PeerProfileView(
        peerId: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
        viewer: Profile(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
            authUserId: UUID(),
            displayName: "Demo",
            initials: "DM",
            avatarURL: nil,
            subscriptionTier: "free",
            timezone: nil,
            notificationsEnabled: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    )
}
