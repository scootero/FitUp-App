//
//  HomeStepAveragesDebugCard.swift
//

#if DEBUG
import SwiftUI

/// Dev card: viewer vs featured opponent rolling step averages from `user_health_baselines`, plus balanced scoring hints.
struct HomeStepAveragesDebugCard: View {
    let profileId: UUID?
    let featuredStepMatch: HomeActiveMatch?

    @State private var avg7You: Double?
    @State private var avg30You: Double?
    @State private var avg90You: Double?
    @State private var updatedYou: String?

    @State private var avg7Opp: Double?
    @State private var avg30Opp: Double?
    @State private var avg90Opp: Double?
    @State private var updatedOpp: String?

    private let repo = MetricSnapshotRepository()

    private var loadKey: String {
        let p = profileId?.uuidString ?? "nil"
        let o = featuredStepMatch?.opponent.id.uuidString ?? "nil"
        return "\(p)|\(o)"
    }

    var body: some View {
        Group {
            if profileId != nil {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Step averages (debug)")
                        .font(FitUpFont.mono(10, weight: .heavy))
                        .foregroundStyle(FitUpColors.Neon.cyan)

                    HStack(alignment: .top, spacing: 0) {
                        columnBlock(
                            title: "You",
                            d7: avg7You,
                            d30: avg30You,
                            d90: avg90You,
                            updated: updatedYou,
                            alignment: .leading
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 1)
                            .padding(.vertical, 2)

                        columnBlock(
                            title: opponentColumnTitle,
                            d7: avg7Opp,
                            d30: avg30Opp,
                            d90: avg90Opp,
                            updated: updatedOpp,
                            alignment: .trailing
                        )
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    if let m = featuredStepMatch, m.metricType == "steps" {
                        Divider().opacity(0.25)
                        scoringFooter(for: m)
                    }
                }
                .font(FitUpFont.body(12, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(.base)
                .task(id: loadKey) {
                    await load()
                }
            }
        }
    }

    private var opponentColumnTitle: String {
        guard let o = featuredStepMatch?.opponent else { return "Them" }
        let t = o.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let i = o.initials.trimmingCharacters(in: .whitespacesAndNewlines)
        if !i.isEmpty { return i }
        return "Opponent"
    }

    @ViewBuilder
    private func columnBlock(
        title: String,
        d7: Double?,
        d30: Double?,
        d90: Double?,
        updated: String?,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(title.uppercased())
                .font(FitUpFont.mono(9, weight: .heavy))
                .foregroundStyle(Color.white.opacity(0.38))
                .tracking(1.1)
            Text("7d avg: \(format(d7))")
            Text("30d avg: \(format(d30))")
            Text("90d avg: \(format(d90))")
            Text("Baseline row: \(updated ?? "—")")
                .font(FitUpFont.body(10, weight: .medium))
                .foregroundStyle(FitUpColors.Text.tertiary)
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private func scoringFooter(for m: HomeActiveMatch) -> some View {
        if m.isBalancedStepsBattle {
            VStack(alignment: .leading, spacing: 6) {
                Text("Balanced · Battle Score")
                    .font(FitUpFont.body(11, weight: .heavy))
                    .foregroundStyle(FitUpColors.Neon.orange.opacity(0.9))
                Text("Your day vs baseline: \(formatPercent(m.myBalancedPercent)) · mult \(m.myBalanceMultiplierDisplay)")
                Text("Theirs vs baseline: \(formatPercent(m.theirBalancedPercent)) · mult \(m.theirBalanceMultiplierDisplay)")
                Text("Stored baselines (steps): you \(formatBaseline(m.myBaselineSteps)) vs them \(formatBaseline(m.theirBaselineSteps))")
                    .font(FitUpFont.body(11, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.tertiary)
            }
        } else {
            Text("Scoring: raw step totals (not balanced)")
                .font(FitUpFont.body(11, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.tertiary)
        }
    }

    private func formatBaseline(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.0f", v)
    }

    private func formatPercent(_ v: Double) -> String {
        String(format: "%.1f%%", v)
    }

    private func format(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.1f", v)
    }

    private func load() async {
        guard let profileId else { return }
        let oppId = featuredStepMatch?.opponent.id
        do {
            async let youTask = repo.fetchRollingStepBaselines(userId: profileId)
            let you = try await youTask
            var opp: (d7: Double?, d30: Double?, d90: Double?, updatedAt: String?) = (nil, nil, nil, nil)
            if let oppId, oppId != profileId {
                if let row = try? await repo.fetchRollingStepBaselines(userId: oppId) {
                    opp = row
                }
            }
            await MainActor.run {
                avg7You = you.d7
                avg30You = you.d30
                avg90You = you.d90
                updatedYou = you.updatedAt
                avg7Opp = opp.d7
                avg30Opp = opp.d30
                avg90Opp = opp.d90
                updatedOpp = opp.updatedAt
            }
        } catch {
            await MainActor.run {
                avg7You = nil
                avg30You = nil
                avg90You = nil
                updatedYou = nil
                avg7Opp = nil
                avg30Opp = nil
                avg90Opp = nil
                updatedOpp = nil
            }
        }
    }
}
#endif
