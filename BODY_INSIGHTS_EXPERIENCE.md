# BodyPilot AI — Body Insights Experience

Version: 1.0
Date: 2026-08-25
Status: Product differentiation layer for V1/V1.1

---

## 1. Why This Exists

BodyPilot must feel more useful and more memorable than a generic fitness dashboard.

The main Today screen should stay simple, but every important health/fitness dimension gets a dedicated, highly visual detail page. Each page explains one part of the user's body in plain language, shows how today compares with the user's own baseline, and ends with a useful action.

The system is called **Body Insights**.

Core idea:

> One body. Many signals. One clear story.

Body Insights should make the user want to open individual pages even when they are not starting a workout.

---

## 2. Product Differentiator: Living Metric Worlds

Each major metric has its own visual identity while staying inside the BodyPilot brand.

Every page has:
- a distinctive light illustration or motion motif
- its own accent color
- one primary metric
- personal-baseline status
- supporting metrics
- trend visualization
- a short AI explanation
- one recommended action
- a link to the relevant workout/recovery behavior

The pages must feel related, but not repetitive.

The illustration style must be original to BodyPilot. Do not copy another application's mascots, layouts, wording, or visual assets.

---

## 3. Body Insights Hub

Add a section to the Today screen below the daily recommendation:

**Explore your body**

Cards:
- Sleep
- Steps & Movement
- Recovery
- Heart
- Training Load
- Strength
- Mobility & Balance
- Workout History

Each card shows:
- small themed illustration
- current status
- one headline number
- tiny trend indicator

Example:

    Sleep
    Excellent
    7h 42m
    +28m vs your 28-day average

Tapping opens the dedicated detail page.

---

## 4. Shared Detail-Page Template

Every Body Insight page follows the same information hierarchy.

### Section A — Hero

Large, calm, light graphic with the current status embedded into the visual world.

Example:

    Sleep
    Restorative night
    7h 42m

The hero should use subtle animation when Reduce Motion is off.

### Section B — What it means

Two or three sentences maximum.

Example:

> You slept 28 minutes longer than your recent average and your overnight heart-rate pattern was close to normal. Your recovery signals support a normal training day.

### Section C — Key numbers

Three to five focused metrics, not a wall of data.

### Section D — Your normal

Show comparison to personal baseline:
- typical range
- today
- 7-day direction
- 28-day direction

### Section E — Pattern

Simple chart or timeline showing the useful pattern.

### Section F — Coach insight

AI-generated explanation constrained by deterministic facts.

### Section G — Action

One strong CTA:
- Start recommended workout
- Take an easy walk
- Add 10 minutes of movement
- Begin wind-down
- Do mobility session
- Choose recovery

---

## 5. Sleep World

### Visual identity
- deep indigo / violet night gradient
- moon, soft stars, horizon glow
- flowing sleep-stage ribbon
- minimal animation

### Primary information
- sleep duration
- sleep quality score/status
- restorative sleep
- bedtime/wake time consistency
- sleep stages when available
- overnight HR / HRV context

### Personal-baseline language
Avoid generic claims such as “8 hours is always ideal.”

Prefer:
> 7h 34m is within your usual healthy range.

### Unique features
- 7-night consistency strip
- bedtime regularity
- recovery contribution
- “What helped?” optional user note

### Main CTA
- “Plan tonight”

This can create a simple wind-down target without becoming a sleep-medical app.

---

## 6. Steps & Movement World

### Visual identity
- warm sunrise/orange/yellow
- pathway with small footprints or route dots
- gentle landscape progression

### Primary information
- steps today
- walking/running distance
- active minutes
- flights climbed when available
- walking HR where useful
- hourly movement distribution

### Important design principle
Do not turn the step count into a guilt target.

Use personal consistency:
> You are 1,400 steps below your usual Tuesday by this time. A 12-minute walk would bring you close to your normal pattern.

### Main CTA
- “Take a 12-minute walk”

This CTA should update dynamically.

---

## 7. Recovery World

### Visual identity
- aqua/green flowing bands
- calm breathing-like motion
- circular recovery field

### Primary information
- Body Score contribution
- HRV vs baseline
- resting HR vs baseline
- sleep contribution
- recent training load
- subjective feeling

