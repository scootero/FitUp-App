import SwiftUI

struct BlockedUsersView: View {
    @State private var users: [BlockedUser] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var busyUserId: UUID?
    private let moderation = ModerationRepository()

    var body: some View {
        ZStack {
            BackgroundGradientView()
            Group {
                if isLoading { ProgressView().tint(FitUpColors.Neon.cyan) }
                else if users.isEmpty {
                    ContentUnavailableView("No Blocked Users", systemImage: "person.crop.circle.badge.checkmark", description: Text("People you block will appear here."))
                } else {
                    List(users) { user in
                        HStack(spacing: 12) {
                            AvatarView(initials: user.initials, color: ProfileAccentColor.swiftUIColor(hex: ProfileAccentColor.hex(for: user.id)), size: 42)
                            Text(user.displayName).foregroundStyle(FitUpColors.Text.primary)
                            Spacer()
                            Button("Unblock") { Task { await unblock(user) } }.disabled(busyUserId != nil)
                        }
                        .listRowBackground(Color.white.opacity(0.08))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Couldn’t Update Blocked Users", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "Please try again.") }
    }

    @MainActor private func load() async {
        isLoading = true
        defer { isLoading = false }
        do { users = try await moderation.loadBlockedUsers() }
        catch { errorMessage = "Blocked users could not be loaded. Please try again." }
    }

    @MainActor private func unblock(_ user: BlockedUser) async {
        busyUserId = user.id
        defer { busyUserId = nil }
        do { try await moderation.unblock(userId: user.id); users.removeAll { $0.id == user.id } }
        catch { errorMessage = "This person could not be unblocked. Please try again." }
    }
}

