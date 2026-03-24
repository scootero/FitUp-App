//
//  ContentView.swift
//  FitUp
//
//  Created by Scott on 3/24/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: MainTab = .home
    @State private var smokeStatus: String = "—"
    @State private var healthStatus: String = "—"

    var body: some View {
        ZStack(alignment: .bottom) {
            BackgroundGradientView()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("FitUp")
                        .font(FitUpFont.display(27, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    SectionHeader(title: "Design system", actionTitle: "Slice 0", onAction: {})

                    HStack(spacing: 12) {
                        AvatarView(initials: "FU", color: FitUpColors.Neon.cyan, size: 40, glow: true)
                        NeonBadge(label: "SAMPLE", color: FitUpColors.Neon.green)
                    }

                    RingGaugeView(score: 73, size: 72)

                    HStack(alignment: .bottom, spacing: 8) {
                        DayBarView(day: "M", myVal: 12000, theirVal: 9000, myWon: true, finalized: true, isToday: false)
                        DayBarView(day: "T", myVal: 8000, theirVal: 9500, myWon: false, finalized: false, isToday: true)
                    }
                    .padding()
                    .glassCard(.base)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Supabase: \(smokeStatus)")
                            .font(FitUpFont.body(13))
                            .foregroundStyle(FitUpColors.Text.secondary)
                        Button("Run profiles probe") {
                            Task {
                                let r = await SupabaseSmoke.runProfilesProbe()
                                switch r {
                                case .skippedNoClient:
                                    smokeStatus = "Skipped (no client)"
                                case .success:
                                    smokeStatus = "OK"
                                case .failure(let msg):
                                    smokeStatus = "Error: \(msg)"
                                }
                            }
                        }
                        .solidButton(color: FitUpColors.Neon.cyan)
                    }
                    .padding()
                    .glassCard(.pending)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("HealthKit: \(healthStatus)")
                            .font(FitUpFont.body(13))
                            .foregroundStyle(FitUpColors.Text.secondary)
                        Button("Request HealthKit access") {
                            Task {
                                do {
                                    try await HealthKitService.requestAuthorization()
                                    healthStatus = "Requested"
                                    AppLogger.log(category: "healthkit_read", level: .info, message: "authorization requested from Slice 0 shell")
                                } catch {
                                    healthStatus = error.localizedDescription
                                }
                            }
                        }
                        .ghostButton(color: FitUpColors.Neon.cyan)
                    }
                    .padding()
                    .glassCard(.win)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            .screenTransition()

            FloatingTabBar(selected: $selectedTab) {
                AppLogger.log(category: "ui", level: .info, message: "BATTLE tapped (Slice 0 stub)")
            }
        }
    }
}

#Preview {
    ContentView()
}
