# BodyPilot AI — Product Requirements Document

Version: 1.1
Date: 2026-08-25
Target: iOS 27 + watchOS 27
IDE: Xcode 27
Language: Swift 6.4
UI: SwiftUI
Status: Build-ready V1 specification + Body Insights differentiation layer

---

## 1. Product Vision

BodyPilot AI is a privacy-first personal fitness and recovery coach for iPhone and Apple Watch.

Its job is not to show the user more charts. Its job is to answer:

1. How is my body doing today?
2. Should I train, take it easy, or recover?
3. What exactly should I do?
4. How should the workout adapt while I am doing it?
5. How am I progressing over time?

The app combines Apple Health data, recent workout load, sleep, heart-rate trends, HRV, user-reported readiness, preferences, goals, and workout history to generate a simple daily Body Score and an actionable recommendation.

Core promise:

> Know what your body is ready for today — and get the right workout automatically.

---

## 2. Product Principles

1. Decision first, data second.
2. Personal baseline beats population averages.
3. Fitness guidance, not medical diagnosis.
4. Raw health data stays on-device whenever possible.
5. AI explains and personalizes; deterministic code calculates health metrics.
6. Apple Watch is a coach, not only a recorder.
7. The app must remain useful even when cloud AI is unavailable.
8. Accessibility and simplicity are first-class requirements.
9. Use native Apple frameworks before introducing third-party dependencies.
10. Every major recommendation must be explainable.

---

## 3. Target User

Primary:
- Adults who want clear daily fitness guidance.
- People returning to regular exercise.
- Walkers and recreational exercisers.
- Adults interested in healthy aging.
- Users combining walking/cardio, strength, mobility and balance.
- People who prefer sustainable training over aggressive streak mechanics.

Secondary:
- Regular exercisers who want recovery-aware guidance.
- Apple Watch users who want more personalized interpretation of Health data.

Not primary V1:
- Elite athletes.
- Competitive team sports.
- Clinical rehabilitation.
- Medical diagnosis or treatment.

---

## 4. Supported Platforms

### V1
- iPhone: iOS 27+
- Apple Watch: watchOS 27+
- SwiftUI native app
- Swift 6.4
- Xcode 27

### Later
- iPad
- Web companion
- Additional wearable/data providers

---

## 5. Xcode 27 / iOS 27 Technology Strategy

Use relevant new Apple-platform capabilities aggressively while keeping the architecture maintainable.

### 5.1 Foundation Models framework
Use the iOS 27 Foundation Models framework as the primary AI abstraction.

Goals:
- On-device coaching where supported.
- Structured workout explanations.
- Natural-language coaching.
- Dynamic Profiles for different coaching modes.
- Provider abstraction through the LanguageModel protocol.
- Future ability to use Apple Foundation Models, Private Cloud Compute, or another conforming provider without rewriting the app.

AI must never be responsible for calculating the Body Score itself.

### 5.2 HealthKit workout zones
Use iOS/watchOS 27 workout zone APIs:
- HKWorkoutZoneGroup
- preferredWorkoutZoneConfiguration(for:)
- HKWorkoutZoneConfiguration
- HKLiveWorkoutBuilderDelegate real-time zone updates

Use zones for:
- live workout intensity guidance
- time-in-zone summaries
- post-workout insights
- adapting cardio intensity

### 5.3 WorkoutKit
Use WorkoutKit for:
- CustomWorkout
- SingleGoalWorkout
- PacerWorkout where appropriate
- WorkoutPlan
- workout previews
- syncing scheduled workouts to Apple Watch

### 5.4 App Intents
Expose safe user actions through App Intents:
- “How am I today?”
- “Start today’s workout.”
- “Give me a 20-minute workout.”
- “Log how I feel.”
- “Show my weekly progress.”

Design intents for Siri / Apple Intelligence integration.

### 5.5 SwiftUI 27
Use modern SwiftUI architecture and iOS 27 APIs where useful:
- Swift Observation
- modern @State behavior
- ContentBuilder where appropriate
- new reorderable APIs for user-customizable workout/favorites lists
- new swipe action container APIs where appropriate
- native platform materials and controls
- Liquid Glass-compatible native components rather than custom imitation

### 5.6 Xcode 27 coding intelligence
Project documentation must support Xcode agents.

Repository root must contain:
- CLAUDE.md
- README.md
- PRD.md

