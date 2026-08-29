# BodyPilot AI

A privacy-first personal fitness and recovery coach for iPhone and Apple Watch.

> Know what your body is ready for today — and get the right workout automatically.

## Platform

- Xcode 27
- Swift 6.4
- iOS 27+
- watchOS 27+
- SwiftUI
- HealthKit
- WorkoutKit
- Foundation Models
- App Intents
- SwiftData
- StoreKit 2

## Product

BodyPilot AI combines personal HealthKit trends, workout history, recovery signals, daily check-in data, goals and preferences into:

- a daily Body Score
- a clear train/easy/recover recommendation
- a personalized workout
- Apple Watch live coaching
- progress explanations
- a conversational AI coach

The app is deliberately not a medical diagnostic tool.

## Start Here

Read in this order:

1. `PRD.md` — product requirements and build order
2. `CLAUDE.md` — coding-agent rules and architecture
3. this `README.md`

## Development Requirements

At the time this project was specified (August 25, 2026), Apple documents Xcode 27 as beta software. The current Xcode 27 beta uses Swift 6.4 and the iOS 27/watchOS 27 SDKs.

Xcode 27 beta requires macOS Tahoe 26.4 or later.

Confirm the latest Apple release notes before shipping.

## Create the Xcode Project

Recommended:

- App name: BodyPilot
- Interface: SwiftUI
- Language: Swift
- Storage: SwiftData
- Tests: enabled
- Deployment: iOS 27
- Add Watch App target: watchOS 27

Suggested bundle IDs:

    com.yourcompany.bodypilot
    com.yourcompany.bodypilot.watchkitapp

Do not hard-code these if an existing Apple Developer identifier already exists.

## Required Capabilities

iPhone target:
- HealthKit
- App Groups only if later required
- Notifications
- Siri/App Intents as appropriate
- In-App Purchase

Watch target:
- HealthKit
- Workout processing/background capabilities as required by final implementation

Only enable entitlements that the app actually uses.

## Suggested Repository Structure

    BodyPilot/
    ├── BodyPilotApp/
    ├── BodyPilotWatch/
    ├── BodyPilotTests/
    ├── BodyPilotUITests/
    ├── PRD.md
    ├── CLAUDE.md
    └── README.md

## Xcode 27 Intelligence

Xcode 27 supports coding agents and model choice directly in the IDE.

In Xcode:

    Xcode > Settings > Intelligence

Enable the agent/provider you want to use.

The project includes `CLAUDE.md` so Claude has project-specific instructions.

### Claude Code + Xcode MCP

Apple documents an Xcode MCP bridge for external agents.

With Xcode open to this project:

    claude mcp add --transport stdio xcode -- xcrun mcpbridge

Verify:

    claude mcp list

This lets Claude Code use Xcode capabilities such as project context, building and testing.

## First Prompt for Claude in Xcode

Copy this into the Xcode coding assistant after creating the project:

    Read PRD.md, CLAUDE.md and README.md completely.
    We are starting BodyPilot AI from an empty Xcode 27 project.
    Implement Phase 1 only.
    Create a clean feature-oriented SwiftUI architecture for the iOS and watchOS targets.
    Add the five-tab iPhone shell: Today, Coach, Workout, Progress, Me.
    Add the basic watchOS shell.
    Add SwiftData infrastructure, HealthKit service protocols, dependency boundaries, a small design system, mock data and unit-test targets.
    Use Swift 6.4 strict concurrency.
    Do not implement AI, real HealthKit queries or live workout logic yet.
    Build all targets, fix compiler errors and warnings caused by your work, run the tests, and stop only when Phase 1 builds cleanly.
    Summarize the files created and the next Phase 2 task.

## Build Phases

1. Project foundation
2. HealthKit + baseline engine
3. Body Score + recommendation engine
4. Workout generation + Watch
5. Foundation Models coach
6. App Intents + notifications + StoreKit
7. QA + accessibility + privacy + TestFlight

Do not skip phases unless explicitly instructed.

## Core Architecture Rule

Deterministic code calculates:

- Body Score
- readiness
- training constraints
- safety gates
- recommendation limits

AI handles:

- natural-language coaching
- explanation
- personalization
- workout wording/composition within validated constraints
- progress summaries

The AI may never be the sole authority for health-score calculations or safety decisions.

## Privacy

Default architecture:

    HealthKit -> local normalization -> local score/recommendation
                                      -> derived AI context only

Do not upload the user's full HealthKit history to a cloud model.

## Official Apple References

- Xcode: https://developer.apple.com/xcode/
- Xcode What's New: https://developer.apple.com/xcode/whats-new/
- iOS What's New: https://developer.apple.com/ios/whats-new/
- watchOS What's New: https://developer.apple.com/watchos/whats-new/
- HealthKit updates: https://developer.apple.com/documentation/Updates/HealthKit
- WorkoutKit: https://developer.apple.com/documentation/workoutkit
- Foundation Models updates: https://developer.apple.com/documentation/Updates/FoundationModels
- Xcode external-agent access: https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode

## Status

Initial specification complete.
Next action: create/open the Xcode 27 project and run the First Prompt above.

## Body Insights — New Differentiation Layer

BodyPilot now includes dedicated visual insight pages instead of concentrating all metrics into one dashboard.

Primary worlds:
- Sleep
- Steps & Movement
- Recovery
- Heart
- Training Load
- Strength
- Mobility & Balance
- Workout Journey

Each world combines a light original illustration, personal-baseline context, trend information, a concise explanation, and one useful action.

Read:

    BODY_INSIGHTS_EXPERIENCE.md

before building these screens.

### Updated build sequence

Keep the original phases, but implement Body Insights progressively:

- Phase 2: create normalized data required by insight snapshots
- Phase 3: build Recovery + Training Load insights together with Body Score
- Phase 3.5: build Insights Hub, Sleep, Steps & Movement, and visual illustration system
- Phase 4: add Workout Journey and Watch/widget surfaces
- Phase 5: add AI explanation to validated InsightContext
- V1.1: Heart, Strength, Mobility & Balance, Weekly Body Review

### Product rule

The home screen answers **what should I do today?**

The insight pages answer **what is happening in this part of my body and what should I do about it?**
