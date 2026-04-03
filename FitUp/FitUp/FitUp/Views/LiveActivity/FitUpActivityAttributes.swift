//
//  FitUpActivityAttributes.swift
//  FitUp
//
//  Slice 9: ActivityKit Live Activity attributes and content state.
//  This file is compiled into BOTH the FitUp main app target AND the
//  FitUpWidgetExtension target so both share the exact same Swift type.
//
//  Content-state keys intentionally match dispatch-notification
//  buildLiveActivityPayload field names for push-token update compatibility.
//

import ActivityKit
import Foundation

// MARK: - Attributes (static data set at Activity.request time)

struct FitUpActivityAttributes: ActivityAttributes {

    let matchId: UUID
    let myDisplayName: String
    let opponentDisplayName: String
    let metricType: String          // "steps" | "active_calories"
    let durationDays: Int

    // MARK: - ContentState (dynamic, updated via push or local Activity.update)

    struct ContentState: Codable, Hashable {
        var myTotal: Int
        var opponentTotal: Int
        var myScore: Int
        var theirScore: Int
        var dayNumber: Int

        var myLabel: String { metricLabel(myTotal) }
        var opponentLabel: String { metricLabel(opponentTotal) }

        private func metricLabel(_ value: Int) -> String {
            value >= 1000
                ? String(format: "%.1fk", Double(value) / 1000)
                : "\(value)"
        }

        var leadingLabel: String {
            if myTotal > opponentTotal {
                return "You lead by \(myTotal - opponentTotal)"
            } else if opponentTotal > myTotal {
                return "Behind by \(opponentTotal - myTotal)"
            } else {
                return "Tied"
            }
        }
    }
}