The agent should be able to build, run tests, inspect compiler failures, and iterate through Xcode tools.

External Claude Code may connect to Xcode using:

    claude mcp add --transport stdio xcode -- xcrun mcpbridge

---

## 6. Main Navigation

Five tabs:

1. Today
2. Coach
3. Workout
4. Progress
5. Me

Apple Watch navigation:
1. Today
2. Start Workout
3. Active Workout
4. Summary

---

## 7. V1 Functional Requirements

## 7.1 Onboarding

Maximum six primary screens.

### Screen 1 — Goal
Options:
- Get active again
- Lose weight
- Improve walking endurance
- Build strength
- Improve mobility
- Improve balance
- Healthy aging
- General fitness

### Screen 2 — Current activity
- Beginner
- Occasional
- Regular
- Very active

### Screen 3 — Apple Health permission
Explain exactly why each category is requested.

### Screen 4 — Preferred activities
Multi-select:
- Walking
- Running
- Cycling
- Strength
- Mobility
- Balance
- Stretching
- Chair exercise
- Swimming
- Core
- Recovery

### Screen 5 — Equipment
- None
- Resistance bands
- Dumbbells
- Home gym
- Full gym

### Screen 6 — Coach setup
- coaching tone
- preferred workout duration
- preferred workout days
- first Body Score and recommendation

Persist onboarding locally.

---

## 7.2 Today Screen

Primary output:

### Body Score
Range: 0–100.

Status bands:
- 80–100: Strong
- 65–79: Ready
- 45–64: Easy
- 0–44: Recover

Do not present score as a medical measurement.

### Components
- Body Score
- readiness label
- short explanation
- recovery score
- sleep score
- heart/HRV trend
- recent training load
- user feeling
- recommended workout
- duration
- intensity
- primary CTA: Start Workout
- secondary CTA: Change
- secondary CTA: Ask Coach

### Explanation example
“Your recovery signals are close to your normal range, but you slept less than usual. Today is a good day for moderate activity rather than a hard session.”

---

## 7.3 Body Score Engine

Body Score must be deterministic.

Initial configurable weighting:
- Sleep: 25%
- HRV relative to personal baseline: 20%
- Resting HR relative to baseline: 15%
- Recent workout load: 20%
- Recovery/history consistency: 10%
- User-reported feeling: 10%

### Rules
- Compare physiological signals to personal rolling baseline.
- Never score a user solely from population thresholds.
- Require minimum usable historical data.
- Expose confidence value.
- Missing data reduces confidence, not necessarily score.
- Maintain a detailed ScoreExplanation object.

Example model:

    struct BodyScoreResult {
        let score: Int
        let confidence: Double
        let readiness: ReadinessLevel
        let components: [ScoreComponent]
        let explanationFacts: [ExplanationFact]
        let computedAt: Date
    }

### Baseline windows
Prototype:
- short baseline: 7 days
- primary baseline: 28 days
- trend baseline: 90 days

All constants must be centralized and testable.

---

## 7.4 Daily Check-in

One-tap readiness:
- Very tired
- Tired
- Normal
- Good
- Excellent

Optional soreness:
- Legs
- Back
- Knee
- Shoulder
- General
- None

Optional free-text note.

Check-in must influence recommendations but must not override safety logic.

---

## 7.5 Coach

Conversational AI coach.

Input:
- text
- dictation
- structured context from the app

Examples:
- “I only have 15 minutes.”
- “My legs are tired.”
- “Give me a home workout.”
- “Why is my score lower today?”
- “Make today easier.”
- “What improved this month?”

### AI context policy
Do not send the complete raw HealthKit record to a cloud model.

Provide structured derived context, for example:

    bodyScore: 72
    sleepVsBaseline: -8%
    hrvVsBaseline: -5%
    restingHRVsBaseline: +2 bpm
    recentLoad: moderate
    subjectiveFeeling: normal
    goal: walkingEndurance
    equipment: none

### Coach profiles
Use Dynamic Profiles:
- Daily Coach
- Workout Builder
- Progress Analyst
- Recovery Explainer

### AI fallback
If Foundation Models are unavailable:
- deterministic recommendation engine remains functional
- use predefined explanation templates
- Coach shows graceful availability state

---

## 7.6 Workout Generator

Workout generation uses rules first, AI second.

Inputs:
- readiness
- Body Score
- goal
- time available
- preferred activity
- equipment
- recent load
- soreness
- limitations configured by user
- workout history

