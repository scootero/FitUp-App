//
//  FitUpApp.swift
//  FitUp
//
//  Created by Scott on 3/24/26.
//

import SwiftUI

@main
struct FitUpApp: App {
    init() {
        AppThirdPartyConfig.configureIfPossible()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