### Core status language
- Strong
- Ready
- Easy
- Recover

### Main CTA
Depending on readiness:
- Start workout
- Choose easy session
- Recovery session

### Explainability
This is the most important explainable page in the app.

Always show:
- what increased readiness
- what reduced readiness
- confidence level

---

## 8. Heart World

### Visual identity
- warm coral/red accents used carefully
- pulsing line / soft heart contour
- no alarming medical appearance

### Primary information
- resting heart rate
- workout heart rate trends
- HRV link to recovery
- zone distribution
- personal-baseline range

### Safety
The page is fitness-oriented, not diagnostic.

Never label disease or arrhythmia.

If Apple Health provides a medical notification, BodyPilot may surface the existence of the Health alert and direct the user to Apple Health or appropriate care; it must not reinterpret it as a diagnosis.

### Main CTA
- “See today’s intensity”

---

## 9. Training Load World

### Visual identity
- blue/teal rolling landscape or wave
- current load represented as position inside a personal range

### Primary information
- recent workload
- 7-day load
- 28-day baseline
- recovery balance
- intensity distribution
- consecutive hard/easy days

### Differentiator
Do not show a mysterious graph without explanation.

Every load visualization must answer:
- Where am I now?
- What changed it?
- What should I do next?

### Main CTA
- Start recommended session

---

## 10. Strength World

### Visual identity
- clean electric-blue blocks / controlled geometric motion

### Primary information
- strength sessions this week/month
- total training minutes
- movement categories trained
- consistency
- perceived exertion
- progression notes

### V1 philosophy
Do not require detailed bodybuilding set/rep logging to create value.

Start with session-level strength intelligence.

### Main CTA
- “Build today’s strength session”

---

## 11. Mobility & Balance World

### Visual identity
- turquoise/green arcs
- body silhouette or balance line
- calm movement illustrations

### Primary information
- mobility sessions
- balance sessions
- consistency
- soreness/limitations check-in
- recommended short routine

### Main CTA
- “5-minute mobility reset”

This world is especially important for healthy-aging users.

---

## 12. Workout History World

### Visual identity
- BodyPilot route motif from the approved logo
- timeline/path with milestones

### Primary information
- workouts
- activity mix
- minutes
- intensity
- best consistency period
- program progress

### Differentiator: The Journey Path

Instead of only a chronological list, provide a visual journey path.

Each workout appears as a small node on a route.

The route can highlight:
- recovery day
- walking day
- strength day
- milestone
- program week completion

Tapping a node opens the workout summary.

---

## 13. Daily Story

Add an optional vertically scrollable **Daily Story** accessible from Today.

It combines the user's most meaningful signals into 4–6 cards:

1. How you are today
2. What changed overnight
3. Movement so far
4. Recommended workout
5. One useful insight
6. Evening suggestion

This is not a social-story clone. It is a concise daily narrative.

The Daily Story should be generated from deterministic data and can use the AI only for wording.

---

## 14. Weekly Body Review

Every seven days, generate a visual review.

Sections:
- Your week in one sentence
- Recovery pattern
- Sleep pattern
- Movement pattern
- Training consistency
- Best day
- One area to improve
- Suggested focus for next week

CTA:
- “Build next week”

This feature is a strong Pro retention feature.

---

## 15. Widgets & Complications

Body Insights should extend outside the app.

### iPhone widgets
- Body Score
- Sleep status
- Steps vs personal pattern
- Recommended workout
- Recovery status
- Weekly progress

### Apple Watch complications / widgets
- Body Score ring/mark
- Recovery label
- Next workout
- Steps vs usual
- Sleep duration

Rules:
- glanceable
- minimal text
- no sensitive detail on Lock Screen unless appropriate
- no guilt language

---

## 16. Visual System

BodyPilot's approved master brand remains:
- Pilot Blue #0A6BFF
- Deep Blue #0047D1
- Route Teal #00E0B8
- Sky Mist #E8F2FF
- Graphite #111827
- Cool Gray #6B7280
- Light Gray #F3F4F6
- White #FFFFFF

Insight worlds can add controlled secondary accents:
- Sleep Violet
- Movement Amber
- Recovery Green
- Heart Coral

These must be centralized as semantic colors in Assets.xcassets.

