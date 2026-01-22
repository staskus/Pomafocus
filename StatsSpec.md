# Pomafocus Stats Module Spec

## Goals
- Make progress visible and motivating without guilt or overload.
- Show session consistency, focus volume, and blocking impact at a glance.
- Keep visuals aligned with the current bold, minimal Pomafocus style.

## Core Metrics
### Focus
- Focus minutes (today, week, month).
- Sessions completed vs. started (completion rate).
- Average session length and median session length.
- Streaks: current streak, longest streak, weekly streak (days with >= 1 session).
- Deep Breath usage: countdown triggers, confirmations, stops prevented.

### Blocking
- Block attempts per day (total and by app/site).
- Peak temptation windows (time-of-day).
- Devices involved (iPhone, iPad, macOS).

### Derived Signals
- Focus consistency score: weighted by streak + completion rate.
- Rescue rate: deep breath confirmations / stop attempts.
- "Saved time" estimate: blocked attempts * average duration estimate.

## Data Model (Proposed)
### Event Log
- SessionEvent: start, stop, complete, duration, device, deepBreathEnabled.
- BlockEvent: app/site identifier, timestamp, device, allowed/blocked.
- DeepBreathEvent: started, confirmed, timedOut.

### Daily Rollups
- DailyStats: date, totalMinutes, sessionsStarted, sessionsCompleted, completionRate.
- DailyBlocks: date, attempts, topBlockedItems, peakHour.

### Storage + Sync
- Store locally with SwiftData or Core Data.
- Sync daily rollups via CloudKit (lightweight), keep full event log local.
- Keep 90 days of raw events, unlimited daily rollups.

## UI Structure
### Tab: Stats
Two-tier layout: Overview (default) + Insights.

#### Overview
- Hero ring: weekly focus minutes vs. target.
- Streak card: current streak, longest streak, "best week".
- Today card: minutes, sessions, completion rate.
- Block impact card: attempts today, peak window, top app/site.

#### Insights
- Weekly trend chart (bars) with completion overlay.
- Session length distribution (small histogram).
- Time-of-day heatmap (hourly focus density).
- Block attempts by time (sparkline).
- Deep Breath effectiveness (confirm vs. timeout).

#### Motivators
- Badges (first 5 sessions, 7-day streak, 10 hours/week).
- Weekly recap card with headline metric (ex: "+18% focus time").

## Visual Direction
- Use the existing gradient and accent red/yellow palette.
- Keep bold, monospaced numerals for time.
- Cards with dark surface and soft borders (like current widget style).
- Progress bars and rings reuse current ring style.
- Short, punchy labels (READY, FOCUS, STREAK).

## UX States
- Empty: show a single "Start your first session" card with a hero ring at 0%.
- Low data: hide advanced charts, show 7-day trend only.
- Offline: show cached data and a "Syncing..." badge.

## Accessibility
- Large type-friendly layout, avoid tiny chart labels.
- Color-safe variants: use pattern/opacity, not color only.

## Open Questions
- Target weekly focus minutes: user-defined or suggested?
- Should block attempts be private-only (no sync) by default?
- Include macOS focus sessions if user enables "Cross-device stats"?
