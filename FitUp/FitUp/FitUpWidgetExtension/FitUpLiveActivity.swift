//
//  FitUpLiveActivity.swift
//  FitUpWidgetExtension
//
//  Slice 9: Live Activity lock-screen and Dynamic Island views.
//  Design tokens come from FitUpActivityAttributes values; hard-coded
//  colors use the exact neon palette from DesignTokens.swift (no assets).
//

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Color constants (mirrors DesignTokens — no shared module needed)

private extension Color {
    static let fitupCyan   = Color(red: 0/255, green: 255/255, blue: 224/255)
    static let fitupOrange = Color(red: 255/255, green: 98/255, blue: 0/255)
    static let fitupBg     = Color(red: 4/255, green: 4/255, blue: 10/255)
    static let fitupText   = Color.white
    static let fitupSecondary = Color.white.opacity(0.52)
}

// MARK: - Live Activity configuration

struct FitUpLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FitUpActivityAttributes.self) { context in
            LockScreenLiveActivityView(
                attributes: context.attributes,
                state: context.state
            )
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.myDisplayName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.fitupCyan)
                        Text(context.state.myLabel)
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.fitupCyan)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.attributes.opponentDisplayName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.fitupOrange)
                        Text(context.state.opponentLabel)
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.fitupOrange)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        Text("DAY \(context.state.dayNumber)/\(context.attributes.durationDays)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.fitupSecondary)
                        ScoreView(
                            myScore: context.state.myScore,
                            theirScore: context.state.theirScore
                        )
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.leadingLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.fitupSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 4)
                }
            } compactLeading: {
                Text(context.state.myLabel)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.fitupCyan)
            } compactTrailing: {
                Text(context.state.opponentLabel)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.fitupOrange)
            } minimal: {
                Image(systemName: "figure.run")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.fitupCyan)
            }
        }
    }
}

// MARK: - Lock screen view

private struct LockScreenLiveActivityView: View {
    let attributes: FitUpActivityAttributes
    let state: FitUpActivityAttributes.ContentState

    var body: some View {
        ZStack {
            Color.fitupBg
            VStack(spacing: 10) {
                HStack {
                    Label(
                        "Day \(state.dayNumber) of \(attributes.durationDays)",
                        systemImage: "flame.fill"
                    )
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.fitupSecondary)
                    Spacer()
                    ScoreView(myScore: state.myScore, theirScore: state.theirScore)
                }

                HStack(spacing: 0) {
                    PlayerColumn(
                        name: attributes.myDisplayName,
                        value: state.myLabel,
                        color: .fitupCyan,
                        alignment: .leading
                    )
                    Spacer()
                    VStack(spacing: 2) {
                        Text("VS")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(Color.fitupSecondary)
                        Text(state.leadingLabel)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.fitupSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(maxWidth: 80)
                    }
                    Spacer()
                    PlayerColumn(
                        name: attributes.opponentDisplayName,
                        value: state.opponentLabel,
                        color: .fitupOrange,
                        alignment: .trailing
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Subviews

private struct PlayerColumn: View {
    let name: String
    let value: String
    let color: Color
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(name)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundStyle(color)
        }
    }
}

private struct ScoreView: View {
    let myScore: Int
    let theirScore: Int

    var body: some View {
        HStack(spacing: 4) {
            Text("\(myScore)")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(Color.fitupCyan)
            Text("–")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.fitupSecondary)
            Text("\(theirScore)")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(Color.fitupOrange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Widget bundle entry point

@main
struct FitUpWidgetBundle: WidgetBundle {
    var body: some Widget {
        FitUpLiveActivity()
    }
}
