import AuthenticationServices
import SwiftUI

struct AccountDeletionRequestView: View {
    let profile: Profile?
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var operationId = UUID()
    @State private var requiresAppleAuthorization = false
    @State private var isPreparing = true
    @State private var isDeleting = false
    @State private var showConfirmation = false
    @State private var showAppleAuthorization = false
    @State private var errorMessage: String?
    private let service = AccountDeletionService()

    var body: some View {
        ZStack {
            BackgroundGradientView()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Delete Account")
                        .font(FitUpFont.display(28, weight: .black))
                        .foregroundStyle(FitUpColors.Text.primary)
                    Text("Permanently delete your FitOff account and associated data.")
                        .font(FitUpFont.body(15, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                    if showAppleAuthorization { appleAuthorizationCard }
                    if let errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(errorMessage)
                                .font(FitUpFont.body(14, weight: .semibold))
                                .foregroundStyle(FitUpColors.Neon.pink)
                            Button("Try Again") { Task { await prepare() } }
                                .disabled(isDeleting)
                                .font(FitUpFont.body(14, weight: .bold))
                                .foregroundStyle(FitUpColors.Neon.cyan)
                        }
                        .padding(14)
                        .glassCard(.base)
                    }
                    Button(role: .destructive) { showConfirmation = true } label: {
                        HStack(spacing: 10) {
                            if isPreparing || isDeleting { ProgressView().tint(.white) }
                            Text(isDeleting ? "Deleting Account…" : "Delete Account")
                                .font(FitUpFont.body(16, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FitUpColors.Neon.pink)
                    .disabled(isPreparing || isDeleting || showAppleAuthorization)
                    Text("If you have an active App Store subscription, deleting your account does not automatically cancel your subscription.")
                        .font(FitUpFont.body(13, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }
                .padding(20)
            }
        }
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .task { await prepare() }
        .alert("Delete Account?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Account", role: .destructive) {
                if requiresAppleAuthorization { showAppleAuthorization = true }
                else { Task { await delete(appleAuthorizationCode: nil) } }
            }
        } message: {
            Text("This permanently deletes your account and associated personal data and cannot be undone.\n\nIf you have an active App Store subscription, deleting your account does not automatically cancel your subscription.")
        }
    }

    private var appleAuthorizationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Confirm with Apple")
                .font(FitUpFont.body(16, weight: .bold))
                .foregroundStyle(FitUpColors.Text.primary)
            Text("Apple requires fresh authorization before FitOff can revoke Sign in with Apple and finish deleting this account.")
                .font(FitUpFont.body(13, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = []
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                          let codeData = credential.authorizationCode,
                          let code = String(data: codeData, encoding: .utf8), !code.isEmpty else {
                        errorMessage = failureText()
                        return
                    }
                    Task { await delete(appleAuthorizationCode: code) }
                case .failure:
                    errorMessage = failureText()
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .disabled(isDeleting)
        }
        .padding(16)
        .glassCard(.base)
    }

    @MainActor private func prepare() async {
        guard !isDeleting else { return }
        isPreparing = true
        errorMessage = nil
        defer { isPreparing = false }
        do {
            let preparation = try await service.prepare(operationId: operationId)
            requiresAppleAuthorization = preparation.requiresAppleAuthorization
        } catch { errorMessage = failureText() }
    }

    @MainActor private func delete(appleAuthorizationCode: String?) async {
        guard !isDeleting else { return }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }
        do {
            _ = try await service.delete(operationId: operationId, appleAuthorizationCode: appleAuthorizationCode)
            if let profileId = profile?.id { AccountDeletionLocalState.clear(profileId: profileId) }
            LiveActivityCoordinator.shared.endActivity()
            await sessionStore.completeAccountDeletion()
        } catch let failure as AccountDeletionFailure {
            showAppleAuthorization = failure.code == "apple_authorization_required" || requiresAppleAuthorization
            AppLogger.log(
                category: "account_deletion", level: .error, message: "account_deletion_failed",
                metadata: [
                    "operation_id": failure.operationId.uuidString,
                    "stage": "request", "error_code": failure.code, "success": "false",
                ]
            )
            errorMessage = failure.errorDescription
        } catch { errorMessage = failureText() }
    }

    private func failureText() -> String {
        "Account deletion could not be completed. Please try again. Operation ID: \(operationId.uuidString)"
    }
}

#Preview {
    NavigationStack { AccountDeletionRequestView(profile: nil) }
        .environmentObject(SessionStore())
}
