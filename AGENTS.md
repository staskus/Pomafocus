# Platform Guidelines (iOS & macOS)

## Repo Workflow
- Follow the repo-level conventions in `CLAUDE.md` (git workflow, signing environment, and build commands).

## Build & Project Generation
- **macOS:** open `Package.swift` in Xcode or run `swift run Pomafocus` during development. Use `./Scripts/build_app.sh` when you need a distributable `.app` bundle and always test the fresh bundle before sharing it.
- **iOS:** the SwiftUI companion lives in `apps/ios`. Generate the Xcode project with `./Scripts/generate_ios_project.sh` (requires `brew install xcodegen`) and remember that the resulting `.xcodeproj` is disposable - regenerate it whenever the manifest changes rather than committing it.
- Both platforms share the Swift package in `Sources/`, so rebuild both sides whenever you touch `PomafocusKit` or the sync layer.

## Coding Style
- SwiftUI view/state work should prefer Apple's Observation framework (`@Observable`, `@Bindable`) instead of `ObservableObject` / `@StateObject` unless a legacy API forces it.

## Testing & Devices
- Before reaching for a simulator, confirm whether a real iOS device is connected and prefer it when possible. Simulators are acceptable when hardware isn't available, but the final smoke test should run on-device.
- "Restart the app" means rebuild/install and relaunch (macOS menu bar + iOS) - don't just force quit and reopen the previous binary.

## Signing & Capabilities
- If you ever need the Apple Development team ID, run `security find-identity -p codesigning -v` and use the `Apple Development` identity (current default: `L4KYCD4RPZ`). That team ID must line up with the bundle identifiers declared in `apps/ios/project.yml` and the macOS entitlements in `Resources/Info.plist`.
- iCloud + push entitlements are already included for both apps; when creating new targets or sample projects, copy the existing entitlement settings (Key-Value sync relies on `com.apple.developer.ubiquity-kvstore-identifier` matching the bundle ID).

## After Each Code Change

Follow this workflow after making any code changes:

1. **Run tests:** `swift test`
2. **Regenerate Xcode projects:** `cd apps && xcodegen generate`
3. **Verify success:** Both steps must pass without errors
4. **Commit & push:** Only if tests pass and xcodegen succeeds

```sh
swift test && cd apps && xcodegen generate && cd .. && git add -A && git commit -m "Your message" && git push
```

---

## Architecture Overview

Pomafocus is a cross-platform Pomodoro timer with app/website blocking, cross-device sync, and focus statistics. Swift 6.0, macOS 13.0+, iOS 18.0+.

```
┌─────────────────────────────────────────────┐
│  iOS App (SwiftUI)                          │
│  PomafocusCore -> SessionController,        │
│    ScheduleStore, ExperienceCoordinator     │
│  Widgets: Live Activities, Home/Lock Screen │
└──────────────────┬──────────────────────────┘
                   │
        ┌──────────▼──────────┐
        │  PomafocusKit       │
        │  (Shared Library)   │
        │  Timer, Session,    │
        │  Sync, Stats,       │
        │  Blocking           │
        └──────────┬──────────┘
                   │
        ┌──────────┼──────────┐
        │                     │
   CloudKit (primary)   NSUbiquitousKVS
   push-woken sync      (fallback)
                   │
┌──────────────────▼──────────────────────────┐
│  macOS Menu Bar App (AppKit)                │
│  StatusBarController, HotkeyManager,        │
│  PreferencesWindowController                │
│  Delegates blocking to iOS companion        │
└─────────────────────────────────────────────┘
```

## Project Structure

```
Sources/
  PomafocusKit/              # Shared core library
    PomodoroTimer.swift              # Timer engine (injectable clock/ticker)
    PomodoroSessionController.swift  # Main session orchestrator (@MainActor, ObservableObject)
    PomodoroSyncManager.swift        # Cross-device sync coordinator
    PomodoroCloudSync.swift          # CloudKit backend implementation
    PomodoroSharedModels.swift       # Sync data models (PomodoroSharedState, PomodoroPreferencesSnapshot)
    PomodoroInterfaces.swift         # Protocols (PomodoroSyncManaging, PomodoroBlocking, etc.)
    StatsStore.swift                 # Session recording & aggregation
    PomodoroActivityAttributes.swift # Live Activity definitions
    EntitlementChecker.swift         # CloudKit entitlement validation
    Blocking/
      PomodoroBlocker_iOS.swift      # FamilyControls + ManagedSettings
      PomodoroBlocker_macOS.swift    # Delegates to iOS via URL scheme
  PomafocusWidgetKit/
    WidgetState.swift                # Widget state & commands via App Group
  Pomafocus/                         # macOS menu bar app sources
    AppDelegate.swift
    StatusBarController.swift
    PomodoroSettings.swift
    HotkeyManager.swift / Hotkey.swift
    PreferencesWindowController.swift

apps/
  ios/
    Sources/                         # iOS SwiftUI app
      PomafocusiOSApp.swift          # @main entry point
      PomafocusCore.swift            # Singleton coordinator
      ContentView.swift
      PomodoroDashboardView.swift
      PomodoroBlockingPanel.swift
      ScheduleStore.swift            # Focus schedules + block lists
      ScheduleCoordinator.swift      # Automated schedule monitoring
      ScheduleModels.swift
      PomodoroExperienceCoordinator.swift  # Live Activities
    Widgets/                         # Live Activity extension
    HomeWidgets/                     # Home/Lock screen widgets
    project.yml                      # XcodeGen manifest
  macos/
    project.yml
    PrivilegedHelper/                # XPC helper (infrastructure for future blocking)
  shared/Sources/                    # Shared SwiftUI views (brutalist theme)

Tests/PomafocusKitTests/             # Swift Testing (@Test macros)
Scripts/                             # Build, generation, signing scripts
```

