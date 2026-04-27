//
//  ProductAnalytics+Screen.swift
//  FitUp
//
//  Lightweight screen_viewed / screen_exited (requires authenticated `userId` for RLS).
//

import SwiftUI

extension View {
    /// Tracks `screen_viewed` on appear and `screen_exited` on disappear when `userId` is non-nil.
    func trackProductScreen(_ screenKey: String, userId: UUID?) -> some View {
        modifier(ProductScreenTrackingModifier(screenKey: screenKey, userId: userId))
    }
}

private struct ProductScreenTrackingModifier: ViewModifier {
    let screenKey: String
    let userId: UUID?

    @State private var appearedAt: Date?

    func body(content: Content) -> some View {
        content
            .onAppear {
                appearedAt = Date()
                guard let userId else { return }
                ProductAnalytics.track(
                    ProductAnalytics.Event.screenViewed,
                    userId: userId,
                    screenName: screenKey,
                    properties: ["screen": screenKey]
                )
            }
            .onDisappear {
                guard let userId else {
                    appearedAt = nil
                    return
                }
                var props: [String: String] = ["screen": screenKey]
                if let appearedAt {
                    props["duration_ms"] = String(Int(Date().timeIntervalSince(appearedAt) * 1000))
                }
                ProductAnalytics.track(
                    ProductAnalytics.Event.screenExited,
                    userId: userId,
                    screenName: screenKey,
                    properties: props
                )
                appearedAt = nil
            }
    }
}
