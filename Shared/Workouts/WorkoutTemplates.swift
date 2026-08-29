import Foundation

/// Deterministic, data-driven step templates. The generator picks and time-boxes
/// exercises; AI may later rephrase wording but never changes the structure.
enum WorkoutTemplates {
    struct Exercise: Sendable {
        let name: String
        let detail: String
        let coachingCue: String?
        let requiredEquipment: EquipmentType?
        let stressedAreas: [SorenessArea]

        init(
            _ name: String,
            _ detail: String,
            cue: String? = nil,
            equipment: EquipmentType? = nil,
            stresses: [SorenessArea] = []
        ) {
            self.name = name
            self.detail = detail
            self.coachingCue = cue
            self.requiredEquipment = equipment
            self.stressedAreas = stresses
        }
    }

    // MARK: - Step assembly

    static func steps(
        activity: ActivityType,
        intensity: WorkoutIntensity,
        totalMinutes: Int,
        equipment: [EquipmentType],
        avoiding soreness: [SorenessArea]
    ) -> [WorkoutStep] {
        let warmupMinutes = max(2, Int((Double(totalMinutes) * 0.15).rounded()))
        let cooldownMinutes = max(2, Int((Double(totalMinutes) * 0.15).rounded()))
        let mainMinutes = max(1, totalMinutes - warmupMinutes - cooldownMinutes)
        let gentleIntensity: WorkoutIntensity = intensity.rank < WorkoutIntensity.light.rank ? intensity : .light

        let warmup = warmupStep(for: activity, minutes: warmupMinutes, intensity: gentleIntensity)
        let cooldown = cooldownStep(for: activity, minutes: cooldownMinutes, intensity: gentleIntensity)
        return [warmup]
            + mainSteps(
                activity: activity,
                intensity: intensity,
                minutes: mainMinutes,
                equipment: equipment,
                soreness: soreness
            )
            + [cooldown]
    }

    private static func warmupStep(
        for activity: ActivityType,
        minutes: Int,
        intensity: WorkoutIntensity
    ) -> WorkoutStep {
        switch activity {
        case .chairExercise:
            WorkoutStep(
                phase: .warmup,
                name: String(localized: "Seated warm-up"),
                detail: String(localized: "Sit comfortably with both feet flat. Roll your shoulders, open and close your hands, then march gently in place."),
                durationMinutes: minutes,
                intensity: intensity,
                coachingCue: String(localized: "Keep your back supported if needed and breathe smoothly.")
            )
        case .walking, .running:
            WorkoutStep(
                phase: .warmup,
                name: String(localized: "Warm-up"),
                detail: String(localized: "Start easy. Walk or jog lightly, relax your shoulders, and gradually lengthen your stride."),
                durationMinutes: minutes,
                intensity: intensity,
                coachingCue: String(localized: "You should be able to speak in full sentences.")
            )
        case .cycling:
            WorkoutStep(
                phase: .warmup,
                name: String(localized: "Warm-up"),
                detail: String(localized: "Pedal with very light resistance, sit tall, and let your cadence build gradually."),
                durationMinutes: minutes,
                intensity: intensity,
                coachingCue: String(localized: "Keep pressure even through both feet.")
            )
        case .swimming:
            WorkoutStep(
                phase: .warmup,
                name: String(localized: "Warm-up"),
                detail: String(localized: "Swim easy laps or move gently in the water while settling into a calm breathing rhythm."),
                durationMinutes: minutes,
                intensity: intensity,
                coachingCue: String(localized: "Stop and rest at the wall whenever breathing feels rushed.")
            )
        default:
            WorkoutStep(
                phase: .warmup,
                name: String(localized: "Warm-up"),
                detail: String(localized: "Move slowly through the joints you will use today, then ease into the first exercise."),
                durationMinutes: minutes,
                intensity: intensity,
                coachingCue: String(localized: "Start lighter than you think you need.")
            )
        }
    }

