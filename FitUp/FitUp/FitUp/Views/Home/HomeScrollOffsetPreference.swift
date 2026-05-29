//
//  HomeScrollOffsetPreference.swift
//  FitUp
//
//  Tracks Home ScrollView offset to dismiss the intro tip.
//

import SwiftUI

enum HomeScrollCoordinateSpace {
    static let name = "homeScroll"
}

struct HomeScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
