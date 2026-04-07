//
//  ProfileAccentColor.swift
//  FitUp
//
//  Deterministic accent hex / SwiftUI Color from profile id (matches MatchRepository palette).
//

import SwiftUI

enum ProfileAccentColor {
    private static let paletteHex = ["00AAFF", "FF6200", "BF5FFF", "FFE000", "39FF14", "FF2D9B"]

    static func hex(for userId: UUID) -> String {
        let index = abs(userId.hashValue) % paletteHex.count
        return paletteHex[index]
    }

    static func color(for userId: UUID) -> Color {
        swiftUIColor(hex: hex(for: userId))
    }

    static func swiftUIColor(hex: String) -> Color {
        guard let v = UInt32(hex, radix: 16) else {
            return FitUpColors.Neon.cyan
        }
        return Color(rgb: v)
    }
}
