//
//  CalendarModePillSwitcher.swift
//  FitUp
//
//  Battles / Steps toggle for the activity calendar.
//

import SwiftUI

struct CalendarModePillSwitcher: View {
    @Binding var mode: ActivityCalendarMode

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ActivityCalendarMode.allCases) { option in
                pillButton(option)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.07))
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.9)
        }
    }

    private func pillButton(_ option: ActivityCalendarMode) -> some View {
        let isSelected = mode == option
        return Button {
            mode = option
        } label: {
            Text(option.pillLabel)
                .font(FitUpFont.body(10, weight: .bold))
                .foregroundStyle(isSelected ? Color.white : FitUpColors.Text.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        FitUpColors.Neon.cyan.opacity(0.35),
                                        FitUpColors.Neon.purple.opacity(0.28),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .overlay {
                                Capsule()
                                    .strokeBorder(FitUpColors.Neon.cyan.opacity(0.45), lineWidth: 0.8)
                            }
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
