//
//  PostAuthDisplayNameView.swift
//  FitUp
//
//  Shown after sign up or Sign in with Apple; user confirms their public display name.
//

import SwiftUI

struct PostAuthDisplayNameView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    @State private var nameText = ""
    @State private var isSubmitting = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            BackgroundGradientView()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    VStack(spacing: 12) {
                        nameField
                        Button("Continue") {
                            fieldFocused = false
                            Task { await submit() }
                        }
                        .solidButton(color: FitUpColors.Neon.cyan)
                        .disabled(isSubmitting)
                        .opacity(isSubmitting ? 0.6 : 1)
                    }
                    .padding(16)
                    .glassCard(.base)
                    if let error = sessionStore.authErrorMessage, !error.isEmpty {
                        Text(error)
                            .font(FitUpFont.body(13, weight: .medium))
                            .foregroundStyle(FitUpColors.Neon.pink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .fitUpKeyboardDoneToolbar { fieldFocused = false }
        .trackProductScreen("post_auth_display_name", userId: sessionStore.currentProfile?.id)
        .screenTransition()
        .onAppear {
            if nameText.isEmpty {
                nameText = sessionStore.postAuthNameInitialValue
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your name")
                .font(FitUpFont.display(28, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Text("This is how other players see you on FitUp. You can change it later in your profile.")
                .font(FitUpFont.body(15, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nameField: some View {
        TextField("Display name", text: $nameText)
            .textInputAutocapitalization(.words)
            .disableAutocorrection(true)
            .focused($fieldFocused)
            .submitLabel(.continue)
            .onSubmit {
                Task { await submit() }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .foregroundStyle(FitUpColors.Text.primary)
            .background(
                RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                    .fill(FitUpColors.Bg.base.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }

    private func submit() async {
        guard !isSubmitting else { return }
        let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        fieldFocused = false
        await sessionStore.updateDisplayName(trimmed)
        if sessionStore.authErrorMessage == nil {
            sessionStore.markPostAuthDisplayNameComplete()
        }
    }
}

#Preview {
    PostAuthDisplayNameView()
        .environmentObject(SessionStore())
}
