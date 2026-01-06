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

## Website blocking

Open the Preferences window from the status item to enter the list of domains you want blocked whenever a focus session is running on macOS. The app updates `/etc/hosts` under the hood, so macOS will prompt for administrator access the first time you start a session with website blocking enabled. When a session stops, the entries are removed automatically.