Workout structure:
- warmup
- main work
- optional strength/mobility block
- cooldown

Each generated workout must contain:
- activity
- duration
- target intensity
- optional target HR zone
- steps
- explanation
- adaptation rules

Supported V1:
- Walking
- Strength
- Mobility
- Balance
- Stretching
- Core
- Recovery
- Combined walk + strength
- Combined cardio + mobility

V1.1:
- Running
- Cycling
- Swimming
- HIIT

---

## 7.7 Live Apple Watch Workout

Use HealthKit live workout session APIs.

Display:
- elapsed time
- current step
- heart rate
- target zone
- current zone
- next step
- pause/end

Adaptive events:
- HR above intended zone for configured period
- HR below intended zone
- step completion
- user requests easier/harder
- workout interruption

Example:
“Intensity is higher than planned. Ease back for 2 minutes.”

Do not auto-escalate intensity using AI without deterministic safety limits.

Haptics:
- step transition
- zone warning
- workout complete

---

## 7.8 Workout Completion

Summary:
- duration
- activity
- active energy when available
- average HR
- zone time
- perceived exertion
- completion
- short coaching summary

Prompt:
“How did that feel?”
- Too easy
- Right
- Hard
- Too hard

Use answer to personalize future recommendations.

---

## 7.9 Progress

Periods:
- 7 days
- 30 days
- 90 days

Metrics:
- workout consistency
- active minutes
- walking/cardio time
- strength sessions
- recovery distribution
- Body Score trend
- resting HR trend
- HRV trend
- sleep trend
- zone distribution

AI-generated progress summary may explain changes but must cite underlying local metrics internally.

Example:
“You exercised more consistently this month while your recovery remained stable.”

---

## 7.10 Personal Programs

V1 programs:
- Get Active Again — 4 weeks
- Walking Endurance — 6 weeks
- Healthy Aging — 6 weeks
- Strength Starter — 6 weeks
- Mobility & Balance — 4 weeks

Program engine:
- defines weekly targets
- generates daily recommendation
- adjusts daily workload based on readiness
- never blindly forces scheduled intensity

---

## 7.11 Me / Settings

Sections:
- goals
- activity preferences
- equipment
- workout duration
- coaching preferences
- Health permissions
- data/privacy
- notifications
- units
- language
- subscription
- export/delete app data
- safety information

---

## 8. HealthKit Data

Request only data required for enabled features.

Potential reads:
- workouts
- heart rate
- resting heart rate
- HRV
- sleep
- active energy
- exercise time
- walking/running distance
- steps
- respiratory rate if justified later
- cardio fitness if available and product-reviewed

Potential writes:
- workouts created by the app
- workout metadata where appropriate

Requirements:
- permission copy must be clear and specific
- gracefully support denied categories
- no hidden health-data collection
- health data must never be used for advertising

---

## 9. Data Architecture

### Local-first
Use:
- SwiftData for app-owned structured data
- HealthKit as the source of truth for Apple Health records
- Keychain for secrets/tokens
- AppStorage only for simple preferences

Suggested modules:

    BodyPilotApp
    ├── App
    ├── Core
    │   ├── Models
    │   ├── DesignSystem
    │   ├── Extensions
    │   └── Utilities
    ├── Health
    │   ├── HealthKitClient
    │   ├── HealthPermissions
    │   ├── HealthQueries
    │   └── BaselineEngine
    ├── Readiness
    │   ├── BodyScoreEngine
    │   ├── LoadEngine
    │   └── RecommendationEngine
    ├── AI
    │   ├── CoachService
    │   ├── FoundationModelProvider
    │   ├── CoachProfiles
    │   └── AIContextBuilder
    ├── Workouts
    │   ├── WorkoutGenerator
    │   ├── WorkoutKitService
    │   └── WorkoutTemplates
    ├── Features
    │   ├── Onboarding
    │   ├── Today
    │   ├── Coach
    │   ├── Workout
    │   ├── Progress
    │   └── Settings
    ├── Intents
    └── Resources

    BodyPilotWatch
    ├── Today
    ├── Workout
    ├── HealthSession
    ├── Coaching
    └── ComplicationsWidgets

---

## 10. Architecture Rules

