# Pomafocus (iOS)

SwiftUI companion that mirrors the macOS timer state through `PomafocusKit`.

## Requirements
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Generate the Xcode project
```bash
./Scripts/generate_ios_project.sh
open apps/ios/Pomafocus.xcodeproj
```

## Build & Run
Select the `Pomafocus` scheme in Xcode, choose an iPhone/iPad destination (or a plugged-in device), and hit Run. The app links against the shared Swift package at the repo root, so rebuild the mac target or `swift build` after making shared changes.

## Signing & OTA Builds
- Fastlane manages development + ad-hoc signing via `apps/ios/.env` and `fastlane/Fastfile` (run `bundle exec fastlane ios setup_signing` to generate profiles).
- Debug uses development profiles; Release uses ad-hoc profiles for OTA installs.
- For OTA installs with `getios`, use manual signing and an ad-hoc export method (for example: `getios build --manual-signing --export-method ad-hoc`).
- If `Pomafocus.entitlements` includes Family Controls, ensure Fastlane enables the `family_controls` capability on the main App ID before generating profiles.
- Ad-hoc profiles do not support the Family Controls entitlement, so Release builds use `PomafocusAdHoc.entitlements` (without Family Controls). Use Debug + development signing when you need that capability.
