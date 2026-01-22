## Pomafocus

Modern SwiftUI Pomodoro client for iOS plus a native AppKit menu bar companion on macOS.

### Requirements

- **iOS:** 18.0+
- **macOS:** 13.0+
- **Swift:** 6.0 toolchain
- **Xcode:** 16.0+

### Features

- A shared gradient UI, progress ring, and Screen Time selector on iOS.
- CloudKit-backed state/preferences sync plus NSUbiquitousKeyValueStore fallback.
- Live Activities on iPhone (Lock Screen + Dynamic Island) that continue even when the session originates on macOS.
- Menu bar time indicator plus a global `⌘⌃P` hotkey on macOS.
- Optional "Deep Breath" safety toggle that forces a 30-second pause before manual stops, followed by a 60-second confirmation window; synced between devices.
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
- **PomafocusTemp** – disposable iOS app for `getios` manual-signing tests (see `apps/ios-temp`).

## Signing Setup

Signing is managed via Fastlane with environment-based configuration. This allows anyone to build the project with their own Apple Developer account.

### First-time Setup

1. Copy the environment template:
   ```sh
   cp apps/ios/.env.example apps/ios/.env
   ```

2. Edit `apps/ios/.env` with your Apple Developer credentials:
   ```
   APPLE_ID=your.email@example.com
   TEAM_ID=XXXXXXXXXX
   BUNDLE_ID_PREFIX=com.yourcompany.pomafocus
   APP_GROUP_ID=group.com.yourcompany.pomafocus
   ICLOUD_CONTAINER_ID=iCloud.com.yourcompany.pomafocus
   ```

3. Run the signing setup script:
   ```sh
   ./Scripts/setup_signing.sh
   ```

This will automatically:
- Register the App Group in Apple Developer Portal
- Create all required App IDs with capabilities (Push, iCloud, App Groups)
- Associate App Groups with the main app and widgets
- Generate development provisioning profiles

After setup completes, regenerate the Xcode project and build as usual.

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

Build/run the `PomafocusMac` scheme on the `My Mac` destination. The app runs headless in the menu bar, registers the global hotkey, and exposes Preferences for session tuning.

### Swift Package Tests

Shared logic lives under `PomafocusKit` and ships with Swift Testing suites:

```sh
swift test
```

The suite covers the ticker/timer engine, sync manager, and the higher-level `PomodoroSessionController` (with injectable timers/blockers for deterministic tests).

## CloudKit & Sync

CloudKit is enabled in Release by default; Debug can flip it via the Info.plist overrides in `project.yml`. Every state change publishes a record and the app registers silent push subscriptions so other devices refresh immediately (including when the app is backgrounded). Signing every target with the same Apple ID + iCloud container (`iCloud.com.staskus.pomafocus`) is mandatory for the fast path.

If the entitlement or container is unavailable, the app drops back to NSUbiquitousKeyValueStore (still synced via iCloud Drive, just slower and without push wakes).

## Screen Time Blocking (iOS)

Only the iOS app integrates with `FamilyControls`/`ManagedSettings`. Open **Block distractions…** to choose apps, domains, or categories to shield whenever a session is active on that device. Silent CloudKit pushes keep the selector in sync, so blocking automatically starts/stops even when a session begins on macOS, but the macOS app currently does not perform local blocking.

## Live Activities (iOS)

The `PomafocusActivities` widget delivers a Lock Screen/Dynamic Island status view with the remaining time and progress bar. The main target opts into `NSSupportsLiveActivities` so ActivityKit can continue updating even when the UI is backgrounded; CloudKit pushes wake the app so the Live Activity mirrors macOS timers too.
