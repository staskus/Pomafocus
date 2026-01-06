## Pomafocus

Modern SwiftUI Pomodoro client for iOS plus a native AppKit menu bar companion on macOS:

- A shared gradient UI, progress ring, and Screen Time selector on iOS.
- CloudKit-backed state/preferences sync plus NSUbiquitousKeyValueStore fallback.
- Live Activities on iPhone (Lock Screen + Dynamic Island) that continue even when the session originates on macOS.
- Menu bar time indicator, a global `⌘⌃P` hotkey, and hosts-based website blocking on macOS.
- Screen Time-based app/site blocking on iOS (per-device selections) that follow remote sessions via silent push.

## Projects & Tooling

Everything flows from the Swift package in `Sources/` and the XcodeGen manifests in `apps/`. Regenerate the disposable projects/workspace whenever manifests or shared sources change:

```sh
cd apps && xcodegen generate
# or run the helper script
./Scripts/generate_workspace.sh
open apps/Pomafocus.xcworkspace
```

The workspace exposes two schemes:

- **Pomafocus** – iOS app + Live Activity widget extension.
- **PomafocusMac** – AppKit menu bar host that links against `PomafocusKit`.

Signing is configured for team `L4KYCD4RPZ`. If you need to switch accounts, update `project.yml` + entitlements before regenerating.

## Running & Testing

### iOS

```sh
./Scripts/generate_ios_project.sh
open apps/ios/Pomafocus.xcodeproj
```

Select the `Pomafocus` scheme, choose a device/simulator, and run. Enable “Background Modes → Remote notifications” during development so CloudKit push refreshes keep the Live Activity in sync.

### macOS

```sh
./Scripts/generate_macos_project.sh
open apps/macos/PomafocusMac.xcodeproj
```

Build/run the `PomafocusMac` scheme on the `My Mac` destination. The app runs headless in the menu bar, registers the global hotkey, and exposes Preferences for session tuning plus website blocking (editing the hosts file requires admin approval the first time you run a session with sites configured).

### Swift Package Tests

Shared logic lives under `PomafocusKit` and ships with Swift Testing suites:

```sh
swift test
```

The suite covers the ticker/timer engine, sync manager, and the higher-level `PomodoroSessionController` (with injectable timers/blockers for deterministic tests).

## CloudKit & Sync

CloudKit is enabled in Release by default; Debug can flip it via the Info.plist overrides in `project.yml`. Every state change publishes a record and the app registers silent push subscriptions so other devices refresh immediately (including when the app is backgrounded). Signing every target with the same Apple ID + iCloud container (`iCloud.com.staskus.pomafocus`) is mandatory for the fast path.

If the entitlement or container is unavailable, the app drops back to NSUbiquitousKeyValueStore (still synced via iCloud Drive, just slower and without push wakes).

## Screen Time & Website Blocking

On iOS the shared `PomodoroBlocker` wraps `FamilyControls`/`ManagedSettings`. Open **Block distractions…** in the mobile app to choose apps, domains, or categories to shield whenever a session is active on that device. Silent CloudKit pushes keep the selector in sync, so blocking automatically starts/stops even when a session begins on macOS.

On macOS the menu bar build stores a per-device domain list. Whenever a session starts it rewrites `/etc/hosts` (between `# BEGIN POMAFOCUS` and `# END POMAFOCUS`) to point those domains to `localhost`, flushes DNS, and restores the pristine file as soon as the focus session ends. Because this requires elevated privileges, macOS prompts for administrator approval the first time you run a blocked session.

## Live Activities (iOS)

The `PomafocusActivities` widget delivers a Lock Screen/Dynamic Island status view with the remaining time and progress bar. The main target opts into `NSSupportsLiveActivities` so ActivityKit can continue updating even when the UI is backgrounded; CloudKit pushes wake the app so the Live Activity mirrors macOS timers too.
