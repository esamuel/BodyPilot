# PRD_DELTA.md — Concept change: Body Score → Activity Corridor

This document overrides PRD.md wherever the two conflict.
CLAUDE.md rules remain in force.

## 1. New core concept

BodyPilot moves from a single 0–100 Body Score to an **Activity Corridor**:
a personal healthy-load band computed from heart-rate-based training load,
sleep, and resting-HR/HRV baselines. Each day lands in one of three states:

- `inside` — healthy load for today
- `above` — overreaching
- `below` — under-active

The corridor is drawn as a band over time with the user's daily load as a
line/dots. Views: 1 day, 10 days, 30 days.

## 2. Streak

A streak day means the user stayed inside the corridor or took a rest day
the corridor called for. Resting when the corridor says rest keeps the
streak alive. Two consecutive above-corridor days break it. An isolated
above or below day does not add to the streak. Streak logic is deterministic.

## 3. Life Status

User-set statuses pause corridor pressure without breaking the streak:
`sick`, `injured`, `onBreak`, `vacation`. Status has a start date and
an optional end date. While active: no nudges, streak frozen, corridor
displayed but greyed. If statuses overlap, the most recently started active
status is displayed.

## 4. Training load

`LoadEngine` uses heart-rate-zone load. Per workout, sum each sample
interval's minutes multiplied by its HR-reserve zone weight. HR reserve uses
the personal resting-HR baseline and estimated max HR. HR coverage below 50%
uses the fallback: duration × activity weight × RPE factor. When an explicit
RPE exists, session RPE (duration × RPE) overrides HR load. Constants live in
`LoadConfiguration`.

Until BodyPilot collects a user-entered max HR, max HR is estimated from the
highest observed workout HR with a conservative configured floor.

## 5. Daily suggestion (BodyPilot card)

Daily suggestion types: `rest`, `activeRecovery`, `light`, `moderate`,
`hard`. Deterministic safety constraints remain authoritative.

## 6. Navigation

Four tabs: **Path · Insights · Workouts · Me**

- Path: corridor chart, today's state, streak, life status, the BodyPilot
  daily-suggestion card, and vitals row.
- Insights: existing Body Insights worlds and progress views.
- Workouts: history and start workout.
- Me: profile, coach settings, subscription.

The AI Coach is a sheet reachable from Path and Workouts.

## 7. Workout journal

Each workout summary supports rename, note, RPE 1–10, photo references, and
favorite. Journal metadata is app-owned and linked to a stable workout ID.
RPE feeds the load override.

## 8. Recaps

Weekly and monthly recap cards live in Insights, with a compact preview on
Path: active days, load versus previous period, distance, energy, and photos.

## 9. Localization & RTL

Hebrew is a first-class locale. All new screens must be verified in `he`
with right-to-left layout. Corridor charts use chronological data order while
labels and surrounding controls follow layout direction.

## 10. Deployment target

Ship the rebuild on iOS 26 and watchOS 26. iOS/watchOS 27-only enhancements
are deferred until the final SDK is available.

## 11. Non-goals

- No mascot character.
- No cycle tracking.
- No Android or cloud sync.
- Do not delete Body Insights, HealthKitClient, WorkoutSessionManager,
  StoreKit, App Intents, widgets, or string catalogs.