    private static func cooldownStep(
        for activity: ActivityType,
        minutes: Int,
        intensity: WorkoutIntensity
    ) -> WorkoutStep {
        switch activity {
        case .chairExercise:
            WorkoutStep(
                phase: .cooldown,
                name: String(localized: "Seated cool-down"),
                detail: String(localized: "Stay seated, slow the marching, stretch your hands and shoulders, then take slow breaths."),
                durationMinutes: minutes,
                intensity: intensity,
                coachingCue: String(localized: "Finish feeling calmer, not strained.")
            )
        case .walking, .running:
            WorkoutStep(
                phase: .cooldown,
                name: String(localized: "Cool-down"),
                detail: String(localized: "Slow to an easy walk, shorten your stride, and let your breathing settle."),
                durationMinutes: minutes,
                intensity: intensity,
                coachingCue: String(localized: "End at a pace that feels comfortable and controlled.")
            )
        case .cycling:
            WorkoutStep(
                phase: .cooldown,
                name: String(localized: "Cool-down"),
                detail: String(localized: "Lower resistance and pedal easily until your breathing settles."),
                durationMinutes: minutes,
                intensity: intensity,
                coachingCue: String(localized: "Keep your shoulders relaxed and avoid a sudden stop.")
            )
        case .swimming:
            WorkoutStep(
                phase: .cooldown,
                name: String(localized: "Cool-down"),
                detail: String(localized: "Swim very easy or walk in the water, then pause at the wall for slow breaths."),
                durationMinutes: minutes,
                intensity: intensity,
                coachingCue: String(localized: "Stay relaxed and leave the pool without rushing.")
            )
        default:
            WorkoutStep(
                phase: .cooldown,
                name: String(localized: "Cool-down"),
                detail: String(localized: "Slow the movement, loosen the areas you trained, and breathe deeply."),
                durationMinutes: minutes,
                intensity: intensity,
                coachingCue: String(localized: "Finish with effort dropping, not rising.")
            )
        }
    }

    private static func mainSteps(
        activity: ActivityType,
        intensity: WorkoutIntensity,
        minutes: Int,
        equipment: [EquipmentType],
        soreness: [SorenessArea]
    ) -> [WorkoutStep] {
        switch activity {
        case .walking, .running, .cycling, .swimming:
            return [cardioMainStep(activity: activity, intensity: intensity, minutes: minutes)]
        case .strength, .core, .mobility, .balance, .stretching, .chairExercise, .recovery:
            return circuitSteps(
                from: pool(for: activity),
                intensity: intensity,
                minutes: minutes,
                equipment: equipment,
                soreness: soreness
            )
        }
    }

    private static func cardioMainStep(
        activity: ActivityType,
        intensity: WorkoutIntensity,
        minutes: Int
    ) -> WorkoutStep {
        let name: String
        let detail: String
        let cue: String
        switch intensity {
        case .recovery, .light:
            name = String(localized: "Steady, comfortable pace")
            detail = String(localized: "Move continuously at an easy pace. Keep your breathing calm and your effort comfortable from start to finish.")
            cue = String(localized: "If you cannot speak comfortably, slow down.")
        case .moderate:
            name = String(localized: "Brisk pace")
            detail = String(localized: "Build to a brisk pace where talking takes effort, then hold that steady rhythm.")
            cue = String(localized: "Keep the effort challenging but controlled.")
        case .hard:
            name = String(localized: "Brisk intervals")
            detail = String(localized: "Alternate 3 minutes brisk with 2 minutes easy. Repeat until the step time is complete.")
            cue = String(localized: "Only push hard if your form and breathing stay controlled.")
        }
        return WorkoutStep(
            phase: .main,
            name: name,
            detail: detail,
            durationMinutes: minutes,
            intensity: intensity,
            coachingCue: cue
        )
    }

    /// Splits the main block evenly across the first exercises that fit the
    /// user's equipment and avoid sore areas. Selection order is fixed, so the
    /// same inputs always produce the same workout.
    private static func circuitSteps(
        from pool: [Exercise],
        intensity: WorkoutIntensity,
        minutes: Int,
        equipment: [EquipmentType],
        soreness: [SorenessArea]
    ) -> [WorkoutStep] {
        let available = effectiveEquipment(equipment)
        let fits = pool.filter { exercise in
            let equipmentOK = exercise.requiredEquipment.map(available.contains) ?? true
            let sorenessOK = Set(exercise.stressedAreas).isDisjoint(with: soreness)
            return equipmentOK && sorenessOK
        }
        guard !fits.isEmpty else {
            return [
                WorkoutStep(
                    phase: .main,
                    name: String(localized: "Gentle movement"),
                    detail: String(localized: "Move comfortably in any way that feels good and avoids sore areas. Keep the motion small and steady."),
                    durationMinutes: minutes,
                    intensity: intensity,
                    coachingCue: String(localized: "Stay pain-free and stop if discomfort changes your form.")
                )
            ]
        }

        let targetCount = min(max(minutes / 4, 3), 6)
        let selected = Array(fits.prefix(targetCount))
        let base = max(1, minutes / selected.count)
        let remainder = max(0, minutes - base * selected.count)

        return selected.enumerated().map { index, exercise in
            WorkoutStep(
                phase: .main,
                name: exercise.name,
                detail: exercise.detail,
                durationMinutes: base + (index < remainder ? 1 : 0),
                intensity: intensity,
                coachingCue: exercise.coachingCue,
                requiredEquipment: exercise.requiredEquipment,
                stressedAreas: exercise.stressedAreas
            )
        }
    }

