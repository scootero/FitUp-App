//
//  ActivityCalendarLayout.swift
//  FitUp
//
//  Compact (sheet) vs expanded (inline stats card) sizing for the activity calendar.
//

import SwiftUI

enum ActivityCalendarLayout {
    case compact
    case expanded

    var ringSize: CGFloat {
        switch self {
        case .compact: 26
        case .expanded: 48
        }
    }

    var dayNumberFontSize: CGFloat {
        switch self {
        case .compact: 12
        case .expanded: 13
        }
    }

    var gridColumnSpacing: CGFloat {
        switch self {
        case .compact: 4
        case .expanded: 2
        }
    }

    var gridRowSpacing: CGFloat {
        switch self {
        case .compact: 2
        case .expanded: 4
        }
    }

    var cellVerticalPadding: CGFloat {
        switch self {
        case .compact: 4
        case .expanded: 6
        }
    }
}
