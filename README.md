## Pomafocus

A lightweight macOS menu bar Pomodoro timer with configurable session length and a global hotkey toggle.

### macOS (Swift Package)

```sh
swift run
```

### Bundling into an `.app`

Create a distributable app bundle (with Info.plist and icon) by running:

```sh
./Scripts/build_app.sh
```

The script outputs `dist/Pomafocus.app`, which you can drag into `/Applications`. The bundle inherits the accessory-style behavior (dock-less window) from the executable, so it lives solely in the menu bar once launched.

### iOS App (XcodeGen)

The SwiftUI companion lives under `apps/ios`. Generate the project on demand:

```sh
./Scripts/generate_ios_project.sh
open apps/ios/Pomafocus.xcodeproj
```

Select the `Pomafocus` scheme, choose any iPhone/iPad destination (or a plugged-in device), and run. The project references the shared Swift package at the repo root, so macOS + iOS stay in sync automatically.

### iCloud Sync Setup

Both apps rely on `NSUbiquitousKeyValueStore` for sync, which requires iCloud Key-Value storage to be enabled:

1. In Xcode, open the mac bundle (created with `Scripts/build_app.sh`) and the iOS project, configure their bundle identifiers, and enable the iCloud capability with Key-Value storage for your team.
2. Use the same Apple ID/iCloud account on every device; the shared data key namespace is `com.staskus.pomafocus`.
3. After enabling the capability, rebuild/reinstall both apps so that iCloud entitlements are applied. Once signed in, starting/stopping timers or adjusting the duration on either platform will update the other within a few seconds.
*** End Patch*** End Patch
