//
//  AccountDeletionRequestView.swift
//  FitUp
//
//  Manual account deletion request info for TestFlight (no in-app deletion).
//

import SwiftUI
import UIKit

private enum AccountDeletionSupport {
    static let supportEmail = "oliverscott14@gmail.com"
    static let appName = "FitUp"
}

struct AccountDeletionRequestView: View {
    let profile: Profile?

    @State private var copiedLabel: String?

    private var displayName: String {
        let trimmed = profile?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "—" : trimmed
    }

    private var userIdString: String? {
        profile?.id.uuidString
    }

    var body: some View {
        ZStack {
            BackgroundGradientView()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    bodyText(
                        "Automated in-app account deletion is not available yet. To request deletion of your FitUp account and associated personal data, please email us using the information below."
                    )

                    infoCard

                    bodyText(
                        "Please include your FitUp display name or user ID in the email so we can locate your account."
                    )

                    bodyText(
                        "Completed match history may remain in limited or anonymized form where needed to preserve other users’ match records."
                    )

                    copyButtons

                    if let copiedLabel {
                        Text(copiedLabel)
                            .font(FitUpFont.body(12, weight: .medium))
                            .foregroundStyle(FitUpColors.Neon.green)
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Account Deletion")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            infoRow(label: "Support email", value: AccountDeletionSupport.supportEmail)
            infoRow(label: "Display name", value: displayName)
            infoRow(label: "User ID", value: userIdString ?? "—")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(.base)
    }

    private var copyButtons: some View {
        VStack(spacing: 10) {
            copyButton(title: "Copy Support Email") {
                copy(AccountDeletionSupport.supportEmail, label: "Support email copied")
            }
            if userIdString != nil {
                copyButton(title: "Copy User ID") {
                    copy(userIdString!, label: "User ID copied")
                }
            }
            copyButton(title: "Copy Request Info") {
                copy(requestInfoText, label: "Request info copied")
            }
        }
    }

    private var requestInfoText: String {
        """
        Support email: \(AccountDeletionSupport.supportEmail)
        Display name: \(displayName)
        User ID: \(userIdString ?? "—")
        App name: \(AccountDeletionSupport.appName)
        Request: Account deletion
        """
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

    private func copyButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(FitUpFont.body(14, weight: .semibold))
                .foregroundStyle(FitUpColors.Neon.cyan)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .glassCard(.base)
        }
        .buttonStyle(.plain)
    }

    private func copy(_ text: String, label: String) {
        UIPasteboard.general.string = text
        copiedLabel = label
    }
}

#Preview {
    NavigationStack {
        AccountDeletionRequestView(profile: nil)
    }
}
