//
//  FitUpKeyboard.swift
//  FitUp
//
//  Shared keyboard dismissal helpers for text fields (auth, onboarding, sheets).
//

import SwiftUI
import UIKit

enum FitUpKeyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

extension View {
    /// Adds a Done button above keyboards that lack a return key (e.g. `.numberPad`).
    func fitUpKeyboardDoneToolbar(onDone: @escaping () -> Void) -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done", action: onDone)
                    .font(FitUpFont.body(16, weight: .semibold))
                    .foregroundStyle(FitUpColors.Neon.cyan)
            }
        }
    }
}
