//
//  HomeFeaturedOpponentHandoffOverlay.swift
//  FitUp
//
//  Slice 7 — Blur veil + match-found style rival alert, linear crossfade into handoff beam intro.
//

import SwiftUI

enum HomeFeaturedOpponentHandoffFeature {
    private static let enabledKey = "fitup.hero_opponent_handoff_enabled"

    /// UserDefaults override; default **on** until explicitly set to `false`.
    static var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: enabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: enabledKey)
    }
}

/// Covers the energy hero card: material blur only (no tint), match-found pop-up, then linear crossfade out.
struct HomeFeaturedOpponentHandoffOverlay: View {
    let newOpponentName: String
    var reduceMotion: Bool
    /// 0…1 while the new hero fades in under the dissolving blur (driven with blur fade-out).
    @Binding var crossfadeProgress: CGFloat
    /// Popup dismissed — parent mounts new hero and starts app-open beam intro.
    var onBeginReveal: () -> Void
    let onComplete: () -> Void

    @State private var blurStrength: CGFloat = 0
    @State private var alertScale: CGFloat = 0.06
    @State private var alertOpacity: CGFloat = 0
    @State private var alertVisible = true
    @State private var didBeginReveal = false
    @State private var didFireComplete = false

    private var resolvedName: String {
        let t = newOpponentName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        return "Someone new"
    }

    private var alertScaleInDuration: TimeInterval { reduceMotion ? 0.1 : 0.4 }
    /// Time at full size before popup + blur veil fade out together.
    private var alertHoldDuration: TimeInterval { reduceMotion ? 0.35 : 2.0 }
    private var alertScaleOutDuration: TimeInterval { reduceMotion ? 0.1 : 0.55 }
    private var blurInDuration: TimeInterval { reduceMotion ? 0.08 : 0.35 }
    private var blurOutDuration: TimeInterval { reduceMotion ? 0.12 : 0.8 }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                HandoffHeroBlurVeil(strength: blurStrength)

                if alertVisible {
                    HandoffNewRivalMatchFoundAlert(
                        opponentName: resolvedName,
                        scale: alertScale,
                        opacity: alertOpacity
                    )
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(resolvedName) is your new top rival to beat.")
        .task {
            await runSequence()
        }
    }

    private func runSequence() async {
        if reduceMotion {
            await MainActor.run {
                blurStrength = 1
                alertScale = 1
                alertOpacity = 1
                crossfadeProgress = 0
            }
            try? await Task.sleep(nanoseconds: UInt64(alertHoldDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await exitAlertAndDissolveBlur()
            finish()
            return
        }

        await MainActor.run {
            crossfadeProgress = 0
            alertScale = 0.06
            alertOpacity = 0
            withAnimation(.linear(duration: blurInDuration)) {
                blurStrength = 1
            }
            withAnimation(.easeOut(duration: alertScaleInDuration)) {
                alertScale = 1
                alertOpacity = 1
            }
        }
        try? await Task.sleep(nanoseconds: UInt64(alertScaleInDuration * 1_000_000_000))
        guard !Task.isCancelled else { return }
        try? await Task.sleep(nanoseconds: UInt64(alertHoldDuration * 1_000_000_000))
        guard !Task.isCancelled else { return }

        await exitAlertAndDissolveBlur()
        finish()
    }

    /// Alert scales down while blur + hero crossfade dissolve over 1.5s.
    private func exitAlertAndDissolveBlur() async {
        beginRevealIfNeeded()
        await MainActor.run {
            withAnimation(.easeIn(duration: alertScaleOutDuration)) {
                alertScale = 0.06
                alertOpacity = 0
            }
            withAnimation(.linear(duration: blurOutDuration)) {
                blurStrength = 0
                crossfadeProgress = 1
            }
        }
        try? await Task.sleep(nanoseconds: UInt64(max(alertScaleOutDuration, blurOutDuration) * 1_000_000_000))
        await MainActor.run {
            alertVisible = false
        }
    }

    private func beginRevealIfNeeded() {
        guard !didBeginReveal else { return }
        didBeginReveal = true
        onBeginReveal()
    }

    private func finish() {
        guard !didFireComplete else { return }
        didFireComplete = true
        onComplete()
    }
}

// MARK: - Blur veil (material only — no color tint)

private struct HandoffHeroBlurVeil: View {
    let strength: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.clear)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(strength)
            }
            .allowsHitTesting(false)
    }
}

// MARK: - Match-found style rival alert

private struct HandoffNewRivalMatchFoundAlert: View {
    let opponentName: String
    let scale: CGFloat
    let opacity: CGFloat

    var body: some View {
        VStack(spacing: 14) {
            Text("NEW TOP RIVAL!")
                .font(FitUpFont.mono(17, weight: .heavy))
                .foregroundStyle(FitUpColors.Neon.green)
                .shadow(color: FitUpColors.Neon.green.opacity(0.5), radius: 10)
                .multilineTextAlignment(.center)

            Text("VS \(opponentName.uppercased())")
                .font(FitUpFont.mono(13, weight: .semibold))
                .foregroundStyle(FitUpColors.Neon.yellow)
                .multilineTextAlignment(.center)

            Text("YOUR NEW TOP RIVAL TO BEAT")
                .font(FitUpFont.mono(11, weight: .medium))
                .foregroundStyle(FitUpColors.Neon.cyan)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
        .padding(28)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: FitUpRadius.lg)
                .fill(Color(rgb: 0x0A1020).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: FitUpRadius.lg)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    FitUpColors.Neon.cyan,
                                    FitUpColors.Neon.purple,
                                    FitUpColors.Neon.green,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
        )
        .shadow(color: FitUpColors.Neon.cyan.opacity(0.25), radius: 22)
        .scaleEffect(scale)
        .opacity(opacity)
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
#Preview("Handoff overlay") {
    struct PreviewHost: View {
        @State private var crossfade: CGFloat = 0
        var body: some View {
            HomeFeaturedOpponentHandoffOverlay(
                newOpponentName: "Jordan",
                reduceMotion: false,
                crossfadeProgress: $crossfade,
                onBeginReveal: {},
                onComplete: {}
            )
            .frame(height: 400)
            .padding()
            .background(FitUpColors.Bg.base)
        }
    }
    return PreviewHost()
}
#endif
