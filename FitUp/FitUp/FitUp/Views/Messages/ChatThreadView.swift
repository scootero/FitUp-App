//
//  ChatThreadView.swift
//  FitUp
//
//  1:1 text chat (MVP): polling, no Realtime.
//

import Combine
import SwiftUI

struct ChatThreadView: View {
    let peerProfileId: UUID
    let viewer: Profile
    /// When embedded in a pushed `NavigationLink`, hides the explicit Close button (use the nav back control).
    var showCloseInToolbar: Bool = true

    @Environment(\.dismiss) private var dismiss
    @FocusState private var composerFocused: Bool

    @StateObject private var viewModel: ChatThreadViewModel

    init(peerProfileId: UUID, viewer: Profile, showCloseInToolbar: Bool = true) {
        self.peerProfileId = peerProfileId
        self.viewer = viewer
        self.showCloseInToolbar = showCloseInToolbar
        _viewModel = StateObject(
            wrappedValue: ChatThreadViewModel(peerProfileId: peerProfileId, viewer: viewer)
        )
    }

    var body: some View {
        ZStack {
            MessagingBackground()

            VStack(spacing: 0) {
                if let err = viewModel.bannerError, !err.isEmpty {
                    Text(err)
                        .font(FitUpFont.body(13, weight: .semibold))
                        .foregroundStyle(FitUpColors.Neon.pink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, MessagingLayout.horizontalInset)
                        .padding(.vertical, 10)
                        .background(FitUpColors.Neon.pink.opacity(0.12))
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            if viewModel.messages.isEmpty, viewModel.isLoading {
                                ProgressView()
                                    .tint(FitUpColors.Neon.cyan)
                                    .scaleEffect(1.2)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 48)
                            } else {
                                ForEach(viewModel.messages) { msg in
                                    messageBubble(msg)
                                        .id(msg.id)
                                }
                            }
                        }
                        .padding(.horizontal, MessagingLayout.horizontalInset)
                        .padding(.vertical, MessagingLayout.verticalInset)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let last = viewModel.messages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: composerFocused) { _, focused in
                        guard focused, let last = viewModel.messages.last else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composer
            }
        }
        .navigationTitle(viewModel.peerDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showCloseInToolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(FitUpFont.body(14, weight: .bold))
                        .foregroundStyle(FitUpColors.Neon.cyan)
                }
            }
        }
        .task {
            await viewModel.loadInitial()
        }
        .task {
            await viewModel.pollLoop()
        }
        .onDisappear {
            viewModel.markThreadReadIfNeeded()
        }
    }

    private func messageBubble(_ msg: MessageRowRecord) -> some View {
        let mine = msg.senderId == viewer.id
        return HStack(alignment: .bottom, spacing: 0) {
            if mine { Spacer(minLength: MessagingLayout.bubbleSideGutter) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 6) {
                Text(msg.body)
                    .font(FitUpFont.body(18, weight: .bold))
                    .foregroundStyle(Color.white)
                    .shadow(
                        color: mine
                            ? FitUpColors.Neon.cyan.opacity(0.55)
                            : FitUpColors.Neon.orange.opacity(0.45),
                        radius: 6
                    )
                    .multilineTextAlignment(mine ? .trailing : .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(bubbleFill(mine: mine))
                    .overlay(bubbleStroke(mine: mine))
                    .shadow(
                        color: mine
                            ? FitUpColors.Neon.cyan.opacity(0.45)
                            : FitUpColors.Neon.orange.opacity(0.35),
                        radius: mine ? 14 : 8,
                        y: 4
                    )

                Text(msg.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(FitUpFont.mono(11, weight: .bold))
                    .foregroundStyle(
                        mine
                            ? FitUpColors.Neon.cyan
                            : FitUpColors.Neon.orange.opacity(0.85)
                    )
                    .shadow(
                        color: mine
                            ? FitUpColors.Neon.cyan.opacity(0.4)
                            : FitUpColors.Neon.orange.opacity(0.3),
                        radius: 4
                    )
            }
            .frame(maxWidth: MessagingLayout.bubbleMaxWidth, alignment: mine ? .trailing : .leading)
            if !mine { Spacer(minLength: MessagingLayout.bubbleSideGutter) }
        }
    }

    @ViewBuilder
    private func bubbleFill(mine: Bool) -> some View {
        if mine {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            FitUpColors.Neon.cyan.opacity(0.82),
                            FitUpColors.Neon.blue.opacity(0.62),
                            FitUpColors.Neon.blue.opacity(0.45),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            FitUpColors.Neon.orange.opacity(0.42),
                            FitUpColors.Neon.orange.opacity(0.22),
                            Color.white.opacity(0.1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    @ViewBuilder
    private func bubbleStroke(mine: Bool) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(
                mine
                    ? FitUpColors.Neon.cyan.opacity(0.9)
                    : FitUpColors.Neon.orange.opacity(0.65),
                lineWidth: 1.2
            )
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Drop a message…", text: $viewModel.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(FitUpFont.body(17, weight: .semibold))
                .foregroundStyle(Color.white)
                .shadow(color: FitUpColors.Neon.cyan.opacity(0.25), radius: 4)
                .lineLimit(1...5)
                .focused($composerFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(FitUpColors.Neon.cyan.opacity(0.45), lineWidth: 1)
                        )
                )

            Button {
                Task { await viewModel.send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        canSend ? FitUpColors.Neon.cyan : FitUpColors.Text.tertiary,
                        Color.white.opacity(0.12)
                    )
                    .shadow(color: canSend ? FitUpColors.Neon.cyan.opacity(0.5) : .clear, radius: 8)
            }
            .buttonStyle(.plain)
            .disabled(!canSend || viewModel.sendBusy)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, MessagingLayout.horizontalInset)
        .padding(.top, 12)
        .padding(.bottom, MessagingLayout.composerBottomPad)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial).opacity(0.4)
                LinearGradient(
                    colors: [Color.black.opacity(0.25), Color.black.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    private var canSend: Bool {
        !viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - View model

@MainActor
private final class ChatThreadViewModel: ObservableObject {
    let peerProfileId: UUID
    let viewer: Profile

    @Published var messages: [MessageRowRecord] = []
    @Published var threadId: UUID?
    @Published var peerDisplayName: String = "Chat"
    @Published var isLoading = true
    @Published var bannerError: String?
    @Published var draft = ""
    @Published var sendBusy = false

    private let messagesRepo = MessageRepository()
    private let profiles = ProfileRepository()
    private let friendshipRepo = FriendshipRepository()

    init(peerProfileId: UUID, viewer: Profile) {
        self.peerProfileId = peerProfileId
        self.viewer = viewer
    }

    func loadInitial() async {
        isLoading = true
        bannerError = nil
        defer { isLoading = false }

        if peerProfileId == viewer.id {
            bannerError = "Invalid chat."
            return
        }

        do {
            if let peer = try await profiles.fetchPeerPublicProfile(id: peerProfileId) {
                peerDisplayName = peer.displayName
            }

            let phase = try await friendshipRepo.friendshipPhase(
                currentProfileId: viewer.id,
                peerProfileId: peerProfileId
            )
            let existingThread = try await messagesRepo.threadIdIfExists(
                peerProfileId: peerProfileId,
                currentProfileId: viewer.id
            )
            if phase != .accepted, existingThread == nil {
                bannerError = "Add this person as a friend to message them."
                return
            }

            let tid: UUID
            if let existingThread {
                tid = existingThread
            } else {
                tid = try await messagesRepo.ensureThread(
                    peerProfileId: peerProfileId,
                    currentProfileId: viewer.id
                )
            }
            threadId = tid
            messages = try await messagesRepo.fetchMessages(threadId: tid)
            markThreadReadIfNeeded()
        } catch {
            AppLogger.log(
                category: "messaging",
                level: .error,
                message: "chat_load_failed",
                userId: viewer.id,
                metadata: AppLogger.supabaseErrorMetadata(error)
            )
            bannerError = MessageRepository.userFacingMessage(for: error)
        }
    }

    func markThreadReadIfNeeded() {
        guard let tid = threadId else { return }
        let through = messages.last?.createdAt ?? Date()
        MessageReadStore.markThreadRead(threadId: tid, profileId: viewer.id, through: through)
    }

    func pollLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard let tid = threadId else { continue }
            do {
                let next = try await messagesRepo.fetchMessages(threadId: tid)
                if next != messages {
                    messages = next
                    markThreadReadIfNeeded()
                }
            } catch {
                // Polling: keep last good payload
            }
        }
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let tid = threadId else { return }
        sendBusy = true
        defer { sendBusy = false }
        do {
            try await messagesRepo.sendMessage(threadId: tid, body: text, senderId: viewer.id)
            draft = ""
            messages = try await messagesRepo.fetchMessages(threadId: tid)
            markThreadReadIfNeeded()
        } catch {
            AppLogger.log(
                category: "messaging",
                level: .error,
                message: "chat_send_failed",
                userId: viewer.id,
                metadata: AppLogger.supabaseErrorMetadata(error)
            )
            bannerError = MessageRepository.userFacingMessage(for: error)
        }
    }
}

#Preview {
    NavigationStack {
        ChatThreadView(
            peerProfileId: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
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
            ),
            showCloseInToolbar: true
        )
    }
}
