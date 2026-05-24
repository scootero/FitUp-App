//
//  HomePageStyle.swift
//  FitUp
//
//  Home-only typography and color tweaks (brighter copy, slightly off-white primaries).
//

import SwiftUI

enum HomePageStyle {
  /// Near-white body/headline copy on Home (not pure #FFF).
  static let offWhite = Color(red: 0.97, green: 0.97, blue: 0.95)

  /// Brighter muted labels (was ~52% white).
  static let muted = Color.white.opacity(0.74)

  /// Brighter faint labels (was ~27% white).
  static let faint = Color.white.opacity(0.46)
}
