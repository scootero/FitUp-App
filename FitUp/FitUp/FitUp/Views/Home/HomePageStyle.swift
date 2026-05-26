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

/// Compact layout metrics for the Home energy-beam hero (production Home only).
enum HomeHeroCompactLayout {
  /// Target ~75% of current hero sizing on Home only.
  static let heroScale: CGFloat = 0.75
  /// Active Battles block: slightly smaller, not full 75%.
  static let battlesScale: CGFloat = 0.88

  static func scaled(_ value: CGFloat, by scale: CGFloat = heroScale) -> CGFloat {
    (value * scale).rounded()
  }
}

private struct HomeHeroCompactScaleKey: EnvironmentKey {
  static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
  var homeHeroCompactScale: CGFloat {
    get { self[HomeHeroCompactScaleKey.self] }
    set { self[HomeHeroCompactScaleKey.self] = newValue }
  }
}
