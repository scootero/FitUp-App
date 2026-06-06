//
//  ChallengeNeonSendButton.swift
//  FitUp
//
//  Send Battle CTA with a rotating neon border until tapped or sending.
//

import SwiftUI

struct ChallengeNeonSendButton: View {
    let isSending: Bool
    var onSend: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var borderRotation: Double = 0
    @State private var didTap = false

    private let cornerRadius = FitUpRadius.md
    private let borderWidth: CGFloat = 2

    var body: some View {
        Button {
            didTap = true
            onSend()
        } label: {
            HStack(spacing: 8) {
                if isSending {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.black)
                    Text("Sending...")
                        .font(FitUpFont.body(16, weight: .heavy))
                        .foregroundStyle(.black)
                } else {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Send Battle!")
                        .font(FitUpFont.body(16, weight: .heavy))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, FitUpRadius.md)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                FitUpColors.Neon.cyan.opacity(0.8),
                                FitUpColors.Neon.cyan.opacity(0.53),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .padding(borderWidth)
            .background {
                if showBorder {
                    RoundedRectangle(cornerRadius: cornerRadius + borderWidth, style: .continuous)
                        .strokeBorder(
                            AngularGradient(
                                colors: [
                                    FitUpColors.Neon.cyan,
                                    FitUpColors.Neon.purple,
                                    FitUpColors.Neon.orange,
                                    FitUpColors.Neon.cyan,
                                ],
                                center: .center,
                                angle: .degrees(showAnimatedBorder ? borderRotation : 0)
                            ),
                            lineWidth: borderWidth
                        )
                        .shadow(color: FitUpColors.Neon.cyan.opacity(0.45), radius: 8, x: 0, y: 0)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isSending)
        .opacity(isSending ? 0.8 : 1)
        .onAppear {
            startBorderAnimationIfNeeded()
        }
        .onChange(of: isSending) { _, sending in
            if sending { didTap = true }
        }
    }

    private var showBorder: Bool {
        !isSending && !didTap
    }

    private var showAnimatedBorder: Bool {
        showBorder && !reduceMotion
    }

    private func startBorderAnimationIfNeeded() {
        guard showAnimatedBorder else { return }
        borderRotation = 0
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            borderRotation = 360
        }
    }
}
