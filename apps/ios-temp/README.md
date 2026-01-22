# Pomafocus Temp (iOS)

Disposable SwiftUI app for validating `getios` manual-signing installs.

## Notes

- Uses the same bundle identifier as the main app (`com.povilasstaskus.pomafocus.ios`) so it can reuse the existing manual signing profiles.
- Installing this build replaces Pomafocus on-device. Reinstall Pomafocus afterwards.

## Build

Generate the Xcode project, then build with getios:

```sh
cd apps/ios-temp
xcodegen generate
getios build --manual-signing --export-method ad-hoc
```