- Swift concurrency first.
- Swift 6 strict concurrency.
- No force unwraps in production code.
- Dependency injection through protocols.
- Feature-level ViewModels or observable feature state only when needed.
- Business logic must not live in SwiftUI Views.
- HealthKit access behind protocol abstractions.
- AI access behind LanguageModel-provider abstraction.
- Every calculation engine must have unit tests.
- Views require previews with mock data.
- Prefer structs/value types where appropriate.
- Avoid third-party packages in V1 unless there is a clear documented reason.

---

## 11. Privacy & Safety

### Privacy
Default:
- health records stay on-device
- local Body Score calculation
- local baseline calculation
- derived context sent to external AI only if needed and allowed
- explicit privacy disclosure

### Safety
App must say it provides fitness guidance and is not a medical diagnostic tool.

Never:
- diagnose disease
- interpret symptoms as a medical condition
- advise medication changes
- override emergency symptoms with workout guidance

Safety triggers must stop workout recommendations and present appropriate guidance when user input indicates potentially serious symptoms.

Implement safety logic as deterministic application logic, not solely as an LLM prompt.

---

## 12. Notifications

V1:
- morning readiness available
- planned workout reminder
- program reminder
- optional evening check-in

Avoid guilt-based wording.

Examples:
- “Your plan is ready when you are.”
- “Today may be a good recovery day.”

---

## 13. Accessibility

Required:
- Dynamic Type
- VoiceOver labels
- sufficient contrast
- no meaning by color alone
- reduced-motion respect
- large tap targets
- Apple Watch glanceability
- localization-ready strings from day one

---

## 14. Monetization

### Free
- Apple Health connection
- Body Score
- basic daily recommendation
- basic workout history
- weekly summary
- limited workout templates

### Pro
- AI Coach
- personalized workout generation
- adaptive plans
- live Watch coaching
- advanced progress analysis
- personal programs
- long-term trend explanations

Initial candidate pricing:
- ₪14.90/month
- ₪99/year

Pricing remains a business experiment, not hard-coded product logic.

Use StoreKit 2.

---

## 15. Analytics

Privacy-respecting product analytics only.

Track:
- onboarding completion
- Health connection completion
- Today screen viewed
- recommendation accepted/changed
- workout generated
- workout started/completed
- workout feedback
- Coach request category
- program started
- subscription conversion

Never log raw HealthKit values to analytics.

---

## 16. V1 Scope

Must Have:
- onboarding
- HealthKit permissions and reads
- baseline engine
- Body Score
- Today screen
- daily check-in
- deterministic recommendation engine
- workout generator
- Apple Watch workout session
- workout summary
- basic progress
- Foundation Models coach
- App Intents
- SwiftData persistence
- StoreKit 2 subscription skeleton
- privacy/safety layer
- unit tests
- SwiftUI previews

V1.1:
- richer cardio support
- workout zones analytics
- Smart Stack/widget refinement
- more programs
- richer Watch coaching
- localization expansion
- advanced subscription/paywall experiments

Later:
- social
- trainer portal
- non-Apple wearables
- web
- competitive challenges
- clinical features

---

## 17. Non-Goals for V1

Do not build:
- social feed
- friends/following
- nutrition tracking
- calorie logging
- medical diagnosis
- complex gym exercise catalog
- web backend unless a real need emerges
- custom account/auth system unless required for paid cloud services
- chat history syncing across devices unless justified

---

## 18. Testing Strategy

### Unit
- BodyScoreEngine
- BaselineEngine
- LoadEngine
- RecommendationEngine
- WorkoutGenerator
- AIContextBuilder
- safety rules

### Integration
- HealthKit authorization
- Health query pipeline
- WorkoutKit scheduling
- StoreKit
- watch connectivity
- App Intents

### UI
- onboarding
- Today state variants
- no-data states
- low-readiness states
- workout start/end
- Coach unavailable state
- subscription flows

### AI evaluations
Use Apple Evaluations framework for:
- recommendation explanation fidelity
- unsupported medical claim prevention
- workout constraint adherence
- time-limit adherence
- equipment constraint adherence
- tone consistency

---

## 19. Acceptance Criteria for First Internal Build

A clean install must allow a user to:

1. Complete onboarding.
2. Authorize HealthKit.
3. See a calculated or low-confidence Body Score.
4. Understand why the score was produced.
5. Complete a daily check-in.
6. Receive a recommended workout.
7. Change the available time and regenerate the workout.
8. Ask the coach why today’s recommendation was selected.
9. Start the workout on Apple Watch.
10. See live HR and zone information where available.
11. Finish the workout.
12. Rate perceived difficulty.
13. See the workout reflected in Progress.
14. Relaunch without losing app-owned state.
15. Use core functionality with network unavailable.

