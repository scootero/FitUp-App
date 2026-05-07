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
            Text(title.uppercased())
                .font(FitUpFont.mono(11, weight: .bold))
                .fitUpGlobalTitleStyle(weight: .bold, tracking: 0.9)
                .foregroundStyle(FitUpColors.Text.tertiary.opacity(0.9))

            Spacer(minLength: 0)

            if let actionTitle, let onAction {
                Button(action: onAction) {
                    Text(actionTitle)
                        .font(FitUpFont.mono(10, weight: .semibold))
                        .foregroundStyle(FitUpColors.Neon.cyan.opacity(0.92))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 3)
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
