//
//  SectionHeader.swift
//  FitUp
//
//  Maps JSX `SecHead`.
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var onAction: (() -> Void)?

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(FitUpFont.display(16, weight: .bold))
                .foregroundStyle(FitUpColors.Text.primary)

            Spacer(minLength: 0)

            if let actionTitle, let onAction {
                Button(action: onAction) {
                    Text(actionTitle)
                        .font(FitUpFont.body(12, weight: .semibold))
                        .foregroundStyle(FitUpColors.Neon.cyan)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 2)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        SectionHeader(title: "Active Matches", actionTitle: "3 live", onAction: {})
        SectionHeader(title: "Discover Players")
    }
    .padding()
    .background { BackgroundGradientView() }
}
