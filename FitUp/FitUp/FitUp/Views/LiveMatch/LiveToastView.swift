//
//  LiveToastView.swift
//  FitUp
//
//  Slice 6 toast overlay for live match events.
//

import SwiftUI

struct LiveToastView: View {
    let items: [LiveToastItem]

    var body: some View {
        VStack(spacing: 5) {
            ForEach(items) { item in
                Text(item.message)
                    .font(FitUpFont.body(12, weight: .heavy))
                    .foregroundStyle(color(for: item.tone))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule(style: .continuous)
                            .fill(color(for: item.tone).opacity(0.13))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(color(for: item.tone).opacity(0.31), lineWidth: 1)
                            )
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: 280)
        .padding(.top, 70)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeOut(duration: 0.2), value: items)
        .allowsHitTesting(false)
    }

    private func color(for tone: LiveToastTone) -> Color {
        switch tone {
        case .cyan:
            return FitUpColors.Neon.cyan
        case .orange:
            return FitUpColors.Neon.orange
        case .green:
            return FitUpColors.Neon.green
        }
    }
}
