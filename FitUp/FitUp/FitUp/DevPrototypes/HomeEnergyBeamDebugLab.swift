//
//  HomeEnergyBeamDebugLab.swift
//  FitUp
//
//  DEBUG harness for tuning the energy beam hero (collision lab + handoff preview).
//  Not wired into production Home — use EnergyBeamHeroPrototypeView or embed from a DEBUG screen.
//

#if DEBUG

import SwiftUI

/// Beam collision tuning strip formerly shown above the Home hero.
struct HomeEnergyBeamDebugLabStrip: View {
    @ObservedObject var viewModel: HomeViewModel
    @Binding var beamLabUseBeamPreviewOffset: Bool
    @Binding var beamLabSliderOffset: Double
    @Binding var beamLabAppOpenPreviewToken: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DEBUG — Beam collision lab")
                .font(FitUpFont.body(10, weight: .heavy))
                .foregroundStyle(Color.white.opacity(0.4))
                .tracking(1)

            Button {
                beamLabAppOpenPreviewToken = UUID()
            } label: {
                Text("Preview app open animation")
                    .font(FitUpFont.body(11, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(FitUpColors.Neon.cyan.opacity(0.15))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(FitUpColors.Neon.cyan.opacity(0.45), lineWidth: 1)
                            )
                    )
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.featuredHomeStepMatch == nil)

            Toggle("Use Beam Preview Offset", isOn: $beamLabUseBeamPreviewOffset)
                .font(FitUpFont.body(12, weight: .semibold))
                .controlSize(.small)
                .tint(FitUpColors.Neon.cyan)

            Slider(
                value: $beamLabSliderOffset,
                in: -10_000 ... 10_000,
                step: 1
            )
            .controlSize(.small)
            .tint(FitUpColors.Neon.cyan)
            .disabled(!beamLabUseBeamPreviewOffset)

            HStack(spacing: 6) {
                presetButton(title: "Center") {
                    beamLabSliderOffset = 0
                }
                presetButton(title: "User Push") {
                    beamLabSliderOffset = 2_500
                }
                presetButton(title: "Opponent Push") {
                    beamLabSliderOffset = -2_500
                }
            }

            Button {
                viewModel.debugPreviewHeroOpponentHandoff()
            } label: {
                Text("Preview opponent handoff (Slice 7)")
                    .font(FitUpFont.body(11, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(FitUpColors.Neon.orange.opacity(0.15))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(FitUpColors.Neon.orange.opacity(0.45), lineWidth: 1)
                            )
                    )
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.heroOpponentHandoff != nil || viewModel.featuredHomeStepMatch == nil)

            Text("Beam preview offset animates collision only (4s min). Scores/copy stay live. App-open preview replays intro + score catch-up.")
                .font(FitUpFont.body(10, weight: .medium))
                .foregroundStyle(FitUpColors.Text.tertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func presetButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(FitUpFont.body(11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.vertical, 5)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                )
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .buttonStyle(.plain)
    }
}

#endif
