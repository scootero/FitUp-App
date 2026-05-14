//
//  HomeFeaturedOpponentHandoffOverlay.swift
//  FitUp
//
//  Slice 7 — Featured opponent change: brief message + wipe/reveal before showing new hero data.
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

/// Full-width overlay sized like the energy hero card: message, then wipe, then `onComplete`.
struct HomeFeaturedOpponentHandoffOverlay: View {
    let newOpponentName: String
    var reduceMotion: Bool
    let onComplete: () -> Void

    @State private var phase: Phase = .message
    @State private var wipeProgress: CGFloat = 0
    @State private var didFireComplete = false

    private enum Phase {
        case message
        case wiping
        case done
    }

    private var messageDuration: TimeInterval { reduceMotion ? 1.0 : 2.5 }
    private var wipeDuration: TimeInterval { reduceMotion ? 0.12 : 0.55 }

    private var resolvedName: String {
        let t = newOpponentName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        return "Someone new"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(FitUpColors.Bg.base.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    FitUpColors.Neon.orange.opacity(0.22),
                                    FitUpColors.Neon.cyan.opacity(0.18),
                                    Color.white.opacity(0.12),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            VStack(spacing: 18) {
                Text("\(resolvedName.uppercased()) IS TRYING TO BEAT YOU!")
                    .font(FitUpFont.body(13, weight: .heavy))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .tracking(1.4)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 20)

                Text("Refreshing today’s battle…")
                    .font(FitUpFont.body(12, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.secondary)
            }
            .padding(.vertical, 36)
            .opacity(phase == .message ? 1 : 0)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.22), value: phase)

            if phase == .wiping || phase == .done {
                GeometryReader { geo in
                    let h = geo.size.height
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    FitUpColors.Neon.cyan.opacity(0.35),
                                    Color.black.opacity(0.92),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: h * 1.05)
                        .offset(y: -h + h * 2 * wipeProgress)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 400)
        .shadow(color: .black.opacity(0.5), radius: 16, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(resolvedName) is trying to beat you. Refreshing today’s battle.")
        .task {
            await runSequence()
        }
    }

    private func runSequence() async {
        try? await Task.sleep(nanoseconds: UInt64(messageDuration * 1_000_000_000))
        guard !Task.isCancelled else { return }
        await MainActor.run {
            phase = .wiping
            wipeProgress = 0
        }
        if reduceMotion {
            await MainActor.run {
                wipeProgress = 1
            }
        } else {
            await animateWipe()
        }
        try? await Task.sleep(nanoseconds: UInt64(max(0.05, wipeDuration) * 0.35 * 1_000_000_000))
        guard !Task.isCancelled else { return }
        await MainActor.run {
            phase = .done
            if !didFireComplete {
                didFireComplete = true
                onComplete()
            }
        }
    }

    private func animateWipe() async {
        let steps = 14
        for i in 1 ... steps {
            try? await Task.sleep(nanoseconds: UInt64((wipeDuration / Double(steps)) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                wipeProgress = CGFloat(i) / CGFloat(steps)
            }
        }
    }
}

#if DEBUG
#Preview("Handoff overlay") {
    HomeFeaturedOpponentHandoffOverlay(
        newOpponentName: "Jordan",
        reduceMotion: false,
        onComplete: {}
    )
    .padding()
    .background(FitUpColors.Bg.base)
}
#endif
