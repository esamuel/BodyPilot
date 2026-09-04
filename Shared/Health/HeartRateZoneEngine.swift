import Foundation

/// One training zone bounded by heart-rate reserve thresholds.
struct HeartRateZone: Hashable, Sendable {
    /// 1...5, matching common training-zone terminology.
    let index: Int
    let lowerBoundBPM: Int
    let upperBoundBPM: Int
    /// Fraction of heart-rate reserve at the zone's lower bound, e.g. 0.45.
    let lowerBoundFraction: Double
}

/// The full deterministic zone table for one person.
struct HeartRateZoneProfile: Hashable, Sendable {
    let maximumHeartRate: Int
    let restingHeartRate: Int
    let zones: [HeartRateZone]

    /// Anything below zone 1 counts as easy effort ("zone 0").
    var easyUpperBoundBPM: Int {
        zones.first?.lowerBoundBPM ?? restingHeartRate
    }
}

/// Deterministic heart-rate zone calculator.
///
/// Zones use the Karvonen (heart-rate reserve) method:
/// `threshold = resting + fraction × (max − resting)`, rounded down.
/// Max heart rate is estimated with the Tanaka formula (208 − 0.7 × age),
/// which stays accurate for older adults where 220 − age drifts high.
enum HeartRateZoneEngine {
    /// Lower bounds of zones 1–5 as fractions of heart-rate reserve.
    static let zoneFractions: [Double] = [0.45, 0.60, 0.70, 0.80, 0.90]

    /// Used until Apple Health provides a personal resting heart rate.
    static let fallbackRestingHeartRate = 60

    /// Used when the user hasn't shared a birth date.
    static let fallbackAge = 40

    static func estimatedMaximumHeartRate(age: Int?) -> Int {
        let clampedAge = min(max(age ?? fallbackAge, 10), 100)
        return Int((208.0 - 0.7 * Double(clampedAge)).rounded())
    }

    static func profile(maximumHeartRate: Int, restingHeartRate: Int) -> HeartRateZoneProfile {
        // Guard degenerate inputs so the reserve stays positive.
        let maxHR = max(maximumHeartRate, 100)
        let restHR = min(max(restingHeartRate, 30), maxHR - 20)
        let reserve = Double(maxHR - restHR)

        let lowerBounds = zoneFractions.map { fraction in
            restHR + Int((reserve * fraction).rounded(.down))
        }
        let zones = lowerBounds.enumerated().map { offset, lower in
            HeartRateZone(
                index: offset + 1,
                lowerBoundBPM: lower,
                upperBoundBPM: offset + 1 < lowerBounds.count ? lowerBounds[offset + 1] : maxHR,
                lowerBoundFraction: zoneFractions[offset]
            )
        }
        return HeartRateZoneProfile(
            maximumHeartRate: maxHR,
            restingHeartRate: restHR,
            zones: zones
        )
    }
}
