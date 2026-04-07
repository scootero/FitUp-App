//
//  HRZonesCard.swift
//  FitUp
//
//  Slice 12 — HR zones (`HealthScreen` + JSX `hrZones` colors).
//

import SwiftUI

struct HRZonesCard: View {
    let restingHRText: String
    let zones: [HealthHRZoneRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: FitUpRadius.pill)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 40, height: 6)
                Text("\(restingHRText) bpm resting")
                    .font(FitUpFont.body(14))
                    .foregroundStyle(FitUpColors.Text.secondary)
            }
            .padding(.bottom, 14)

            Text("From most recent workout")
                .font(FitUpFont.body(11))
                .foregroundStyle(FitUpColors.Text.tertiary)
                .padding(.bottom, 14)

            ForEach(Array(zones.enumerated()), id: \.element.id) { index, zone in
                hrZoneProgressBar(
                    label: zone.label,
                    value: zone.valueLabel,
                    percent: zone.percent,
                    color: zoneColor(index: index)
                )
            }
        }
        .padding(18)
        .glassCard(.base)
    }

    private func zoneColor(index: Int) -> Color {
        switch index {
        case 0: return Color.white.opacity(0.25)
        case 1: return FitUpColors.Neon.blue
        case 2: return FitUpColors.Neon.cyan
        case 3: return FitUpColors.Neon.orange
        default: return FitUpColors.Neon.red
        }
    }

    private func hrZoneProgressBar(label: String, value: String, percent: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(FitUpFont.body(13))
                    .foregroundStyle(FitUpColors.Text.secondary)
                Spacer()
                Text(value)
                    .font(FitUpFont.mono(13, weight: .bold))
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, geo.size.width * CGFloat(percent / 100)))
                }
            }
            .frame(height: 6)
        }
        .padding(.bottom, 12)
    }
}

#Preview {
    HRZonesCard(
        restingHRText: "58",
        zones: [
            HealthHRZoneRow(id: 0, label: "Zone 1 · Rest", valueLabel: "0%", percent: 0),
            HealthHRZoneRow(id: 1, label: "Zone 2 · Fat burn", valueLabel: "3%", percent: 3),
            HealthHRZoneRow(id: 2, label: "Zone 3 · Cardio", valueLabel: "15%", percent: 15),
            HealthHRZoneRow(id: 3, label: "Zone 4 · Peak", valueLabel: "44%", percent: 44),
            HealthHRZoneRow(id: 4, label: "Zone 5 · Max", valueLabel: "38%", percent: 38),
        ]
    )
    .padding()
    .background { BackgroundGradientView() }
}
