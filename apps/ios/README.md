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
