//
//  AnalyticsDebugView.swift
//  FitUp
//

import SwiftUI

#if DEBUG
struct AnalyticsDebugView: View {
    var body: some View {
        List {
            Section("Foreground session") {
                if let sid = ProductAnalytics.currentForegroundSessionIdForDebug() {
                    Text(sid.uuidString)
                        .font(.system(.caption, design: .monospaced))
                } else {
                    Text("nil (backgrounded)")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Last insert error") {
                Text(ProductAnalytics.debugLastInsertError() ?? "—")
                    .font(.caption)
            }

            Section("Recent events (newest last)") {
                let rows = ProductAnalytics.debugRecentEvents()
                if rows.isEmpty {
                    Text("None yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, pair in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pair.1)
                                .font(.subheadline.weight(.semibold))
                            Text(pair.0.formatted(date: .omitted, time: .standard))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Analytics debug")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