The same brand logo must remain unchanged.

---

## 17. Light Illustration System

Create a reusable SwiftUI illustration layer called `BodyPilotIllustrations`.

Use:
- SwiftUI Shape
- Canvas where justified
- gradients
- SF Symbols where appropriate
- subtle particle/path accents
- vector assets for more detailed branded scenes

Avoid:
- heavy 3D rendering
- photo-realistic health organs
- copied mascots
- stock-illustration look

Illustrations should remain lightweight and battery-conscious.

Suggested scenes:
- `SleepNightScene`
- `MovementPathScene`
- `RecoveryWaveScene`
- `HeartPulseScene`
- `TrainingLoadLandscapeScene`
- `StrengthBlocksScene`
- `MobilityArcScene`
- `JourneyRouteScene`

Each scene needs static and reduced-motion variants.

---

## 18. Insight Navigation

Keep the five main tabs unchanged:

Today | Coach | Workout | Progress | Me

Do not add eight new tabs.

Insight pages are reached from:
- Today cards
- Progress
- Coach deep links
- widgets/complications
- search/App Intents where appropriate

---

## 19. AI Behavior

AI never invents a metric.

The AI receives an `InsightContext` built locally:

    struct InsightContext: Sendable {
        let kind: InsightKind
        let status: InsightStatus
        let facts: [InsightFact]
        let baselineComparisons: [BaselineComparison]
        let safeActions: [SuggestedAction]
        let confidence: Double
    }

AI output may provide:
- plain-language explanation
- short summary
- encouraging tone
- answer to “why?”

AI output may not:
- change numeric values
- override safety rules
- invent causes
- diagnose
- claim medical certainty

---

## 20. Data Model

Suggested domain types:

    enum InsightKind: String, Codable, Sendable {
        case sleep
        case movement
        case recovery
        case heart
        case trainingLoad
        case strength
        case mobilityBalance
        case workoutHistory
    }

    struct InsightSnapshot: Sendable {
        let kind: InsightKind
        let headline: String
        let primaryValue: InsightValue
        let status: InsightStatus
        let facts: [InsightFact]
        let baseline: [BaselineComparison]
        let trend: TrendDirection
        let action: SuggestedAction?
        let generatedAt: Date
    }

All calculation remains deterministic.

---

## 21. New Architecture Modules

Add:

    Features/
      Insights/
        InsightsHub/
        SleepInsight/
        MovementInsight/
        RecoveryInsight/
        HeartInsight/
        TrainingLoadInsight/
        StrengthInsight/
        MobilityInsight/
        WorkoutJourney/
        WeeklyReview/

    Insights/
      InsightEngine.swift
      InsightSnapshot.swift
      InsightContextBuilder.swift
      InsightActionEngine.swift

    Core/
      Illustrations/
        SleepNightScene.swift
        MovementPathScene.swift
        RecoveryWaveScene.swift
        HeartPulseScene.swift
        TrainingLoadLandscapeScene.swift
        StrengthBlocksScene.swift
        MobilityArcScene.swift
        JourneyRouteScene.swift

---

## 22. V1 vs V1.1

### V1
- Insights Hub
- Sleep page
- Steps & Movement page
- Recovery page
- Training Load page
- Workout Journey
- light illustration system
- one or two widgets

### V1.1
- Heart page
- Strength page
- Mobility & Balance page
- Weekly Body Review
- expanded widgets/complications
- richer motion

### Later
- shareable monthly report
- coach-generated challenges
- seasonal visual themes

---

## 23. Acceptance Criteria

A Body Insight page is done only when:
- it has a unique but brand-consistent visual identity
- it displays personal-baseline context
- it explains what changed
- it provides one useful action
- it works without AI
- AI wording cannot contradict deterministic facts
- it supports VoiceOver
- it supports Dynamic Type
- it has a Reduce Motion state
- it has loading / empty / unavailable states
- it has preview fixtures
- it has unit tests for derived data
- it does not resemble a copied competitor screen

---

## 24. Product Success Test

A user should be able to open any Body Insight page and answer within five seconds:

1. How am I doing?
2. Is this normal for me?
3. Why?
4. What should I do next?

If the page cannot answer all four, simplify it.
