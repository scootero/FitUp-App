//
//  AccountDeletionRequestView.swift
//  FitUp
//
//  In-app account deletion (App Store Guideline 5.1.1) via delete-account Edge Function.
//

import SwiftUI
import Supabase
import UIKit

struct AccountDeletionRequestView: View {
    let profile: Profile?
    var onDeleted: (() -> Void)? = nil

    @EnvironmentObject private var sessionStore: SessionStore
    @State private var isDeleting = false
    @State private var showConfirm = false
    @State private var errorMessage: String?
    @State private var didSucceed = false

    private var displayName: String {
        let trimmed = profile?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "—" : trimmed
    }

    var body: some View {
        ZStack {
            BackgroundGradientView()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    bodyText(
                        "Permanently delete your FitUp account and associated personal data. This cannot be undone."
                    )

                    infoCard

                    bodyText(
                        "Completed match history may remain in limited or anonymized form so other players’ records stay intact."
                    )

                    if let errorMessage {
                        Text(errorMessage)
                            .font(FitUpFont.body(13, weight: .semibold))
                            .foregroundStyle(FitUpColors.Neon.pink)
                    }

                    if didSucceed {
                        Text("Your account was deleted.")
                            .font(FitUpFont.body(13, weight: .semibold))
                            .foregroundStyle(FitUpColors.Neon.green)
                    }

                    Button {
                        showConfirm = true
                    } label: {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.85)
                            }
                            Text(isDeleting ? "Deleting…" : "Delete My Account")
                                .font(FitUpFont.body(15, weight: .heavy))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .solidButton(color: FitUpColors.Neon.pink)
                    .disabled(isDeleting || profile?.id == nil)

                    Button {
                        if let url = URL(string: FitUpAppLinks.supportMailtoURL) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Contact support: \(FitUpAppLinks.supportEmail)")
                            .font(FitUpFont.body(13, weight: .semibold))
                            .foregroundStyle(FitUpColors.Neon.cyan)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Account Deletion")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your FitUp account. You will be signed out.")
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            infoRow(label: "Display name", value: displayName)
            infoRow(label: "User ID", value: profile?.id.uuidString ?? "—")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(.base)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(FitUpFont.body(14, weight: .medium))
            .foregroundStyle(FitUpColors.Text.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(FitUpFont.body(11, weight: .bold))
                .foregroundStyle(FitUpColors.Text.tertiary)
            Text(value)
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(FitUpColors.Text.primary)
                .textSelection(.enabled)
        }
    }

    @MainActor
    private func deleteAccount() async {
        guard let userId = profile?.id else { return }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }

        do {
            try await AccountDeletionService.deleteCurrentAccount()
            didSucceed = true
            AppLogger.log(
                category: "auth",
                level: .info,
                message: "account deleted",
                userId: userId
            )
            onDeleted?()
            await sessionStore.signOut()
        } catch {
            errorMessage = "Could not delete your account right now. Try again or email \(FitUpAppLinks.supportEmail)."
            AppLogger.log(
                category: "auth",
                level: .error,
                message: "account deletion failed",
                userId: userId,
                metadata: ["error": error.localizedDescription]
            )
        }
    }
}

enum AccountDeletionService {
    static func deleteCurrentAccount() async throws {
        guard let client = SupabaseProvider.client else {
            throw ProfileRepositoryError.supabaseNotConfigured
        }
        let session = try await client.auth.session
        try await client.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(
                headers: ["Authorization": "Bearer \(session.accessToken)"],
                body: EmptyDeleteBody()
            )
        )
    }
}

private struct EmptyDeleteBody: Encodable {}

#Preview {
    NavigationStack {
        AccountDeletionRequestView(profile: nil)
            .environmentObject(SessionStore())
    }
}
