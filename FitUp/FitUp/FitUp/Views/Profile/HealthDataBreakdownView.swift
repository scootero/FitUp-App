//
//  HealthDataBreakdownView.swift
//  FitUp
//
//  Health Data Info — authoritative totals + per-source attribution (debug).
//

import SwiftUI

struct HealthDataBreakdownView: View {
    let profile: Profile?

    @StateObject private var viewModel = HealthDataBreakdownViewModel()

    private static let rangeFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    var body: some View {
        ZStack {
            BackgroundGradientView()
            List {
                if let err = viewModel.errorMessage, !err.isEmpty {
                    Section {
                        Text(err)
                            .font(FitUpFont.body(13))
                            .foregroundStyle(FitUpColors.Neon.pink)
                            .listRowBackground(Color.clear)
                    }
                }
                if let err = viewModel.breakdownError, !err.isEmpty {
                    Section {
                        Text("Per-source data: \(err)")
                            .font(FitUpFont.body(13))
                            .foregroundStyle(FitUpColors.Neon.pink)
                            .listRowBackground(Color.clear)
                    }
                }

                Section {
                    metricBlock(
                        title: "Steps (today)",
                        total: viewModel.stepsToday.map { "\($0)" } ?? "—",
                        sources: viewModel.stepsSources
                    )
                } header: {
                    sectionHeader("Steps")
                } footer: {
                    Text("Per-source totals may not equal combined total due to Apple Health deduplication.")
                        .font(FitUpFont.body(11))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                }

                Section {
                    metricBlock(
                        title: "Active calories (today)",
                        total: viewModel.caloriesToday.map { "\($0)" } ?? "—",
                        sources: viewModel.caloriesSources
                    )
                } header: {
                    sectionHeader("Active calories")
                } footer: {
                    Text("Per-source totals may not equal combined total due to Apple Health deduplication.")
                        .font(FitUpFont.body(11))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                }

                Section {
                    metricBlock(
                        title: "Sleep last night",
                        total: viewModel.sleepLastNightDisplay,
                        sources: viewModel.sleepSources
                    )
                } header: {
                    sectionHeader("Sleep")
                } footer: {
                    Text("Per-source values are approximate and may not equal total due to aggregation logic.")
                        .font(FitUpFont.body(11))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                }

                Section {
                    metricBlock(
                        title: "Resting heart rate",
                        total: viewModel.restingHRDisplay,
                        sources: viewModel.restingHRSources
                    )
                } header: {
                    sectionHeader("Resting heart rate")
                } footer: {
                    Text("Headline shows the most recent sample overall; per-source rows show the latest sample per source (last \(HealthKitPerSourceBreakdown.restingHeartRateLookbackDays) days).")
                        .font(FitUpFont.body(11))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                }

                Section {
                    debugRow(label: "Steps samples", value: "\(viewModel.stepsSampleCount)")
                    debugRow(label: "Active calorie samples", value: "\(viewModel.caloriesSampleCount)")
                    debugRow(label: "Sleep samples (last-night window)", value: "\(viewModel.sleepSampleCount)")
                    debugRow(label: "Resting HR samples (lookback)", value: "\(viewModel.restingHRSampleCount)")
                    debugRow(label: "Today query range", value: todayQueryRangeString)
                    debugRow(label: "Last night window", value: lastNightWindowString)
                    debugRow(label: "Device timezone", value: TimeZone.current.identifier)
                    debugRow(
                        label: "Profile timezone",
                        value: profile?.timezone ?? "—"
                    )
                } header: {
                    sectionHeader("Debug")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(FitUpColors.Neon.cyan)
                        .scaleEffect(1.1)
                }
            }
        }
        .navigationTitle("Health Data Info")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(FitUpColors.Neon.cyan)
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            await viewModel.load()
        }
    }

    private var todayQueryRangeString: String {
        guard let start = viewModel.queryStart, let end = viewModel.queryEnd else {
            return "—"
        }
        let a = Self.rangeFormatter.string(from: start)
        let b = Self.rangeFormatter.string(from: end)
        return "\(a) → \(b)"
    }

    private var lastNightWindowString: String {
        guard let start = viewModel.lastNightWindowStart, let end = viewModel.lastNightWindowEnd else {
            return "—"
        }
        let a = Self.rangeFormatter.string(from: start)
        let b = Self.rangeFormatter.string(from: end)
        return "\(a) → \(b)"
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(FitUpFont.body(11, weight: .bold))
            .foregroundStyle(FitUpColors.Text.tertiary)
    }

    @ViewBuilder
    private func metricBlock(title: String, total: String, sources: [MetricSourceRow]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(FitUpFont.body(14))
                    .foregroundStyle(FitUpColors.Text.secondary)
                Spacer()
                Text(total)
                    .font(FitUpFont.body(16, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.primary)
            }
            if sources.isEmpty {
                Text("No per-source samples")
                    .font(FitUpFont.body(12))
                    .foregroundStyle(FitUpColors.Text.tertiary)
            } else {
                ForEach(sources) { row in
                    HStack(alignment: .firstTextBaseline) {
                        Text("• \(row.sourceName)")
                            .font(FitUpFont.body(12))
                            .foregroundStyle(FitUpColors.Text.secondary)
                        Spacer(minLength: 8)
                        Text(row.detail)
                            .font(FitUpFont.body(12, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.primary)
                    }
                    .padding(.leading, 8)
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.clear)
    }

    private func debugRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(FitUpFont.body(12))
                .foregroundStyle(FitUpColors.Text.tertiary)
            Text(value)
                .font(FitUpFont.body(13, weight: .medium))
                .foregroundStyle(FitUpColors.Text.primary)
                .textSelection(.enabled)
        }
        .listRowBackground(Color.clear)
    }
}

#Preview {
    NavigationStack {
        HealthDataBreakdownView(profile: nil)
    }
}
