# CLAUDE.md — BodyPilot AI

This file is the operating contract for any coding agent working on BodyPilot AI.

Read `PRD.md` and `README.md` before making architectural changes.

---

## Mission

Build BodyPilot AI as a native, privacy-first iPhone + Apple Watch fitness and recovery coach using Xcode 27, iOS 27, watchOS 27, Swift 6.4, SwiftUI, HealthKit, WorkoutKit, Foundation Models, App Intents, SwiftData, and StoreKit 2.

The app must answer:

- How is the user doing today?
- Should they train, go easy, or recover?
- What exactly should they do?
- How should the workout adapt?
- How are they progressing?

Never turn the product into a generic fitness dashboard.

---

## Absolute Rules

1. Use Swift 6.4 and strict concurrency.
2. Target iOS 27+ and watchOS 27+ for this project unless the human explicitly changes the deployment target.
3. Use SwiftUI for UI.
4. Prefer native Apple frameworks.
5. Do not add a dependency without documenting why it is necessary.
6. Do not place business logic in Views.
7. Do not let an LLM calculate Body Score or safety decisions.
8. Do not send raw HealthKit history to an external model.
9. Do not introduce medical diagnosis.
10. Do not weaken privacy or HealthKit permission boundaries.
11. Do not use force unwraps in production code.
12. Do not silently change product scope.
13. Build after meaningful code changes.
14. Run relevant tests after changes.
15. Fix warnings caused by your changes.
16. Keep files focused and reasonably small.
17. Add previews for user-facing SwiftUI screens.
18. Use String Catalog/localization-ready strings.
19. Use semantic accessibility labels.
20. Preserve offline core functionality.

---

## Source of Truth

Priority order:

1. Human instruction in current conversation
2. PRD.md
3. CLAUDE.md
4. README.md
5. Existing tests
6. Existing code

If documents conflict, follow the higher-priority source and update lower-priority documentation when appropriate.

---

## Xcode 27 Agent Workflow

When Xcode tools are available:

1. Inspect the current project and target configuration.
2. Make the smallest coherent change.
3. Build the affected target.
4. Read compiler diagnostics.
5. Fix failures.
6. Run relevant tests.
7. Verify previews or UI state if appropriate.
8. Summarize exactly what changed.

Never report a feature as complete if the project does not compile.

External Claude Code can use Xcode MCP:

    claude mcp add --transport stdio xcode -- xcrun mcpbridge

Verify with:

    claude mcp list

Xcode must be open to the project when using the bridge.

---

## Architecture

Use feature-oriented architecture with protocol boundaries.

Suggested layout:

    BodyPilotApp/
      App/
      Core/
        Models/
        DesignSystem/
        Utilities/
      Health/
        HealthKitClient.swift
        HealthPermissions.swift
        HealthQueries.swift
        BaselineEngine.swift
      Readiness/
        BodyScoreEngine.swift
        LoadEngine.swift
        RecommendationEngine.swift
      AI/
        CoachService.swift
        FoundationModelProvider.swift
        CoachProfiles.swift
        AIContextBuilder.swift
      Workouts/
        WorkoutGenerator.swift
        WorkoutKitService.swift
        WorkoutTemplates.swift
      Features/
        Onboarding/
        Today/
        Coach/
        Workout/
        Progress/
        Settings/
      Intents/
      Resources/

    BodyPilotWatch/
      Today/
      Workout/
      HealthSession/
      Coaching/
      Widgets/

    BodyPilotTests/
    BodyPilotUITests/

---

## Dependency Direction

UI -> feature state/services -> domain engines -> platform clients

Allowed:
- Today feature calls RecommendationEngine.
- RecommendationEngine consumes normalized health/readiness models.
- HealthKitClient talks to HealthKit.
- CoachService consumes derived AIContext.

Not allowed:
- SwiftUI View querying HealthKit directly.
- LLM returning BodyScore as authoritative data.
- AI code mutating HealthKit directly.
- UI containing health-score formulas.
- Analytics receiving raw HealthKit values.

---

## Concurrency

Use:
- async/await
- actors for mutable shared service state
- Sendable domain values
- MainActor only for UI-facing state that needs it

Avoid:
- detached tasks without justification
- unchecked Sendable unless documented
- callback pyramids
- synchronous blocking I/O on main thread

Every new concurrency warning must be resolved, not suppressed.

---

## HealthKit Rules

HealthKit is sensitive.

Requirements:
- request only required types
- show a graceful state for denied permissions
- query through HealthKitClient abstractions
- convert samples into normalized domain models
- do not persist unnecessary copies of raw HealthKit data
- keep test fixtures synthetic
- never log raw health values to analytics
- use real-device validation before declaring Watch workout behavior complete

