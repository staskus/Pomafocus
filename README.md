## Pomafocus

A lightweight macOS menu bar Pomodoro timer with configurable session length and a global hotkey toggle.

### Running

```sh
swift run
```

### Bundling into an `.app`

Create a distributable app bundle (with Info.plist and icon) by running:

```sh
./Scripts/build_app.sh
```

The script outputs `dist/Pomafocus.app`, which you can drag into `/Applications`. The bundle inherits the accessory-style behavior (dock-less window) from the executable, so it lives solely in the menu bar once launched.

### Xcode App Targets

An Xcode workspace lives under `iOSApp/PomafocusiOS.xcodeproj` and now ships with two targets:

- `PomafocusMac` — the menu bar app wired up for macOS signing/iCloud/Push. Select the scheme, choose My Mac (or a connected Mac via Playgrounds), and build/run directly from Xcode instead of using `swift run`.
- `PomafocusiOS` — the SwiftUI companion for iPhone/iPad. Pick a simulator or physical device and hit Run to toggle the shared timer and adjust duration.

### iCloud Sync Setup

Both apps rely on `NSUbiquitousKeyValueStore` for sync, which requires iCloud Key-Value storage to be enabled:

1. In Xcode, open the mac bundle (created with `Scripts/build_app.sh`) and the iOS project, configure their bundle identifiers, and enable the iCloud capability with Key-Value storage for your team.
2. Use the same Apple ID/iCloud account on every device; the shared data key namespace is `com.staskus.pomafocus`.
3. After enabling the capability, rebuild/reinstall both apps so that iCloud entitlements are applied. Once signed in, starting/stopping timers or adjusting the duration on either platform will update the other within a few seconds.
*** End Patch*** End Patch
