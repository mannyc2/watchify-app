//
//  PriceThreshold.swift
//  watchify
//

import Foundation

enum PriceThreshold: String, CaseIterable, Codable {
    case any = "Any amount"
    case dollars5 = "At least $5"
    case dollars10 = "At least $10"
    case dollars25 = "At least $25"
    case percent10 = "At least 10%"
    case percent25 = "At least 25%"

    var minDollars: Decimal? {
        switch self {
        case .dollars5: return 5
        case .dollars10: return 10
        case .dollars25: return 25
        default: return nil
        }
    }

    var minPercent: Int? {
        switch self {
        case .percent10: return 10
        case .percent25: return 25
        default: return nil
        }
    }

    /// Check if a change event meets this threshold
    func isSatisfied(by change: ChangeEventDTO) -> Bool {
        // Non-price changes always pass
        guard change.changeType == .priceDropped || change.changeType == .priceIncreased else {
            return true
        }

        switch self {
        case .any:
            return true

        case .dollars5, .dollars10, .dollars25:
            guard let minDollars, let priceChange = change.priceChange else {
                return true
            }
            return abs(priceChange) >= minDollars

        case .percent10, .percent25:
            guard let minPercent else { return true }
            // Use magnitude as proxy for percentage
            switch change.magnitude {
            case .small:
                // small = <10%, only passes if threshold is less than 10%
                return false
            case .medium:
                // medium = 10-25%, passes for 10% threshold but not 25%
                return minPercent <= 10
            case .large:
                // large = >25%, always passes
                return true
            }
        }
    }
}
