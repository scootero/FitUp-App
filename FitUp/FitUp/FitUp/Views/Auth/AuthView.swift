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
    @State private var isPasswordVisible = false
    @State private var isWorking = false
    @FocusState private var focusedField: AuthField?

    private enum AuthField: Hashable {
        case displayName
        case email
        case password
    }

    var body: some View {
        NavigationStack {
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
            .toolbar(.hidden, for: .navigationBar)
            .fitUpKeyboardDoneToolbar { focusedField = nil }
        }
        .screenTransition()
        .onAppear {
            ProductAnalytics.track(ProductAnalytics.Event.authScreenView, userId: nil)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            FitUpBrandMark(fontSize: 34)
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
            passwordField
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
        AuthAppleSignInButton(isWorking: isWorking) { result in
            Task { await handleAppleSignIn(result: result) }
        }
        .equatable()
    }

    private var modeToggle: some View {
        Button(isSignUp ? "Already have an account? Sign In" : "Need an account? Sign Up") {
            focusedField = nil
            isSignUp.toggle()
            isPasswordVisible = false
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
            .textContentType(contentType(for: field))
            .autocorrectionDisabled()
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

    private var passwordField: some View {
        HStack(spacing: 8) {
            Group {
                if isPasswordVisible {
                    TextField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                } else {
                    SecureField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: .password)
            .submitLabel(.go)
            .onSubmit { Task { await submitEmailAuth() } }

            Button {
                isPasswordVisible.toggle()
            } label: {
                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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

    private func contentType(for field: AuthField) -> UITextContentType? {
        switch field {
        case .displayName: return .name
        case .email: return .username
        case .password: return nil
        }
    }

    private func submitEmailAuth() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        // Resign first so iOS password autofill commits into `password` before we read it.
        focusedField = nil
        FitUpKeyboard.dismiss()
        try? await Task.sleep(for: .milliseconds(80))

        let trimmedEmail = Self.normalizedEmail(email)
        email = trimmedEmail
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard Self.isPlausibleEmail(trimmedEmail) else {
            sessionStore.authErrorMessage = "Enter a full email address, like name@email.com."
            return
        }
        guard !password.isEmpty else {
            sessionStore.authErrorMessage = "Enter the password for that email. The password field was empty."
            return
        }

        if isSignUp {
            await sessionStore.signUp(email: trimmedEmail, password: password, displayName: trimmedName)
        } else {
            await sessionStore.signInWithEmail(email: trimmedEmail, password: password)
        }
    }

    private static func normalizedEmail(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// GoTrue rejects addresses without `@` and a dotted domain as "invalid format".
    private static func isPlausibleEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        let local = parts[0]
        let domain = parts[1]
        return !local.isEmpty && domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
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

/// Sign in with Apple's UIKit button installs a required `width <= 375` constraint.
/// On Plus / Pro Max phones the auth column is wider than that, so Auto Layout breaks
/// the constraint on every layout pass — including each keystroke — and the debug
/// constraint dump stalls the main thread. Cap the button, and skip updates while typing.
private struct AuthAppleSignInButton: View, Equatable {
    var isWorking: Bool
    var onCompletion: (Result<ASAuthorization, Error>) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.isWorking == rhs.isWorking
    }

    var body: some View {
        GeometryReader { geo in
            let available = geo.size.width
            if available.isFinite, available > 1 {
                let width = min(available, 375)
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: onCompletion
                )
                .signInWithAppleButtonStyle(.white)
                .frame(width: width, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                        .strokeBorder(FitUpColors.Neon.cyan.opacity(0.18), lineWidth: 1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .disabled(isWorking)
                .opacity(isWorking ? 0.6 : 1)
            }
        }
        .frame(height: 52)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    AuthView()
        .environmentObject(SessionStore())
}
