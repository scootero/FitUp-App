//
//  HomeStepAveragesDebugCard.swift
//  FitUp
//

#if DEBUG
import SwiftUI

/// Temporary dev verification card for HealthKit-derived aggregates uploaded as rolling averages.
struct HomeStepAveragesDebugCard: View {
    let profileId: UUID?

    @State private var avg7: Double?
    @State private var avg30: Double?
    @State private var avg90: Double?
    @State private var updatedAt: String?

    private let repo = MetricSnapshotRepository()

    var body: some View {
        Group {
            if profileId != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Step Averages (debug)")
                        .font(FitUpFont.mono(10, weight: .heavy))
                        .foregroundStyle(FitUpColors.Neon.cyan)
                    Text("7d avg: \(format(avg7))")
                    Text("30d avg: \(format(avg30))")
                    Text("90d avg: \(format(avg90))")
                    Text("Last updated: \(updatedAt ?? "—")")
                        .font(FitUpFont.body(11, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                }
                .font(FitUpFont.body(12, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(.base)
                .task(id: profileId) {
                    await load()
                }
            }
        }
    }

    private func format(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.1f", v)
    }

    private func load() async {
        guard let profileId else { return }
        do {
            let row = try await repo.fetchRollingStepBaselines(userId: profileId)
            await MainActor.run {
                avg7 = row.d7
                avg30 = row.d30
                avg90 = row.d90
                updatedAt = row.updatedAt
            }
        } catch {
            await MainActor.run {
                avg7 = nil
                avg30 = nil
                avg90 = nil
                updatedAt = nil
            }
        }
    }
}
#endif
