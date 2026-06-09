//
//  LiveActivitiesNotificationsSettingsView.swift
//  FitUp
//
//  Profile sub-screen: Live Activities (local) and All Notifications (Supabase).
//

import SwiftUI

struct LiveActivitiesNotificationsSettingsView: View {
    let profile: Profile?

    @AppStorage(NotificationPreferences.liveActivitiesEnabledKey) private var liveActivitiesEnabled = true
    @State private var notificationsEnabled = true

    private var liveActivitiesHelperText: String {
        if notificationsEnabled {
            return "Show active battles on your Lock Screen and Dynamic Island."
        }
        return "Turn on notifications to use Live Activities."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsGroupView(title: "PREFERENCES") {
                    SettingsRowView(
                        sfSymbol: "lock.rectangle.on.rectangle",
                        label: "Live Activities",
                        helperText: liveActivitiesHelperText,
                        isDisabled: !notificationsEnabled,
                        showSeparator: true,
                        action: .toggle($liveActivitiesEnabled)
                    )
                    SettingsRowView(
                        sfSymbol: "bell",
                        label: "All Notifications",
                        helperText: "Allow FitUp to send battle updates and reminders.",
                        showSeparator: false,
                        action: .toggle($notificationsEnabled)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 40)
        }
        .background(BackgroundGradientView())
        .navigationTitle("Live Activities & Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            syncFromProfile()
            enforceNotificationsCouplingIfNeeded()
        }
        .onChange(of: profile?.notificationsEnabled) { _, _ in
            syncFromProfile()
            enforceNotificationsCouplingIfNeeded()
        }
        .onChange(of: liveActivitiesEnabled) { _, newValue in
            guard !newValue else { return }
            LiveActivityCoordinator.shared.endActivity()
        }
        .onChange(of: notificationsEnabled) { _, newValue in
            if !newValue {
                liveActivitiesEnabled = false
                LiveActivityCoordinator.shared.endActivity()
            }
            guard let authUserId = profile?.authUserId else { return }
            Task {
                await ProfileRepository().updateNotificationsEnabled(newValue, authUserId: authUserId)
            }
        }
    }

    private func syncFromProfile() {
        if let enabled = profile?.notificationsEnabled {
            notificationsEnabled = enabled
        }
    }

    private func enforceNotificationsCouplingIfNeeded() {
        guard !notificationsEnabled, liveActivitiesEnabled else { return }
        liveActivitiesEnabled = false
        LiveActivityCoordinator.shared.endActivity()
    }
}

#Preview {
    NavigationStack {
        LiveActivitiesNotificationsSettingsView(profile: nil)
    }
}
