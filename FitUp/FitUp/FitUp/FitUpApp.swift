//
//  FitUpApp.swift
//  FitUp
//
//  Created by Scott on 3/24/26.
//

import SwiftUI
import UIKit

@main
struct FitUpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var sessionStore = SessionStore()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppThirdPartyConfig.configureIfPossible()
        Task { await SubscriptionService.shared.refresh() }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionStore)
                .environmentObject(NotificationService.shared)
                .onAppear {
                    NotificationService.shared.attachSessionStore(sessionStore)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task { await SubscriptionService.shared.refreshEntitlement() }
                }
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            NotificationService.shared.didRegister(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            NotificationService.shared.didFailToRegister(error: error)
        }
    }
}
