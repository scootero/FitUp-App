//
//  ChallengeSentView.swift
//  FitUp
//
//  Slice 4 sent confirmation state.
//  Slice 1A: auto-return Home after delay; manual Back to Home remains.
//

import SwiftUI

struct ChallengeSentView: View {
    let opponentName: String
    let metricLabel: String
    let formatLabel: String
    var onBackHome: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var contentOpacity: Double = 1
    @State private var didExit = false
    @State private var autoDismissTask: Task<Void, Never>?
    @State private var exitFadeTask: Task<Void, Never>?

    private static let autoDismissDelay: Duration = .seconds(2.5)
    private static let exitFadeDuration: Duration = .milliseconds(450)

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 10)

            Text("⚡")
                .font(.system(size: 58))

            Text("Battle Sent!")
                .font(FitUpFont.display(22, weight: .black))
                .foregroundStyle(FitUpColors.Neon.cyan)

            Text("Waiting for \(opponentName) to accept...")
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
                .multilineTextAlignment(.center)

            NeonBadge(label: "\(metricLabel) · \(formatLabel)", color: FitUpColors.Neon.cyan)

            Button("Back to Home") {
                exitToHome(immediate: true)
            }
            .buttonStyle(.plain)
            .ghostButton(color: FitUpColors.Neon.cyan)
            .padding(.top, 10)
            .disabled(didExit)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .opacity(contentOpacity)
        .onAppear {
            contentOpacity = reduceMotion ? 1 : 0
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.4)) {
                    contentOpacity = 1
                }
            }
            scheduleAutoDismiss()
        }
        .onDisappear {
            autoDismissTask?.cancel()
            autoDismissTask = nil
            exitFadeTask?.cancel()
            exitFadeTask = nil
        }
    }

    private func scheduleAutoDismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = Task { @MainActor in
            try? await Task.sleep(for: Self.autoDismissDelay)
            guard !Task.isCancelled else { return }
            exitToHome(immediate: reduceMotion)
        }
    }

    /// - Parameter immediate: When true, dismiss without fade (manual Back to Home). Auto-dismiss uses fade unless Reduce Motion.
    private func exitToHome(immediate: Bool = false) {
        guard !didExit else { return }
        didExit = true
        autoDismissTask?.cancel()
        autoDismissTask = nil
        exitFadeTask?.cancel()
        exitFadeTask = nil

        if immediate || reduceMotion {
            onBackHome()
            return
        }

        withAnimation(.easeInOut(duration: 0.45)) {
            contentOpacity = 0
        }

        exitFadeTask = Task { @MainActor in
            try? await Task.sleep(for: Self.exitFadeDuration)
            guard !Task.isCancelled else { return }
            onBackHome()
        }
    }
}
