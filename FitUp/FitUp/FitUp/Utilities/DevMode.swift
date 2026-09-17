//
//  DevMode.swift
//  FitUp
//
//  Developer tools availability. Compile-time Debug only — never ships in Release.
//

import Foundation

enum DevMode {
    /// Developer tools UI may appear (Xcode Debug builds only).
    static var isAvailable: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Developer tool content (analytics buffer, log viewer) is active in Debug.
    static var isActive: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
