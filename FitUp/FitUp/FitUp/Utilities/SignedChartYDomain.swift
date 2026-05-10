//
//  SignedChartYDomain.swift
//  FitUp
//
//  Shared Y-axis bounds for signed charts (battle margins, cumulative net).
//

import Foundation

enum SignedChartYDomain {
    /// Builds asymmetric domains around real data so one-sided series does not waste half the chart on empty polarity,
    /// while reserving ~`reserveOppositeFraction` of final span on the empty side of zero (visual hint).
    static func domain(
        dataMin: Int,
        dataMax: Int,
        padFraction: Double = 0.10,
        reserveOppositeFraction: Double = 0.25,
        minimumCoreSpan: Int = 400,
        padFloor: Int = 50
    ) -> ClosedRange<Int> {
        let mn = min(dataMin, dataMax)
        let mx = max(dataMin, dataMax)

        let coreSpan = max(mx - mn, minimumCoreSpan)
        let pad = max(Int(Double(coreSpan) * padFraction), padFloor)

        let hasNegative = mn < 0
        let hasPositive = mx > 0
        let allZeroLike = mn == 0 && mx == 0

        if allZeroLike {
            let reserve = max(Int(Double(minimumCoreSpan) * reserveOppositeFraction), padFloor)
            return (-reserve)...(max(reserve, pad))
        }

        if !hasNegative && hasPositive {
            let high = mx + pad
            let spanAboveZero = max(high, minimumCoreSpan / 2)
            let reserveBelow = max(Int(Double(spanAboveZero) * reserveOppositeFraction), padFloor)
            return (-reserveBelow)...high
        }

        if hasNegative && !hasPositive {
            let low = mn - pad
            let spanBelowZero = max(abs(low), minimumCoreSpan / 2)
            let reserveAbove = max(Int(Double(spanBelowZero) * reserveOppositeFraction), padFloor)
            return low...reserveAbove
        }

        var low = mn - pad
        var high = mx + pad
        if low > 0 { low = 0 }
        if high < 0 { high = 0 }
        return low...high
    }

    /// Tick positions spanning `domain` (five steps inclusive).
    static func axisTickValues(for domain: ClosedRange<Int>) -> [Int] {
        let lo = domain.lowerBound
        let hi = domain.upperBound
        let span = hi - lo
        guard span > 0 else { return [lo] }
        let steps = 4
        return (0...steps).map { i in lo + (span * i) / steps }
    }
}