For iOS/watchOS 27 workout zones, prefer:
- HKWorkoutZoneGroup
- preferredWorkoutZoneConfiguration(for:)
- HKWorkoutZoneConfiguration
- HKLiveWorkoutBuilderDelegate updates

---

## Body Score

Body Score is deterministic and explainable.

Never ask the model to “decide a score.”

The engine returns:

    struct BodyScoreResult: Sendable {
        let score: Int
        let confidence: Double
        let readiness: ReadinessLevel
        let components: [ScoreComponent]
        let explanationFacts: [ExplanationFact]
        let computedAt: Date
    }

Initial weighting:
- sleep 25%
- HRV 20%
- resting HR 15%
- recent load 20%
- recovery/history 10%
- subjective feeling 10%

Weights must be centralized and easy to tune.

Use personal baselines rather than fixed population cutoffs wherever possible.

Missing data reduces confidence.

Write extensive unit tests for:
- missing data
- low confidence
- extreme values
- baseline changes
- recovery days
- conflicting signals

---

## Recommendation Engine

RecommendationEngine is deterministic.

Output should include:

    struct DailyRecommendation: Sendable {
        let level: ReadinessLevel
        let recommendedDuration: DurationRange
        let preferredActivities: [ActivityType]
        let intensity: WorkoutIntensity
        let constraints: [WorkoutConstraint]
        let rationaleFacts: [ExplanationFact]
    }

AI may explain or personalize wording, but must not override constraints.

---

## AI / Foundation Models

Use Foundation Models as the AI abstraction.

Design so model providers are replaceable.

Protocol example:

    protocol CoachProviding: Sendable {
        func respond(to request: CoachRequest) async throws -> CoachResponse
    }

Use Dynamic Profiles for:
- DailyCoach
- WorkoutBuilder
- ProgressAnalyst
- RecoveryExplainer

AI receives derived context, not full raw HealthKit records.

Preferred context:

    bodyScore: 72
    confidence: 0.84
    sleepDelta: -0.08
    hrvDelta: -0.05
    restingHRDeltaBPM: 2
    recentLoad: .moderate
    feeling: .normal
    goal: .walkingEndurance
    equipment: [.none]

Always include deterministic constraints in the request.

Provide a non-AI fallback.

Use the Evaluations framework for AI behavior QA.

---

## Workout Generation

WorkoutGenerator must enforce:
- time limit
- equipment
- readiness
- soreness
- goal
- supported activity
- safety constraints

AI may help with human-readable composition but cannot violate the generator's validated constraints.

Every generated workout must be validated before display/start.

---

## Apple Watch

Watch experience must be glanceable.

During workout prioritize:
1. current step
2. heart rate / zone
3. elapsed time
4. next action

Use haptics for important state transitions.

Do not spam the user with messages.

Adaptive coaching must be driven by deterministic thresholds and state machines.

---

## SwiftUI

Use native controls and materials.

Goals:
- adopt iOS 27 design naturally
- support Dynamic Type
- support VoiceOver
- respect Reduce Motion
- avoid custom chrome when standard components work
- keep body implementations readable
- extract complex subviews
- previews for normal/loading/error/empty states

Use new SwiftUI 27 APIs where they genuinely improve the product.

Do not use an API merely because it is new.

---

## App Intents

Expose safe, useful actions:
- GetTodayReadinessIntent
- StartRecommendedWorkoutIntent
- CreateQuickWorkoutIntent
- LogFeelingIntent
- ShowWeeklyProgressIntent

Intents must call the same domain services used by the app.

Do not duplicate business logic inside intent handlers.

---

## Persistence

Use SwiftData for app-owned records such as:
- UserProfile
- CheckIn
- GeneratedWorkout
- ProgramEnrollment
- CoachPreference
- cached derived summaries where justified

Do not copy the entire HealthKit database into SwiftData.

Use Keychain for secrets.

---

## Testing

Every calculation engine requires unit tests.

Minimum suites:

    BodyScoreEngineTests
    BaselineEngineTests
    LoadEngineTests
    RecommendationEngineTests
    WorkoutGeneratorTests
    SafetyRuleTests
    AIContextBuilderTests

Use protocol mocks for HealthKit and AI.

UI tests should cover:
- onboarding
- Today
- check-in
- workout generation
- workout start
- Coach fallback
- paywall

When fixing a bug, add a regression test when practical.

---

## Safety

This is a fitness app, not a medical app.

The AI must not:
- diagnose
- recommend medication changes
- claim to detect disease
- invent medical certainty

Potentially serious symptom handling must be deterministic and conservative.

Never let a conversational model decide whether a safety gate is bypassed.

---

## Privacy

Architecture target:
- raw HealthKit data on-device
- local calculations
- derived AI context
- explicit user control
- no health-data advertising use
- no sensitive values in analytics logs

