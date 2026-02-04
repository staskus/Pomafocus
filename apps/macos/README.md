# Pomafocus (macOS)

Menu bar host for the shared Pomodoro timer. The project is generated via XcodeGen so the `.xcodeproj` stays disposable.

## Requirements
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (installed via `brew install xcodegen`)

## Generate the Xcode project
```bash
./Scripts/generate_macos_project.sh
open apps/macos/PomafocusMac.xcodeproj
```

The scheme builds the familiar status-item app using the sources in `Sources/Pomafocus` while linking against `PomafocusKit`. Use this project if you want an app target inside Xcode instead of the plain Swift Package workflow.

## Build distributable artifacts

```bash
./Scripts/build_macos_apps.sh
```

This produces:
- `dist/macos/PomafocusMac.app` (the actual status bar app)
- `dist/macos/OpenPomafocus.command` (launcher that opens `PomafocusMac.app` and the optional companion app if installed)

The same files are copied to `~/Downloads/Pomafocus-Builds`.

## Screen Time blocking on macOS

Native macOS cannot enforce iOS-style FamilyControls/ManagedSettings shielding directly. PomafocusMac therefore delegates Screen Time blocking to the companion iOS app when available.
