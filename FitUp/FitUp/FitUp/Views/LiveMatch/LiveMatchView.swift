//
//  LiveMatchView.swift
//  FitUp
//
//  Slice 6 Live Match screen.
//

import SwiftUI

struct LiveMatchView: View {
    var onClose: () -> Void

    @StateObject private var viewModel: LiveMatchViewModel

    init(
        matchId: UUID,
        profile: Profile?,
        onClose: @escaping () -> Void
    ) {
        self.onClose = onClose
        _viewModel = StateObject(
            wrappedValue: LiveMatchViewModel(
                matchId: matchId,
                profile: profile,
                repository: LiveMatchRepository()
            )
        )
    }

    var body: some View {
        ZStack {
            BackgroundGradientView()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(FitUpFont.body(12, weight: .semibold))
                            .foregroundStyle(FitUpColors.Neon.pink)
                            .padding(.horizontal, 2)
                    }

                    liveHeroCard
                    pauseButton
                    seriesCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            LiveToastView(items: viewModel.toasts)
        }
        .task {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
        .screenTransition()
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                onClose()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(FitUpColors.Neon.cyan)
            }
            .buttonStyle(.plain)

            Text("Live Match")
                .font(FitUpFont.display(18, weight: .heavy))
                .foregroundStyle(FitUpColors.Text.primary)

            Spacer()

            NeonBadge(
                label: viewModel.isPaused ? "PAUSED" : "● LIVE",
                color: viewModel.isPaused ? FitUpColors.Neon.orange : FitUpColors.Neon.green
            )
        }
    }

    private var liveHeroCard: some View {
        let accent = viewModel.isWinning ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange
        let variant: GlassCardVariant = viewModel.isWinning ? .win : .lose

        return VStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.56), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)

            VStack(spacing: 20) {
                HStack(alignment: .center, spacing: 16) {
                    competitorColumn(
                        initials: viewModel.meInitials,
                        name: "You",
                        value: viewModel.meCount,
                        color: FitUpColors.Neon.cyan,
                        glow: viewModel.isWinning
                    )

                    VStack(spacing: 4) {
                        Text("VS")
                            .font(FitUpFont.display(20, weight: .black))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        viewModel.isWinning ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange,
                                        (viewModel.isWinning ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange).opacity(0.38),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Text(viewModel.leadLabel)
                            .font(FitUpFont.body(11, weight: .heavy))
                            .foregroundStyle(viewModel.isWinning ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange)
                    }
                    .frame(maxWidth: .infinity)

                    competitorColumn(
                        initials: viewModel.opponentInitials,
                        name: viewModel.opponentName,
                        value: viewModel.opponentCount,
                        color: color(from: viewModel.opponentHexColor),
                        glow: !viewModel.isWinning
                    )
                }

                VStack(spacing: 6) {
                    HStack {
                        Text("0")
                            .font(FitUpFont.mono(9, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.tertiary)
                        Spacer()
                        Text("Goal: \(viewModel.goalValue.formatted())")
                            .font(FitUpFont.mono(9, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.tertiary)
                    }

                    progressBarRow(
                        label: viewModel.meProgressLabel,
                        progress: viewModel.meProgress,
                        color: FitUpColors.Neon.cyan
                    )

                    progressBarRow(
                        label: viewModel.opponentProgressLabel,
                        progress: viewModel.opponentProgress,
                        color: color(from: viewModel.opponentHexColor)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .glassCard(variant)
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .tint(FitUpColors.Neon.cyan)
            }
        }
    }

    private var pauseButton: some View {
        Button {
            viewModel.togglePause()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(viewModel.isPaused ? "Resume Live Display" : "Pause Live Display")
                    .font(FitUpFont.body(15, weight: .heavy))
            }
            .foregroundStyle(viewModel.isPaused ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                    .fill((viewModel.isPaused ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange).opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                            .strokeBorder((viewModel.isPaused ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange).opacity(0.28), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var seriesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MATCH LENGTH · \(viewModel.seriesLabel.uppercased())")
                .font(FitUpFont.mono(11, weight: .bold))
                .foregroundStyle(FitUpColors.Text.secondary)
                .tracking(1)

            HStack(alignment: .center, spacing: 12) {
                Text("\(viewModel.myScore)")
                    .font(FitUpFont.display(32, weight: .black))
                    .foregroundStyle(FitUpColors.Neon.cyan)

                HStack(spacing: 4) {
                    ForEach(Array(viewModel.seriesMarkers.enumerated()), id: \.offset) { _, marker in
                        Circle()
                            .fill(seriesMarkerColor(marker))
                            .frame(width: 14, height: 14)
                            .shadow(color: seriesMarkerGlow(marker), radius: 6, x: 0, y: 0)
                    }
                }
                .frame(maxWidth: .infinity)

                Text("\(viewModel.theirScore)")
                    .font(FitUpFont.display(32, weight: .black))
                    .foregroundStyle(color(from: viewModel.opponentHexColor))
            }

            HStack {
                Text("You")
                Spacer()
                Text(viewModel.opponentName)
            }
            .font(FitUpFont.body(10, weight: .medium))
            .foregroundStyle(FitUpColors.Text.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassCard(.base)
    }

    private func competitorColumn(
        initials: String,
        name: String,
        value: Int,
        color: Color,
        glow: Bool
    ) -> some View {
        VStack(spacing: 5) {
            AvatarView(initials: initials, color: color, size: 54, glow: glow)
            Text(name)
                .font(FitUpFont.body(12, weight: .bold))
                .foregroundStyle(FitUpColors.Text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value.formatted())
                .font(FitUpFont.display(22, weight: .black))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(viewModel.metricUnitLabel)
                .font(FitUpFont.body(10, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func progressBarRow(
        label: String,
        progress: Double,
        color: Color
    ) -> some View {
        GeometryReader { proxy in
            let fullWidth = proxy.size.width
            let clamped = min(max(progress, 0), 1)
            let fillWidth = fullWidth * clamped

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(0.06))

                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.8), color.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: color.opacity(0.45), radius: 10, x: 0, y: 0)
                    .frame(width: max(0, fillWidth))
                    .animation(viewModel.isPaused ? nil : .easeOut(duration: 0.4), value: clamped)

                Text(label)
                    .font(FitUpFont.body(10, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.8))
                    .padding(.leading, 10)
            }
        }
        .frame(height: 22)
    }

    private func seriesMarkerColor(_ marker: LiveSeriesMarker) -> Color {
        switch marker {
        case .me:
            return FitUpColors.Neon.cyan
        case .opponent:
            return FitUpColors.Neon.orange
        case .pending:
            return Color.white.opacity(0.1)
        }
    }

    private func seriesMarkerGlow(_ marker: LiveSeriesMarker) -> Color {
        switch marker {
        case .me:
            return FitUpColors.Neon.cyan.opacity(0.5)
        case .opponent:
            return FitUpColors.Neon.orange.opacity(0.4)
        case .pending:
            return .clear
        }
    }

    private func color(from hex: String) -> Color {
        guard let value = UInt32(hex, radix: 16) else {
            return FitUpColors.Neon.orange
        }
        return Color(rgb: value)
    }
}