Before introducing any backend, state exactly:
- what data leaves device
- why
- retention
- encryption
- deletion mechanism
- whether the feature can work without it

---

## Performance

Optimize for:
- fast Today screen
- battery-conscious HealthKit queries
- minimal Watch background work
- cached normalized summaries where appropriate
- no repeated expensive full-history queries

Profile before speculative optimization.

---

## Design Language

Visual personality:
- calm
- premium
- clear
- warm
- non-judgmental
- confidence without clinical appearance

Avoid:
- aggressive red warnings for normal low-readiness days
- guilt language
- dense dashboards
- tiny text
- excessive rings/gauges
- gamification that encourages overtraining

Primary home-screen hierarchy:

    Body Score
    Readiness message
    Recommended workout
    Start action
    Why / supporting signals

---

## Coding Style

- descriptive names
- one primary responsibility per type
- explicit access control
- avoid giant god objects
- avoid needless generic abstractions
- comments explain why, not obvious what
- documentation comments for public/domain APIs
- format consistently
- no dead code
- no commented-out abandoned implementations

---

## Git / Change Discipline

For each meaningful feature:
- keep changes scoped
- do not rewrite unrelated code
- preserve working behavior
- update tests
- update docs when architecture changes

Commit naming suggestion:

    feat(today): add deterministic readiness summary
    feat(health): add HRV baseline query
    feat(watch): add live zone coaching
    test(score): cover missing sleep samples
    fix(coach): prevent constraint override

---

## First Build Task

If the repository is empty, implement only Phase 1 first:

1. Create iOS app target.
2. Create watchOS companion target.
3. Add SwiftData container.
4. Add five-tab iPhone shell.
5. Add basic Watch navigation.
6. Add HealthKit capability placeholders.
7. Add dependency protocols.
8. Add test targets.
9. Add a minimal DesignSystem.
10. Ensure all targets build in Xcode 27.

Do not jump directly to AI or live workout logic before the foundation builds cleanly.

Then proceed through the Build Order in `PRD.md`.

---

## Body Insights Experience Rules

Read `BODY_INSIGHTS_EXPERIENCE.md` before implementing any metric-detail UI.

Body Insights is a first-class product layer, not a collection of miscellaneous charts.

### Required behavior

Each major insight page must:
- show one primary status/value first
- compare against personal baseline
- explain what changed
- end with one deterministic safe action
- work without AI
- use AI only to phrase or explain validated facts

### Visual architecture

Add reusable illustration scenes under:

    Core/Illustrations/

Prefer native SwiftUI Shapes, Canvas, gradients, and SF Symbols where appropriate.

Illustrations must:
- be original to BodyPilot
- have a static/reduced-motion state
- avoid heavy continuous animations
- stay decorative and never hide essential information
- be testable independently in previews

### Insight domain layer

Create an `Insights` domain module containing:
- InsightEngine
- InsightSnapshot
- InsightContextBuilder
- InsightActionEngine

Do not calculate insight state in Views.

Do not ask the language model to invent an insight.

### Dedicated page features

Organize:

    Features/Insights/
      InsightsHub/
      SleepInsight/
      MovementInsight/
      RecoveryInsight/
      CardioFitness/
      StrengthInsight/
      MobilityInsight/
      WorkoutJourney/
      WeeklyReview/

### Cardio Fitness insight

The visible Insights hub includes **Cardio** instead of a Training Load card. Training load remains a deterministic input to Body Score and recommendations; it is not removed from the readiness domain.

Cardio must:

- read through the HealthKit abstraction, never query HealthKit from a View
- combine normalized data originating from iPhone, Apple Watch, and recorded activities
- cover resting heart rate, steps, activity duration, walking/running distance, and active energy
- include VO₂ max in About Cardio Fitness when HealthKit provides an estimate
- keep missing values missing rather than inventing zeroes
- aggregate chart points into one average per calendar month
- show a weighted average line for the selected 12-month or calendar-year period
- give every selectable metric a stable, distinct semantic color
- let touch or drag selection snap to a month and reveal its average, month, and year
- expose available calendar years from the loaded Health history
- remain descriptive and non-diagnostic; do not classify VO₂ max against population cutoffs

Health history may be queried far enough back to populate year selection, but normalized results stay on device and raw samples must not be persisted.

Do not add new main tabs. Keep:

    Today | Coach | Workout | Progress | Me

### AI contract

AI may receive only validated `InsightContext` data.

AI must never:
- alter metric values
- claim a cause not present in deterministic facts
- diagnose
- override a SuggestedAction safety constraint

### UX test

For every insight page, verify that a user can determine in under five seconds:
1. How am I doing?
2. Is it normal for me?
3. Why?
4. What should I do next?

If not, simplify the page.
