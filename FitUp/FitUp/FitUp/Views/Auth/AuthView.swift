//
//  AuthView.swift
//  FitUp
//
//  Slice 1 auth entry point: email/password and Apple sign-in.
//

import AuthenticationServices
import Foundation
import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    @State private var isWorking = false
    @FocusState private var focusedField: AuthField?

    private enum AuthField: Hashable {
        case displayName
        case email
        case password
    }

    var body: some View {
        ZStack {
            BackgroundGradientView()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    formCard
                    appleButton
                    modeToggle
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
        .fitUpKeyboardDoneToolbar { focusedField = nil }
        .screenTransition()
        .onAppear {
            ProductAnalytics.track(ProductAnalytics.Event.authScreenView, userId: nil)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FitUp")
                .font(FitUpFont.display(34, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Text(isSignUp ? "Create your account" : "Welcome back")
                .font(FitUpFont.body(15, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formCard: some View {
        VStack(spacing: 12) {
            if isSignUp {
                textField(
                    title: "Display name",
                    text: $displayName,
                    capitalization: .words,
                    field: .displayName,
                    submitLabel: .next,
                    onSubmit: { focusedField = .email }
                )
            }
            textField(
                title: "Email",
                text: $email,
                capitalization: .never,
                keyboardType: .emailAddress,
                field: .email,
                submitLabel: .next,
                onSubmit: { focusedField = .password }
            )
            secureField(
                title: "Password",
                text: $password,
                field: .password,
                submitLabel: .go,
                onSubmit: { Task { await submitEmailAuth() } }
            )
            Button(isSignUp ? "Create Account" : "Sign In") {
                focusedField = nil
                Task { await submitEmailAuth() }
            }
            .solidButton(color: FitUpColors.Neon.cyan)
            .disabled(isWorking)
            .opacity(isWorking ? 0.6 : 1)
        }
        .padding(16)
        .glassCard(.base)
    }

    private var appleButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            Task { await handleAppleSignIn(result: result) }
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                .strokeBorder(FitUpColors.Neon.cyan.opacity(0.18), lineWidth: 1)
        }
        .disabled(isWorking)
        .opacity(isWorking ? 0.6 : 1)
    }

    private var modeToggle: some View {
        Button(isSignUp ? "Already have an account? Sign In" : "Need an account? Sign Up") {
            focusedField = nil
            isSignUp.toggle()
            sessionStore.authErrorMessage = nil
        }
        .buttonStyle(.plain)
        .font(FitUpFont.body(14, weight: .semibold))
        .foregroundStyle(FitUpColors.Neon.blue)
    }

    private func textField(
        title: String,
        text: Binding<String>,
        capitalization: TextInputAutocapitalization = .never,
        keyboardType: UIKeyboardType = .default,
        field: AuthField,
        submitLabel: SubmitLabel,
        onSubmit: @escaping () -> Void
    ) -> some View {
        TextField(title, text: text)
            .textInputAutocapitalization(capitalization)
            .keyboardType(keyboardType)
            .disableAutocorrection(true)
            .focused($focusedField, equals: field)
            .submitLabel(submitLabel)
            .onSubmit(onSubmit)
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

    private func secureField(
        title: String,
        text: Binding<String>,
        field: AuthField,
        submitLabel: SubmitLabel,
        onSubmit: @escaping () -> Void
    ) -> some View {
        SecureField(title, text: text)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .focused($focusedField, equals: field)
            .submitLabel(submitLabel)
            .onSubmit(onSubmit)
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

    private func submitEmailAuth() async {
        guard !isWorking else { return }
        focusedField = nil
        isWorking = true
        defer { isWorking = false }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        if isSignUp {
            await sessionStore.signUp(email: trimmedEmail, password: password, displayName: trimmedName)
        } else {
            await sessionStore.signInWithEmail(email: trimmedEmail, password: password)
        }
    }

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            guard let credential = try result.get().credential as? ASAuthorizationAppleIDCredential else {
                sessionStore.authErrorMessage = "Unable to read Apple ID credential."
                return
            }

            guard let idToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
                sessionStore.authErrorMessage = "Missing Apple identity token."
                return
            }

            // Apple sends `fullName` only on the first authorization for this app + Apple ID.
            let preferredName = Self.displayNameFromApple(credential.fullName)
            await sessionStore.signInWithApple(idToken: idToken, preferredDisplayName: preferredName)
        } catch {
            sessionStore.authErrorMessage = error.localizedDescription
        }
    }

    /// Prefers given name; falls back to a locale-formatted full name from `PersonNameComponents`.
    private static func displayNameFromApple(_ components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let given = components.givenName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !given.isEmpty { return given }
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default
        let formatted = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
        return formatted.isEmpty ? nil : formatted
    }
}

#Preview {
    AuthView()
        .environmentObject(SessionStore())
}
