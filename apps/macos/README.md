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
