//
//  FormatStepView.swift
//  FitUp
//
//  Slice 4 step 1: choose challenge format.
//

import SwiftUI

struct FormatStepView: View {
    var onSelect: (ChallengeFormatType) -> Void

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Choose match format")
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)

            LazyVGrid(columns: columns, spacing: 10) {
                formatCard(.daily, color: FitUpColors.Neon.yellow)
                formatCard(.firstTo3, color: FitUpColors.Neon.purple)
                formatCard(.bestOf5, color: FitUpColors.Neon.cyan)
                formatCard(.bestOf7, color: FitUpColors.Neon.blue)
            }
        }
    }

    private func formatCard(_ format: ChallengeFormatType, color: Color) -> some View {
        Button {
            onSelect(format)
        } label: {
            VStack(spacing: 4) {
                Text(format.displayName)
                    .font(FitUpFont.display(15, weight: .black))
                    .foregroundStyle(color)
                    .multilineTextAlignment(.center)
                Text(format.subtitle)
                    .font(FitUpFont.body(11, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .glassCard(.base)
            .overlay {
                RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                    .strokeBorder(color.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

