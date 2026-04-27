//
//  FriendsListView.swift
//  FitUp
//
//  Lists explicit friends, pending requests, and people you can add from past matches.
//

import Combine
import SwiftUI

@MainActor
final class FriendsListViewModel: ObservableObject {
    @Published private(set) var items: [FriendListItem] = []
    @Published private(set) var suggestions: [SuggestedOpponentItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var actionInFlight: Set<UUID> = []

    private let repository = FriendshipRepository()

    func load(profile: Profile?) async {
        guard let profile else {
            items = []
            suggestions = []
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await repository.loadFriendListState(currentProfile: profile)
            items = result.items
            suggestions = result.suggestions
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not load friends."
        }
    }

    func addFriend(currentProfile: Profile, peerId: UUID) async {
        await run(peerId, currentProfile) {
            try await repository.sendFriendRequest(from: currentProfile.id, to: peerId)
        }
    }

    func accept(currentProfile: Profile, peerId: UUID) async {
        let (a, b) = FriendshipRepository.orderedPair(currentProfile.id, peerId)
        await run(peerId, currentProfile) {
            try await repository.acceptRequest(aId: a, bId: b)
        }
    }

    func removeOrDecline(currentProfile: Profile, peerId: UUID) async {
        let (a, b) = FriendshipRepository.orderedPair(currentProfile.id, peerId)
        await run(peerId, currentProfile) {
            try await repository.deleteFriendship(aId: a, bId: b)
        }
    }

    private func run(_ peerId: UUID, _ profile: Profile, _ op: () async throws -> Void) async {
        actionInFlight.insert(peerId)
        errorMessage = nil
        defer { actionInFlight.remove(peerId) }
        do {
            try await op()
            await load(profile: profile)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
        }
    }
}

struct FriendsListView: View {
    let profile: Profile?

    @StateObject private var viewModel = FriendsListViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(FitUpFont.body(12, weight: .semibold))
                        .foregroundStyle(FitUpColors.Neon.pink)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .tint(FitUpColors.Neon.cyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if viewModel.items.isEmpty, viewModel.suggestions.isEmpty {
                    Text("When you play matches, you can send friend requests to people you’ve competed with. Accept requests above to build your list.")
                        .font(FitUpFont.body(14, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(.base)
                }

                if !viewModel.items.isEmpty {
                    SettingsGroupView(title: "REQUESTS & FRIENDS") {
                        ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                            friendRow(item)
                            if index < viewModel.items.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.05))
                                    .frame(height: 1)
                                    .padding(.leading, 66)
                            }
                        }
                    }
                }

                if !viewModel.suggestions.isEmpty {
                    SettingsGroupView(title: "ADD FROM MATCHES") {
                        ForEach(Array(viewModel.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                            suggestionRow(suggestion)
                            if index < viewModel.suggestions.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.05))
                                    .frame(height: 1)
                                    .padding(.leading, 66)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 40)
        }
        .background(BackgroundGradientView())
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: profile?.id) {
            await viewModel.load(profile: profile)
        }
    }

    @ViewBuilder
    private func friendRow(_ item: FriendListItem) -> some View {
        let busy = viewModel.actionInFlight.contains(item.peerId)
        HStack(spacing: 12) {
            AvatarView(
                initials: item.initials,
                color: ProfileAccentColor.swiftUIColor(hex: item.colorHex),
                size: 40
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(FitUpFont.body(14, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.primary)
                Text(subtitle(for: item))
                    .font(FitUpFont.body(11, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.tertiary)
            }
            Spacer(minLength: 0)
            actions(for: item, busy: busy)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .opacity(busy ? 0.55 : 1)
    }

    private func subtitle(for item: FriendListItem) -> String {
        switch item.rowType {
        case .incomingRequest:
            return "Wants to be friends"
        case .outgoingRequest:
            return "Request sent"
        case .accepted:
            if let d = item.relevantDate {
                return "Friends since \(Self.shortDate(d))"
            }
            return "Friends"
        }
    }

    @ViewBuilder
    private func actions(for item: FriendListItem, busy: Bool) -> some View {
        Group {
            switch item.rowType {
            case .incomingRequest:
                HStack(spacing: 8) {
                    Button("Decline") {
                        guard let profile else { return }
                        Task { await viewModel.removeOrDecline(currentProfile: profile, peerId: item.peerId) }
                    }
                    .font(FitUpFont.body(12, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .disabled(busy)

                    Button("Accept") {
                        guard let profile else { return }
                        Task { await viewModel.accept(currentProfile: profile, peerId: item.peerId) }
                    }
                    .font(FitUpFont.body(12, weight: .bold))
                    .foregroundStyle(FitUpColors.Neon.cyan)
                    .disabled(busy)
                }
            case .outgoingRequest:
                Button("Cancel") {
                    guard let profile else { return }
                    Task { await viewModel.removeOrDecline(currentProfile: profile, peerId: item.peerId) }
                }
                .font(FitUpFont.body(12, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.secondary)
                .disabled(busy)
            case .accepted:
                Button("Remove") {
                    guard let profile else { return }
                    Task { await viewModel.removeOrDecline(currentProfile: profile, peerId: item.peerId) }
                }
                .font(FitUpFont.body(12, weight: .semibold))
                .foregroundStyle(FitUpColors.Neon.pink)
                .disabled(busy)
            }
        }
    }

    private func suggestionRow(_ suggestion: SuggestedOpponentItem) -> some View {
        let busy = viewModel.actionInFlight.contains(suggestion.profileId)
        return HStack(spacing: 12) {
            AvatarView(
                initials: suggestion.initials,
                color: ProfileAccentColor.swiftUIColor(hex: suggestion.colorHex),
                size: 40
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.displayName)
                    .font(FitUpFont.body(14, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.primary)
                Text("From a past match")
                    .font(FitUpFont.body(11, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.tertiary)
            }
            Spacer(minLength: 0)
            Button("Add") {
                guard let profile else { return }
                Task { await viewModel.addFriend(currentProfile: profile, peerId: suggestion.profileId) }
            }
            .font(FitUpFont.body(12, weight: .bold))
            .foregroundStyle(FitUpColors.Neon.cyan)
            .disabled(busy)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .opacity(busy ? 0.55 : 1.0)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static func shortDate(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        FriendsListView(profile: nil)
    }
}
