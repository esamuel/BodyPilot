import Foundation
import Testing
@testable import BodyPilot

@MainActor
struct CoachWorkoutOfferTests {
    private func makeModel() -> CoachModel {
        CoachModel(
            healthMetrics: MockHealthProvider(),
            coachService: CoachService(primary: nil)
        )
    }

    @Test("Training-intent detection is deterministic")
    func intentDetection() {
        #expect(CoachModel.wantsWorkout("Give me a home workout"))
        #expect(CoachModel.wantsWorkout("I only have 15 minutes"))
        #expect(CoachModel.wantsWorkout("Make today easier"))
        #expect(CoachModel.wantsWorkout("Create a detailed training plan"))
        #expect(CoachModel.wantsWorkout("תיצור לי אימון של 20 דקות"))
        #expect(!CoachModel.wantsWorkout("Why is my score lower today?"))
        #expect(!CoachModel.wantsWorkout("What improved this month?"))
    }

    @Test("Requested minutes parse from the message and ignore implausible numbers")
    func minutesParsing() {
        #expect(CoachModel.requestedMinutes(in: "I only have 15 minutes") == 15)
        #expect(CoachModel.requestedMinutes(in: "a 20-minute session please") == 20)
        #expect(CoachModel.requestedMinutes(in: "give me a workout") == nil)
        #expect(CoachModel.requestedMinutes(in: "I ran 3 km in 2024") == nil)
    }

    @Test("A workout question attaches a validated offer within the requested time")
    func offerAttachedWithinTime() async {
        let model = makeModel()
        await model.send("Give me a 15 minute workout", profile: nil, checkIn: nil)
        let reply = model.messages.last
        #expect(reply?.isUser == false)
        let workout = try? #require(reply?.workout)
        if let workout {
            #expect(workout.totalMinutes <= 15)
            #expect(!workout.steps.isEmpty)
        }
        #expect(reply?.text.contains("step-by-step") == true)
    }

    @Test("Non-training questions get no workout offer")
    func noOfferForScoreQuestion() async {
        let model = makeModel()
        await model.send("Why is my score lower today?", profile: nil, checkIn: nil)
        #expect(model.messages.last?.workout == nil)
    }
}
