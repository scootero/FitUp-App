//
//  TutorialCardsView.swift
//  FitUp
//
//  Slice 2 onboarding tutorial cards.
//

import SwiftUI

struct TutorialCardsView: View {
    var onContinue: () -> Void

    @State private var page = 0

    private let cards: [TutorialCard] = [
        .init(
            title: "Challenge Friends",
            body: "Pick steps or active calories, choose a format, and get matched in seconds.",
            icon: "figure.run"
        ),
        .init(
            title: "Compete Daily",
            body: "Your HealthKit data powers live score updates and day-by-day battle results.",
            icon: "chart.bar.fill"
        ),
        .init(
            title: "Climb The Ranks",
            body: "Win matches, build streaks, and rise on the weekly FitUp leaderboard.",
            icon: "trophy.fill"
        ),
    ]

    var body: some View {
        VStack(spacing: 18) {
            Text("Welcome to FitUp")
                .font(FitUpFont.display(28, weight: .black))
                .foregroundStyle(FitUpColors.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            TabView(selection: $page) {
                ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: card.icon)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(FitUpColors.Neon.cyan)
                        Text(card.title)
                            .font(FitUpFont.display(22, weight: .bold))
                            .foregroundStyle(FitUpColors.Text.primary)
                        Text(card.body)
                            .font(FitUpFont.body(14, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
                    .glassCard(.base)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 250)

            HStack(spacing: 6) {
                ForEach(cards.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? FitUpColors.Neon.cyan : Color.white.opacity(0.18))
                        .frame(width: index == page ? 20 : 8, height: 6)
                }
            }

            Button(page == cards.count - 1 ? "Continue" : "Next") {
                if page < cards.count - 1 {
                    withAnimation(.easeOut(duration: 0.2)) {
                        page += 1
                    }
                } else {
                    onContinue()
                }
            }
            .solidButton(color: FitUpColors.Neon.cyan)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct TutorialCard {
    let title: String
    let body: String
    let icon: String
}

#Preview {
    ZStack {
        BackgroundGradientView()
        TutorialCardsView(onContinue: {})
            .padding(.horizontal, 16)
    }
}