## Core Components

### PomodoroTimer
Injectable timer engine. Configurable clock and ticker for testability. Fires `onTick` every second, tracks elapsed time from `startedAt` date. Used by `PomodoroSessionController`.

### PomodoroSessionController
Main orchestrator. `@MainActor`, `ObservableObject`. Published state: `minutes`, `isRunning`, `remaining`, `deepBreathEnabled`, `deepBreathRemaining`, `deepBreathReady`, `sessionTag`, `sessionOrigin`.

**Session lifecycle:**
1. `toggleTimer()` - start/stop with optional deep breath phase
2. `startSession()` - starts timer, enables blocker, publishes sync state, updates widgets
3. Timer ticks update `remaining`
4. On completion/stop - records stats, disables blocker, publishes state

**Deep Breath feature:** 30-second controlled breathing countdown before stopping. After breathing completes, 60-second confirmation window. User must confirm to complete; timeout dismisses.

**External integration:** `applyExternalState()` receives remote sync changes. `checkWidgetCommands()` polls widget for start/stop commands.

### PomodoroSyncManager
Dual-backend cross-device sync. Primary: CloudKit with silent push subscriptions. Fallback: NSUbiquitousKeyValueStore.

Each device has a UUID `deviceIdentifier`. Both state and preferences include `originIdentifier` to prevent echo (ignores changes from own device).

**CloudKit details:**
- Container: `iCloud.com.staskus.pomafocus` (from Info.plist)
- Private database, record types: `PomodoroState`, `PomodoroPreferences`
- Query subscriptions with silent push (`shouldSendContentAvailable`)
- Graceful degradation if CloudKit unavailable

**KVS fallback:**
- Keys: `pomafocus.shared.state`, `pomafocus.shared.preferences`
- JSON-encoded, slower sync via iCloud Drive

### StatsStore
`@MainActor` singleton. Records `FocusSessionSummary` (start, end, duration, outcome, tag). Tracks deep breath events. Aggregation: `dailyRollups()`, `weeklySummary()`, `currentStreakDays()`. Persists to App Group UserDefaults (`group.com.staskus.pomafocus`).

### Blocking

**iOS:** `FamilyControls` + `ManagedSettings`. Requires Screen Time authorization. Applies/clears shield on selected apps, web domains, categories. Separate blocking for manual sessions vs scheduled blocks.

**macOS:** No direct blocking. Sends URL scheme commands (`pomafocus://block-on`, `pomafocus://block-off`) to iOS companion app (`com.povilasstaskus.pomafocus.ios`).

## Data Models

**Sync:**
- `PomodoroSharedState` - duration, startedAt, isRunning, updatedAt, originIdentifier
- `PomodoroPreferencesSnapshot` - minutes, deepBreathEnabled, updatedAt, originIdentifier

**Stats:**
- `FocusSessionSummary` - id, startedAt, endedAt, durationSeconds, outcome (.completed/.stopped), tag
- `DailyFocusStats` - date, totals, completion/deep-breath rates
- `WeeklyFocusSummary` - 7-day aggregates with streak

**Widget:**
- `WidgetTimerState` - full timer state for widget rendering (progress, statusLabel computed)

**Schedule (iOS):**
- `FocusSchedule` - named schedule with enabled flag and blocks
- `ScheduleBlock` - titled block with kind (.focus/.break), time range, weekdays, optional block list
- `BlockList` - named FamilyActivitySelection for reuse

## iOS App

Entry point: `PomafocusiOSApp`. `PomafocusCore.shared` singleton owns `PomodoroSessionController`, `ScheduleStore`, coordinates experiences and schedules.

**URL schemes:** `pomafocus://start`, `stop`, `toggle`, `block-on`, `block-off`, `screen-time`

**Widget communication:** `WidgetStateManager` reads/writes to App Group UserDefaults. Polled every 0.5 seconds for commands.

**Live Activities:** `PomodoroExperienceCoordinator` manages Lock Screen / Dynamic Island display with live countdown, progress bar, status badges (FOCUS/READY/BREATHE/CONFIRM).

## macOS App

Menu bar accessory (`.accessory` activation policy, headless). `StatusBarController` shows timer in menu bar, plays sounds. `HotkeyManager` binds global hotkey (default Cmd+Ctrl+P). `PreferencesWindowController` for settings.

Uses same `PomodoroSessionController` and `PomodoroSyncManager` as iOS. Blocking delegated to iOS companion.

**Privileged Helper:** XPC infrastructure exists (`com.staskus.pomafocus.mac.helper`) for future /etc/hosts blocking, not actively used.

## Testing

Swift Testing framework with `@Test` macros. Injectable dependencies: `MockTicker`, `MockSyncManager`, `MockBlocker` enable deterministic testing without real CloudKit/FamilyControls.

Test suites: `PomodoroTimerTests`, `PomodoroSessionControllerTests`, `PomodoroSyncManagerTests`, `PomodoroBlockerMacOSTests`.

## Bundle Identifiers

| Target | Bundle ID |
|--------|-----------|
| macOS app | `com.staskus.pomafocus.mac` |
| iOS app | `com.povilasstaskus.pomafocus.ios` |
| iOS Activities | `com.povilasstaskus.pomafocus.ios.activities` |
| iOS Home Widgets | `com.povilasstaskus.pomafocus.ios.homewidgets` |
| macOS Helper | `com.staskus.pomafocus.mac.helper` |
| App Group | `group.com.staskus.pomafocus` |
| iCloud Container | `iCloud.com.staskus.pomafocus` |
