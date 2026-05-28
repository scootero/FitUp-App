//
//  SearchingSection.swift
//  FitUp
//
//  Slice 3 searching cards section.
//

import SwiftUI

struct SearchingSection: View {
    let requests: [HomeSearchingRequest]
    let isCancellingSearchId: UUID?
    var onCancel: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Searching", actionTitle: "\(requests.count) live")

            ForEach(requests) { request in
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        SearchingPulseIcon()

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Waiting for another player to join the queue…")
                                .font(FitUpFont.body(14, weight: .bold))
                                .foregroundStyle(HomePageStyle.offWhite)
                            HStack(spacing: 4) {
                                Text("Battle search active ·")
                                Text("\(sportLabel(for: request.metricType)) · \(MatchDurationCopy.competitionLengthBadge(days: request.durationDays)) ·")
                                SearchingElapsedLabel(createdAt: request.createdAt)
                            }
                                .font(FitUpFont.body(12, weight: .medium))
                                .foregroundStyle(HomePageStyle.muted)
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
                .homeLiquidGlassCard(.base)
                .overlay(
                    RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                        .strokeBorder(FitUpColors.Neon.cyan.opacity(0.14), lineWidth: 1)
                )
            }
        }
    }

    private func sportLabel(for metricType: String) -> String {
        metricType == "active_calories" ? "Calories" : "Steps"
    }

}

private struct SearchingPulseIcon: View {
    @State private var animatePulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(FitUpColors.Neon.cyan.opacity(0.12))
                .frame(width: 40, height: 40)

            Circle()
                .strokeBorder(FitUpColors.Neon.cyan.opacity(0.45), lineWidth: 2)
                .frame(width: 20, height: 20)
                .scaleEffect(animatePulse ? 1.35 : 0.72)
                .opacity(animatePulse ? 0.08 : 0.7)

            Circle()
                .fill(FitUpColors.Neon.cyan)
                .frame(width: 8, height: 8)
                .scaleEffect(animatePulse ? 0.9 : 1.1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                animatePulse = true
            }
        }
    }
}

private struct SearchingElapsedLabel: View {
    let createdAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(waitTimeText(at: context.date))
                .font(FitUpFont.body(11, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
                .monospacedDigit()
        }
    }

    private func waitTimeText(at now: Date) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(createdAt)))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return "\(minutes)m \(String(format: "%02d", seconds))s"
    }
}
