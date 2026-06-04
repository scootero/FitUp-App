//
//  HoldToScrubInteraction.swift
//  FitUp
//
//  Shared hold-then-scrub logic for intraday charts inside scroll views.
//
//  Uses LongPress → Drag (not DragGesture minimumDistance 0 alone) so vertical
//  scroll can win when the finger moves before the hold completes (iOS 18+).
//

import SwiftUI

enum HoldToScrubInteraction {
    /// Hold time before scrub mode activates.
    static let defaultHoldDuration: Double = 0.5
    /// Finger must stay within this radius while holding; movement beyond cancels (scroll wins).
    static let defaultMoveTolerance: CGFloat = 10
    /// Wait before showing arming chrome so quick scroll swipes stay invisible.
    static let armingVisualDelay: Double = 0.12

    /// Long-press then horizontal drag. Attach with `.simultaneousGesture` inside `ScrollView`.
    static func scrubGesture(
        holdDuration: Double = defaultHoldDuration,
        moveTolerance: CGFloat = defaultMoveTolerance,
        onActivated: @escaping () -> Void,
        onDrag: @escaping (DragGesture.Value) -> Void,
        onEnded: @escaping () -> Void
    ) -> some Gesture {
        LongPressGesture(minimumDuration: holdDuration, maximumDistance: moveTolerance)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .first(true):
                    onActivated()
                case .second(true, let drag?):
                    onDrag(drag)
                default:
                    break
                }
            }
            .onEnded { _ in onEnded() }
    }

    static func resetPressState(
        pressStartedAt: inout Date?,
        isArming: inout Bool,
        armProgress: inout CGFloat
    ) {
        pressStartedAt = nil
        isArming = false
        armProgress = 0
    }

    static func endSession(
        pressStartedAt: inout Date?,
        isArming: inout Bool,
        isScrubActive: inout Bool,
        armProgress: inout CGFloat
    ) {
        pressStartedAt = nil
        isArming = false
        isScrubActive = false
        armProgress = 0
    }
}

// MARK: - Press tracking (arming visuals without claiming scroll)

private struct HoldToScrubPressTracker: ViewModifier {
    let moveTolerance: CGFloat
    let onPressChanged: (Bool) -> Void

    func body(content: Content) -> some View {
        content.onLongPressGesture(
            minimumDuration: 86_400,
            maximumDistance: moveTolerance,
            perform: {},
            onPressingChanged: onPressChanged
        )
    }
}

extension View {
    /// Tracks finger down/up for arming UI; uses a never-firing long-press so scroll is not blocked.
    func holdToScrubPressTracking(
        moveTolerance: CGFloat = HoldToScrubInteraction.defaultMoveTolerance,
        onPressChanged: @escaping (Bool) -> Void
    ) -> some View {
        modifier(HoldToScrubPressTracker(moveTolerance: moveTolerance, onPressChanged: onPressChanged))
    }
}
