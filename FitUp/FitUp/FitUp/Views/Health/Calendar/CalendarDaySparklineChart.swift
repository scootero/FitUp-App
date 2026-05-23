//
//  CalendarDaySparklineChart.swift
//  FitUp
//
//  Home-style intraday sparkline for calendar day detail (Steps mode).
//

import SwiftUI

struct CalendarDaySparklineChart: View {
    let values: [CGFloat]
    var accent: Color = FitUpColors.Neon.cyan

    var body: some View {
        GeometryReader { geo in
            let points = sampledPoints(values: values, in: geo.size)
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.32))

                if points.count >= 2 {
                    sparkPath(points: points)
                        .stroke(
                            accent.opacity(0.35),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                        )
                    sparkPath(points: points)
                        .stroke(
                            accent,
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: accent.opacity(0.45), radius: 4)

                    if let last = points.last {
                        Circle()
                            .fill(accent)
                            .frame(width: 7, height: 7)
                            .position(last)
                            .shadow(color: accent.opacity(0.6), radius: 5)
                    }
                }
            }
        }
        .frame(height: 112)
    }

    private func sparkPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func sampledPoints(values: [CGFloat], in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty, size.width > 1, size.height > 1 else { return [] }
        let pad: CGFloat = 14
        let w = size.width - pad * 2
        let h = size.height - pad * 2
        let count = values.count
        return values.enumerated().map { index, value in
            let x = pad + (count == 1 ? w / 2 : w * CGFloat(index) / CGFloat(count - 1))
            let y = pad + h * (1 - min(max(value, 0), 1))
            return CGPoint(x: x, y: y)
        }
    }
}
