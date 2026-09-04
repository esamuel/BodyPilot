import Foundation
import Testing
@testable import BodyPilot

struct HeartRateZoneEngineTests {
    @Test func karvonenThresholdsMatchReferenceValues() {
        // Max 141, resting 47 → reserve 94.
        let profile = HeartRateZoneEngine.profile(maximumHeartRate: 141, restingHeartRate: 47)

        #expect(profile.zones.map(\.lowerBoundBPM) == [89, 103, 112, 122, 131])
        #expect(profile.zones.last?.upperBoundBPM == 141)
        #expect(profile.easyUpperBoundBPM == 89)
    }

    @Test func zonesAreContiguousAndAscending() {
        let profile = HeartRateZoneEngine.profile(maximumHeartRate: 190, restingHeartRate: 55)

        for (zone, next) in zip(profile.zones, profile.zones.dropFirst()) {
            #expect(zone.upperBoundBPM == next.lowerBoundBPM)
            #expect(zone.lowerBoundBPM < zone.upperBoundBPM)
        }
    }

    @Test func maximumHeartRateUsesTanakaFormula() {
        #expect(HeartRateZoneEngine.estimatedMaximumHeartRate(age: 40) == 180)
        #expect(HeartRateZoneEngine.estimatedMaximumHeartRate(age: 79) == 153)
    }

    @Test func missingAgeFallsBackToDefault() {
        let withFallback = HeartRateZoneEngine.estimatedMaximumHeartRate(age: nil)
        let withDefaultAge = HeartRateZoneEngine.estimatedMaximumHeartRate(age: HeartRateZoneEngine.fallbackAge)

        #expect(withFallback == withDefaultAge)
    }

    @Test func extremeAgesAreClamped() {
        #expect(HeartRateZoneEngine.estimatedMaximumHeartRate(age: 3) == HeartRateZoneEngine.estimatedMaximumHeartRate(age: 10))
        #expect(HeartRateZoneEngine.estimatedMaximumHeartRate(age: 130) == HeartRateZoneEngine.estimatedMaximumHeartRate(age: 100))
    }

    @Test func degenerateRestingHeartRateIsClamped() {
        // Resting above max would produce a negative reserve without clamping.
        let profile = HeartRateZoneEngine.profile(maximumHeartRate: 150, restingHeartRate: 170)

        #expect(profile.restingHeartRate == 130)
        for (zone, next) in zip(profile.zones, profile.zones.dropFirst()) {
            #expect(zone.lowerBoundBPM <= next.lowerBoundBPM)
        }
        #expect(profile.zones.last?.upperBoundBPM == 150)
    }
}
