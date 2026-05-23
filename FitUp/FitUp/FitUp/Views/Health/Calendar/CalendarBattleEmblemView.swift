//
//  CalendarBattleEmblemView.swift
//  FitUp
//
//  Rivalry match emblem (green win / red loss) with slam-in animation.
//

import SwiftUI

struct CalendarBattleEmblemView: View {
    let viewerWon: Bool
    let slamIndex: Int
    let isVisible: Bool

    private var tint: Color {
        viewerWon ? FitUpColors.Neon.green : FitUpColors.Neon.red
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.18))
                .overlay {
                    Circle()
                        .strokeBorder(tint.opacity(0.55), lineWidth: 1.2)
                }

            Image(systemName: "bolt.shield.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
                .shadow(color: tint.opacity(0.5), radius: 4)
        }
        .frame(width: 34, height: 34)
        .scaleEffect(isVisible ? 1 : 1.65)
        .opacity(isVisible ? 1 : 0)
        .rotationEffect(.degrees(isVisible ? 0 : -18))
        .animation(
            .spring(response: 0.34, dampingFraction: 0.62).delay(Double(slamIndex) * 0.07),
            value: isVisible
        )
    }
}

struct CalendarBattleEmblemStrip: View {
    let emblems: [CalendarRivalryEmblem]
    @State private var revealEmblems = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RIVALRY RUN")
                .font(FitUpFont.mono(9, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(FitUpColors.Text.tertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(emblems.enumerated()), id: \.element.id) { index, emblem in
                        CalendarBattleEmblemView(
                            viewerWon: emblem.viewerWon,
                            slamIndex: index,
                            isVisible: revealEmblems
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .onAppear {
            revealEmblems = false
            DispatchQueue.main.async {
                revealEmblems = true
            }
        }
        .onChange(of: emblems.map(\.id)) { _, _ in
            revealEmblems = false
            DispatchQueue.main.async {
                revealEmblems = true
            }
        }
    }
}
