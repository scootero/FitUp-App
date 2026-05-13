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
            BackgroundGradientView()
            VStack(spacing: 0) {
                if let err = viewModel.bannerError, !err.isEmpty {
                    Text(err)
                        .font(FitUpFont.body(12, weight: .semibold))
                        .foregroundStyle(FitUpColors.Neon.pink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            if viewModel.messages.isEmpty, viewModel.isLoading {
                                ProgressView()
                                    .tint(FitUpColors.Neon.cyan)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 40)
                            } else {
                                ForEach(viewModel.messages) { msg in
                                    messageBubble(msg)
                                        .id(msg.id)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let last = viewModel.messages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                composer
            }
        }
        .navigationTitle(viewModel.peerDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showCloseInToolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
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
    }

    private func messageBubble(_ msg: MessageRowRecord) -> some View {
        let mine = msg.senderId == viewer.id
        return HStack {
            if mine { Spacer(minLength: 48) }
            Text(msg.body)
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(mine ? Color.white : FitUpColors.Text.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            mine
                                ? LinearGradient(
                                    colors: [FitUpColors.Neon.cyan.opacity(0.45), FitUpColors.Neon.blue.opacity(0.35)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
            if !mine { Spacer(minLength: 48) }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message", text: $viewModel.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(FitUpFont.body(14))
                .foregroundStyle(FitUpColors.Text.primary)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

            Button {
                Task { await viewModel.send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        canSend ? FitUpColors.Neon.cyan : FitUpColors.Text.tertiary,
                        Color.white.opacity(0.08)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSend || viewModel.sendBusy)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.35))
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
            let tid = try await messagesRepo.ensureThread(
                peerProfileId: peerProfileId,
                currentProfileId: viewer.id
            )
            threadId = tid
            messages = try await messagesRepo.fetchMessages(threadId: tid)
        } catch {
            bannerError = friendlyError(error)
        }
    }

    func pollLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard let tid = threadId else { continue }
            do {
                let next = try await messagesRepo.fetchMessages(threadId: tid)
                if next != messages {
                    messages = next
                }
            } catch {
                // Polling: keep last good payload; optional soft error
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
        } catch {
            bannerError = friendlyError(error)
        }
    }

    private func friendlyError(_ error: Error) -> String {
        if let le = error as? LocalizedError, let d = le.errorDescription {
            return d
        }
        return MessageRepositoryError.unexpectedResponse.localizedDescription
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
