import Foundation
import Testing
@testable import BodyPilot

struct FallbackCoachTests {
    private let coach = FallbackCoach()

    private func request(_ message: String, bodyScore: Int = 62) -> CoachRequest {
        CoachRequest(
            message: message,
            context: AIContext(
                bodyScore: bodyScore, confidence: 0.8, sleepDelta: -0.12, hrvDelta: -0.06,
                restingHRDeltaBPM: 3, recentLoad: .moderate, feeling: .normal,
                goal: .generalFitness, equipment: [.none]
            ),
            constraints: [.maxDuration(minutes: 30)],
            profile: .dailyCoach
        )
    }

    @Test("Score questions get an explanation citing the deltas")
    func scoreExplanation() async throws {
        let response = try await coach.respond(to: request("Why is my score lower today?"))
        #expect(response.source == .fallback)
        #expect(response.text.contains("62"))
        #expect(response.text.contains("-12%"))
    }

    @Test("Time questions cite the duration constraint")
    func timeAdvice() async throws {
        let response = try await coach.respond(to: request("I only have a few minutes today"))
        #expect(response.text.contains("30"))
    }

    @Test("Asking for easier gets gentle guidance")
    func easierAdvice() async throws {
        let response = try await coach.respond(to: request("make today easier please"))
        #expect(response.text.lowercased().contains("gentle") || response.text.lowercased().contains("easy"))
    }

    @Test("Any other message gets a readiness summary and is never empty")
    func defaultSummary() async throws {
        let response = try await coach.respond(to: request("hello there"))
        #expect(!response.text.isEmpty)
        #expect(response.text.contains("62"))
    }

    @Test("Responses are deterministic for identical requests")
    func deterministic() async throws {
        let first = try await coach.respond(to: request("why"))
        let second = try await coach.respond(to: request("why"))
        #expect(first.text == second.text)
    }

    @Test("Coach service preserves primary AI failure reason on fallback")
    func servicePreservesPrimaryFailureReason() async {
        struct FailingPrimary: CoachProviding {
            func respond(to request: CoachRequest) async throws -> CoachResponse {
                throw Failure.reason
            }

            enum Failure: LocalizedError {
                case reason

                var errorDescription: String? {
                    "Apple Intelligence is turned off in Settings."
                }
            }
        }

        let service = CoachService(primary: FailingPrimary(), fallback: coach)
        let response = await service.respond(to: request("why"))
        #expect(response.source == .fallback)
        #expect(response.fallbackReason == "Apple Intelligence is turned off in Settings.")
    }
}
