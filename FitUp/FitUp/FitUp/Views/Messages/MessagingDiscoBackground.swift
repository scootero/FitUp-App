//
//  MessagingDiscoBackground.swift
//  FitUp
//
//  Simple battle-arena gradient + subtle grid for Messages.
//

import SwiftUI

// MARK: - Layout tokens

enum MessagingLayout {
    static let horizontalInset: CGFloat = 20
    static let verticalInset: CGFloat = 16
    static let composerBottomPad: CGFloat = 10
    static let bubbleMaxWidth: CGFloat = 280
    static let bubbleSideGutter: CGFloat = 24
}

// MARK: - Background

struct MessagingBackground: View {
    var body: some View {
        ZStack {
            FitUpColors.Bg.base

            LinearGradient(
                colors: [
                    FitUpColors.Neon.orange.opacity(0.1),
                    Color.clear,
                    FitUpColors.Neon.cyan.opacity(0.08),
                ],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )

            RadialGradient(
                colors: [
                    FitUpColors.Neon.purple.opacity(0.07),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.5, y: 0.08),
                startRadius: 20,
                endRadius: 320
            )

            messagingGridTexture(opacity: 0.028, step: 36)

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.28),
                ],
                startPoint: UnitPoint(x: 0.5, y: 0.55),
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

/// Kept for call sites that still reference the old name.
typealias MessagingDiscoBackground = MessagingBackground

// MARK: - Shared texture

private func messagingGridTexture(opacity: Double, step: CGFloat) -> some View {
    GeometryReader { geo in
        Canvas { context, size in
            var path = Path()
            for x in stride(from: 0, through: size.width, by: step) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0, through: size.height, by: step) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(Color.white.opacity(opacity)), lineWidth: 0.5)
        }
        .frame(width: geo.size.width, height: geo.size.height)
    }
}
