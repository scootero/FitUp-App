//
//  LogViewerView.swift
//  FitUp
//
//  Slice 14 — Dev Tools log viewer: monospace green log lines, time-range + level filters,
//  JSON export via ShareLink.
//  Only rendered when Dev Mode is ON (caller guards #if DEBUG).
//

import SwiftUI

struct LogViewerView: View {
    @ObservedObject var viewModel: ProfileViewModel
    let profile: Profile?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header ───────────────────────────────────────────────────
            HStack(alignment: .firstTextBaseline) {
                Text("LOG VIEWER")
                    .font(FitUpFont.body(11, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.tertiary)
                    .kerning(1.5)
                Spacer()
                exportButton
            }
            .padding(.bottom, 8)
            .padding(.leading, 2)

            // ── Filter bar ───────────────────────────────────────────────
            filterBar
                .padding(.bottom, 10)

            // ── Log entries ──────────────────────────────────────────────
            logEntriesCard
        }
        .task {
            await viewModel.fetchLogs(profile: profile)
        }
        .onChange(of: viewModel.logTimeFilter) {
            Task { await viewModel.fetchLogs(profile: profile) }
        }
        .onChange(of: viewModel.logLevelFilter) {
            Task { await viewModel.fetchLogs(profile: profile) }
        }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Time-range chips
                ForEach(ProfileViewModel.LogTimeRange.allCases) { range in
                    filterChip(label: range.rawValue, isActive: viewModel.logTimeFilter == range) {
                        viewModel.logTimeFilter = range
                    }
                }

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1, height: 18)
                    .padding(.horizontal, 2)

                // Level chips
                ForEach(ProfileViewModel.LogLevelFilter.allCases) { lvl in
                    filterChip(label: lvl.rawValue, isActive: viewModel.logLevelFilter == lvl) {
                        viewModel.logLevelFilter = lvl
                    }
                }
            }
        }
    }

    private func filterChip(label: String, isActive: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(label)
                .font(FitUpFont.body(11, weight: .semibold))
                .foregroundStyle(isActive ? FitUpColors.Neon.cyan : FitUpColors.Text.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: FitUpRadius.pill)
                        .fill(isActive
                              ? FitUpColors.Neon.cyan.opacity(0.12)
                              : Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: FitUpRadius.pill)
                                .strokeBorder(
                                    isActive ? FitUpColors.Neon.cyan.opacity(0.35) : Color.clear,
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Log entries

    @ViewBuilder
    private var logEntriesCard: some View {
        if viewModel.isLoadingLogs {
            HStack {
                Spacer()
                ProgressView()
                    .tint(FitUpColors.Neon.green)
                    .padding(16)
                Spacer()
            }
            .glassCard(.base)
        } else if viewModel.logs.isEmpty {
            Text("No logs found for this time range.")
                .font(FitUpFont.mono(10))
                .foregroundStyle(FitUpColors.Neon.green.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .glassCard(.base)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(viewModel.logs.enumerated()), id: \.element.id) { index, entry in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(formatLine(entry))
                            .font(FitUpFont.mono(10))
                            .foregroundStyle(lineColor(for: entry.level))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, index == 0 ? 0 : 5)
                            .padding(.bottom, index == viewModel.logs.count - 1 ? 0 : 5)

                        if index < viewModel.logs.count - 1 {
                            Rectangle()
                                .fill(FitUpColors.Neon.green.opacity(0.08))
                                .frame(height: 1)
                        }
                    }
                }
            }
            .padding(14)
            .glassCard(.base)
        }
    }

    // MARK: - Export button

    private var exportButton: some View {
        let json = viewModel.exportJSON()
        let text = String(data: json, encoding: .utf8) ?? "[]"
        return ShareLink(
            item: text,
            preview: SharePreview("FitUp Logs")
        ) {
            Text("Export")
                .font(FitUpFont.body(12, weight: .semibold))
                .foregroundStyle(FitUpColors.Neon.cyan)
        }
    }

    // MARK: - Helpers

    private func formatLine(_ entry: AppLogEntry) -> String {
        let formatted = Self.timeFormatter.string(from: entry.createdAt)
        return "[\(formatted)] [\(entry.category)] \(entry.message)"
    }

    private func lineColor(for level: String) -> Color {
        switch level {
        case "error":   return FitUpColors.Neon.red
        case "warning": return FitUpColors.Neon.yellow
        default:        return FitUpColors.Neon.green
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}

// MARK: - Preview

#Preview {
    ZStack {
        BackgroundGradientView()
        ScrollView {
            LogViewerView(viewModel: ProfileViewModel(), profile: nil)
                .padding(.horizontal, 16)
                .padding(.top, 20)
        }
    }
}