    /// Home and full gyms include bands and dumbbells.
    private static func effectiveEquipment(_ equipment: [EquipmentType]) -> Set<EquipmentType> {
        var available = Set(equipment)
        if available.contains(.homeGym) || available.contains(.fullGym) {
            available.formUnion([.resistanceBands, .dumbbells])
        }
        return available
    }

    // MARK: - Exercise pools

    private static func pool(for activity: ActivityType) -> [Exercise] {
        switch activity {
        case .strength: strengthPool
        case .core: corePool
        case .mobility: mobilityPool
        case .balance: balancePool
        case .stretching: stretchingPool
        case .chairExercise: chairPool
        case .recovery: recoveryPool
        default: []
        }
    }

    private static var strengthPool: [Exercise] {
        [
            Exercise(
                String(localized: "Sit-to-stand squats"),
                String(localized: "Sit near the front of a sturdy chair. Stand up, pause tall, then sit back down slowly with control."),
                cue: String(localized: "Keep knees tracking over toes and use your hands only if needed."),
                stresses: [.legs, .knee]
            ),
            Exercise(
                String(localized: "Wall push-ups"),
                String(localized: "Place your hands on the wall at shoulder height. Lower your chest toward the wall, then press back."),
                cue: String(localized: "Keep your body in one straight line."),
                stresses: [.shoulder]
            ),
            Exercise(
                String(localized: "Glute bridges"),
                String(localized: "Lie on your back with knees bent. Lift your hips, squeeze your glutes briefly, then lower slowly."),
                cue: String(localized: "Stop before your lower back takes over."),
                stresses: [.back]
            ),
            Exercise(
                String(localized: "Standing calf raises"),
                String(localized: "Stand tall near support. Rise onto your toes, hold briefly, then lower with control."),
                cue: String(localized: "Use the support for balance, not to pull yourself up."),
                stresses: [.legs]
            ),
            Exercise(
                String(localized: "Band rows"),
                String(localized: "Anchor the band securely. Pull the handles toward your ribs, squeeze your shoulder blades, then release slowly."),
                cue: String(localized: "Keep wrists straight and shoulders away from your ears."),
                equipment: .resistanceBands,
                stresses: [.back, .shoulder]
            ),
            Exercise(
                String(localized: "Goblet squats"),
                String(localized: "Hold one dumbbell at your chest. Sit your hips back, squat to a comfortable depth, then stand tall."),
                cue: String(localized: "Keep your chest lifted and stay within a pain-free range."),
                equipment: .dumbbells,
                stresses: [.legs, .knee]
            ),
            Exercise(
                String(localized: "Dumbbell curls"),
                String(localized: "Stand or sit tall. Curl the weights toward your shoulders, pause briefly, then lower with control."),
                cue: String(localized: "Keep elbows close to your sides."),
                equipment: .dumbbells
            ),
        ]
    }

    private static var corePool: [Exercise] {
        [
            Exercise(
                String(localized: "Dead bug"),
                String(localized: "Lie on your back with knees bent. Extend the opposite arm and leg, return to center, then switch sides."),
                cue: String(localized: "Keep your lower back gently pressed down.")
            ),
            Exercise(
                String(localized: "Bird dog"),
                String(localized: "Start on hands and knees. Extend the opposite arm and leg, hold briefly, return, then switch sides."),
                cue: String(localized: "Keep hips level and move slowly."),
                stresses: [.back]
            ),
            Exercise(
                String(localized: "Seated knee lifts"),
                String(localized: "Sit tall with feet flat. Lift one knee, pause briefly, lower it, then switch sides."),
                cue: String(localized: "Brace gently as if zipping up through your lower belly.")
            ),
            Exercise(
                String(localized: "Plank hold"),
                String(localized: "Hold a straight line from head to heels. Rest, reset, and continue whenever form slips."),
                cue: String(localized: "Choose knees down if a full plank strains your back."),
                stresses: [.back, .shoulder]
            ),
        ]
    }

    private static var mobilityPool: [Exercise] {
        [
            Exercise(
                String(localized: "Cat-cow"),
                String(localized: "Start on hands and knees. Round your back slowly, then gently arch and lift your chest."),
                cue: String(localized: "Move with your breath and stay out of sharp pain."),
                stresses: [.back]
            ),
            Exercise(
                String(localized: "Hip circles"),
                String(localized: "Stand tall with soft knees. Circle your hips slowly in one direction, then switch directions."),
                cue: String(localized: "Keep the circles small if your back feels tight.")
            ),
            Exercise(
                String(localized: "Shoulder rolls"),
                String(localized: "Roll your shoulders up, back, and down in slow circles, then repeat forward."),
                cue: String(localized: "Keep your neck long and jaw relaxed.")
            ),
            Exercise(
                String(localized: "Ankle circles"),
                String(localized: "Lift one foot lightly and circle the ankle both ways, then switch to the other side."),
                cue: String(localized: "Hold support if balance feels uncertain.")
            ),
        ]
    }

