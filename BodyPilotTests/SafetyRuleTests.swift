import Foundation
import Testing
@testable import BodyPilot

struct SafetyRuleTests {
    private let gate = SafetyGate()

    @Test("Every red-flag phrase triggers the safety response")
    func allRedFlagsTrigger() {
        for phrase in SafetyGate.redFlagPhrases {
            let response = gate.safetyResponse(for: "I have \(phrase) right now")
            #expect(response != nil, "expected '\(phrase)' to trigger the gate")
            #expect(response?.source == .safety)
        }
    }

    @Test("Matching is case-insensitive")
    func caseInsensitive() {
        #expect(gate.safetyResponse(for: "CHEST PAIN during my walk") != nil)
        #expect(gate.safetyResponse(for: "I feel Dizzy today") != nil)
    }

    @Test("Benign fitness questions pass through")
    func benignMessagesPass() {
        let benign = [
            "Why is my score low today?",
            "I only have 15 minutes",
            "My legs are tired from yesterday",
            "Give me a home workout",
        ]
        for message in benign {
            #expect(gate.safetyResponse(for: message) == nil, "'\(message)' should not trigger the gate")
        }
    }

    @Test("The safety response never contains workout advice")
    func safetyResponseIsConservative() throws {
        let response = try #require(gate.safetyResponse(for: "I have chest pain"))
        let lowered = response.text.lowercased()
        #expect(!lowered.contains("workout suggestion"))
        #expect(lowered.contains("stop"))
        #expect(lowered.contains("medical") || lowered.contains("doctor") || lowered.contains("emergency"))
    }

    @Test("The gate runs before any provider inside CoachService")
    func gateRunsFirstInService() async {
        // A primary provider that would happily answer anything.
        struct EagerCoach: CoachProviding {
            func respond(to request: CoachRequest) async throws -> CoachResponse {
                CoachResponse(text: "Go train hard!", source: .onDeviceAI)
            }
        }
        let service = CoachService(primary: EagerCoach())
        let context = AIContext(
            bodyScore: 90, confidence: 1, sleepDelta: nil, hrvDelta: nil,
            restingHRDeltaBPM: nil, recentLoad: .rest, feeling: .good,
            goal: .generalFitness, equipment: [.none]
        )
        let response = await service.respond(
            to: CoachRequest(message: "chest pain but should I run?", context: context, constraints: [], profile: .dailyCoach)
        )
        #expect(response.source == .safety)
    }
}
