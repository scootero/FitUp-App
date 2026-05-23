//
//  CalendarMonthHeaderView.swift
//  FitUp
//
//  Month title and navigation for the activity calendar.
//

import SwiftUI

struct CalendarMonthHeaderView: View {
    let monthTitle: String
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(monthTitle)
                .font(FitUpFont.display(20, weight: .bold))
                .foregroundStyle(FitUpColors.Text.primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            HStack(spacing: 14) {
                navButton(systemName: "chevron.left", action: onPrevious)
                Button(action: onToday) {
                    Text("Today")
                        .font(FitUpFont.body(12, weight: .bold))
                        .foregroundStyle(FitUpColors.Neon.orange)
                }
                .buttonStyle(.plain)
                navButton(systemName: "chevron.right", action: onNext)
            }
        }
    }

    private func navButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(FitUpColors.Neon.orange)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }
}
