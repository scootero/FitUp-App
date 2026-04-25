//
//  SearchingSection.swift
//  FitUp
//
//  Slice 3 searching cards section.
//

import Combine
import SwiftUI

struct SearchingSection: View {
    let requests: [HomeSearchingRequest]
    let isCancellingSearchId: UUID?
    var waitTimeText: (HomeSearchingRequest) -> String
    var onCancel: (UUID) -> Void

    @State private var dotCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Searching", actionTitle: "\(requests.count) live")

            ForEach(requests) { request in
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(FitUpColors.Neon.purple.opacity(0.15))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(FitUpColors.Neon.purple)
                            }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Finding opponent\(String(repeating: ".", count: dotCount))")
                                .font(FitUpFont.body(13, weight: .bold))
                                .foregroundStyle(FitUpColors.Text.primary)
                            Text("\(sportLabel(for: request.metricType)) · \(MatchDurationCopy.competitionLengthBadge(days: request.durationDays)) · \(waitTimeText(request))")
                                .font(FitUpFont.body(11, weight: .medium))
                                .foregroundStyle(FitUpColors.Text.secondary)
                        }

                        Spacer(minLength: 0)

                        Button("Cancel") {
                            onCancel(request.id)
                        }
                        .buttonStyle(.plain)
                        .font(FitUpFont.body(12, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.05))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                        )
                        .disabled(request.isLocalPlaceholder || isCancellingSearchId == request.id)
                        .opacity((request.isLocalPlaceholder || isCancellingSearchId == request.id) ? 0.5 : 1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .glassCard(.base)
            }
        }
        .onReceive(
            Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()
        ) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }

    private func sportLabel(for metricType: String) -> String {
        metricType == "active_calories" ? "Calories" : "Steps"
    }

}