    private static var balancePool: [Exercise] {
        [
            Exercise(
                String(localized: "Single-leg stand"),
                String(localized: "Stand near support. Lift one foot slightly, hold steady, lower it, then switch sides."),
                cue: String(localized: "Use fingertip support before balance becomes shaky."),
                stresses: [.legs]
            ),
            Exercise(
                String(localized: "Heel-to-toe walk"),
                String(localized: "Walk a straight line, placing one heel directly in front of the other toes each step."),
                cue: String(localized: "Look forward and slow down before you lose control.")
            ),
            Exercise(
                String(localized: "Side leg raises"),
                String(localized: "Hold support and lift one leg sideways, pause briefly, lower with control, then switch."),
                cue: String(localized: "Keep toes facing forward and torso upright."),
                stresses: [.legs]
            ),
        ]
    }

    private static var stretchingPool: [Exercise] {
        [
            Exercise(
                String(localized: "Hamstring stretch"),
                String(localized: "Place one heel forward, hinge gently at the hips, and hold a light stretch behind the thigh."),
                cue: String(localized: "Keep the stretch mild and avoid bouncing."),
                stresses: [.legs]
            ),
            Exercise(
                String(localized: "Chest doorway stretch"),
                String(localized: "Place your forearm on a doorframe, step through gently, and hold the chest stretch."),
                cue: String(localized: "Back off if you feel pinching in the shoulder."),
                stresses: [.shoulder]
            ),
            Exercise(
                String(localized: "Child's pose"),
                String(localized: "Kneel and reach your arms forward, letting your back lengthen and your breathing slow."),
                cue: String(localized: "Use a pillow or skip this if knees are uncomfortable.")
            ),
            Exercise(
                String(localized: "Neck stretch"),
                String(localized: "Sit or stand tall. Tilt one ear toward the shoulder, hold gently, then switch sides."),
                cue: String(localized: "Keep the stretch light and never pull on your head.")
            ),
        ]
    }

    private static var chairPool: [Exercise] {
        [
            Exercise(
                String(localized: "Seated marches"),
                String(localized: "Sit tall with both feet flat. Lift one knee a few inches, lower it, then switch sides at a steady rhythm."),
                cue: String(localized: "Keep your torso upright and slow down if your hips rock.")
            ),
            Exercise(
                String(localized: "Seated arm circles"),
                String(localized: "Extend your arms to the sides at shoulder height or lower. Circle forward, then switch backward halfway."),
                cue: String(localized: "Use smaller circles if your shoulders feel tense.")
            ),
            Exercise(
                String(localized: "Seated leg extensions"),
                String(localized: "Sit near the front of the chair. Straighten one knee, pause briefly, lower slowly, then switch."),
                cue: String(localized: "Move pain-free and avoid locking the knee hard."),
                stresses: [.knee]
            ),
            Exercise(
                String(localized: "Seated twists"),
                String(localized: "Sit tall and cross your arms over your chest. Rotate gently to one side, return to center, then switch."),
                cue: String(localized: "Rotate from the upper back without forcing your lower back."),
                stresses: [.back]
            ),
            Exercise(
                String(localized: "Seated heel raises"),
                String(localized: "Keep toes on the floor. Lift both heels, pause briefly, then lower slowly."),
                cue: String(localized: "Press evenly through the balls of both feet.")
            ),
            Exercise(
                String(localized: "Seated overhead reach"),
                String(localized: "Reach one arm overhead, lower it with control, then switch sides."),
                cue: String(localized: "Keep ribs relaxed and stop before shoulder discomfort.")
            ),
        ]
    }

    private static var recoveryPool: [Exercise] {
        [
            Exercise(
                String(localized: "Gentle walk"),
                String(localized: "Stroll at a completely comfortable pace with relaxed arms and easy breathing."),
                cue: String(localized: "This should feel restorative, not like a test.")
            ),
            Exercise(
                String(localized: "Deep breathing"),
                String(localized: "Inhale for four counts, exhale for six, and let your shoulders drop each time."),
                cue: String(localized: "If counting creates tension, simply breathe slowly.")
            ),
            Exercise(
                String(localized: "Light full-body stretch"),
                String(localized: "Move through easy stretches for the neck, shoulders, hips, and calves, holding wherever feels tight."),
                cue: String(localized: "Stay in a gentle stretch; avoid pushing for range.")
            ),
        ]
    }
}