---

## 20. Build Order

Phase 1 — Project foundation
- create iOS + watchOS targets
- SwiftData models
- design system
- navigation
- HealthKit entitlements
- test targets

Phase 2 — Health foundation
- permissions
- queries
- baseline engine
- mock health data

Phase 3 — Readiness
- BodyScoreEngine
- recommendation engine
- Today UI
- check-in

Phase 4 — Workout
- workout domain models
- generator
- WorkoutKit
- Watch active workout

Phase 5 — Intelligence
- Foundation Models
- dynamic coach profiles
- AI context builder
- deterministic fallback
- evaluations

Phase 6 — System integration
- App Intents
- notifications
- widgets/Smart Stack as justified
- StoreKit 2

Phase 7 — QA
- accessibility
- privacy
- battery/performance
- real-device watch testing
- TestFlight

---

## 21. Definition of Done

A feature is done only when:
- compiles with Swift 6.4 strict concurrency
- has tests for business logic
- has a SwiftUI preview where applicable
- handles loading/error/empty states
- is accessible
- is localized through String Catalog
- does not expose raw health data unnecessarily
- follows the architecture in CLAUDE.md
- passes build and test in Xcode 27

---

## 22. Official Apple References

- Xcode 27: https://developer.apple.com/xcode/
- Xcode 27 What's New: https://developer.apple.com/xcode/whats-new/
- iOS 27: https://developer.apple.com/ios/whats-new/
- watchOS 27: https://developer.apple.com/watchos/whats-new/
- HealthKit updates: https://developer.apple.com/documentation/Updates/HealthKit
- WorkoutKit: https://developer.apple.com/documentation/workoutkit
- Foundation Models updates: https://developer.apple.com/documentation/Updates/FoundationModels
- Xcode external agent MCP: https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode

---

## 23. Body Insights — Dedicated Visual Health & Fitness Worlds

BodyPilot adds a differentiated experience layer called **Body Insights**.

Instead of placing every metric on one dense dashboard, the app gives major dimensions of the user's fitness their own dedicated page:

- Sleep
- Steps & Movement
- Recovery
- Heart
- Training Load
- Strength
- Mobility & Balance
- Workout Journey

Each page must combine:
- a light, original BodyPilot illustration
- one dominant status/value
- personal-baseline comparison
- a small number of supporting metrics
- a simple trend visualization
- plain-language explanation
- one recommended action

The Today screen remains simple and gains an **Explore your body** card section linking to these pages.

### 23.1 Design Principle

The dedicated pages must feel like different “worlds” inside one product. They can use controlled secondary accent palettes, but the BodyPilot logo, typography, spacing, and core brand colors remain consistent.

Illustrations must be original. Do not copy the composition, mascots, wording, or artwork of another product.

### 23.2 Personal Baseline First

Each metric page should prioritize:
- today vs user's own normal range
- 7-day change
- 28-day change
- confidence / data completeness

Population references can be educational context only and must not replace personal-baseline logic.

### 23.3 Action-Linked Insights

Every dedicated page ends with one useful CTA tied to safe deterministic logic.

Examples:
- Sleep: Plan tonight
- Movement: Take a 12-minute walk
- Recovery: Choose easy session
- Training Load: Start recommended session
- Strength: Build today's strength session
- Mobility: 5-minute mobility reset

### 23.4 Daily Story

Today may expose an optional **Daily Story** containing 4–6 concise cards that explain:
- readiness
- overnight changes
- movement so far
- workout recommendation
- one insight
- evening suggestion

The story is data-driven, not a social-media feed.

### 23.5 Weekly Body Review

Pro users can receive a visual weekly review covering:
- recovery
- sleep
- movement
- training consistency
- best day
- one improvement area
- next-week focus

### 23.6 Widgets & Complications

Body Insights should power glanceable widgets/complications for:
- Body Score
- recovery
- sleep
- steps vs usual
- next workout
- weekly progress

### 23.7 Implementation Reference

The complete UX, architecture, data model, visual system, and acceptance criteria are defined in `BODY_INSIGHTS_EXPERIENCE.md`.

This document is now part of the product source of truth.
