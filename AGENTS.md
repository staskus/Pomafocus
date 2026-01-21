# Platform Guidelines (iOS & macOS)

## Repo Workflow
- Follow the repo-level conventions in `CLAUDE.md` (git workflow, signing environment, and build commands).

## Build & Project Generation
- **macOS:** open `Package.swift` in Xcode or run `swift run Pomafocus` during development. Use `./Scripts/build_app.sh` when you need a distributable `.app` bundle and always test the fresh bundle before sharing it.
- **iOS:** the SwiftUI companion lives in `apps/ios`. Generate the Xcode project with `./Scripts/generate_ios_project.sh` (requires `brew install xcodegen`) and remember that the resulting `.xcodeproj` is disposable—regenerate it whenever the manifest changes rather than committing it.
- Both platforms share the Swift package in `Sources/`, so rebuild both sides whenever you touch `PomafocusKit` or the sync layer.

## Coding Style
- SwiftUI view/state work should prefer Apple’s Observation framework (`@Observable`, `@Bindable`) instead of `ObservableObject` / `@StateObject` unless a legacy API forces it.

## Testing & Devices
- Before reaching for a simulator, confirm whether a real iOS device is connected and prefer it when possible. Simulators are acceptable when hardware isn’t available, but the final smoke test should run on-device.
- “Restart the app” means rebuild/install and relaunch (macOS menu bar + iOS) — don’t just force quit and reopen the previous binary.

## Signing & Capabilities
- If you ever need the Apple Development team ID, run `security find-identity -p codesigning -v` and use the `Apple Development` identity (current default: `L4KYCD4RPZ`). That team ID must line up with the bundle identifiers declared in `apps/ios/project.yml` and the macOS entitlements in `Resources/Info.plist`.
- iCloud + push entitlements are already included for both apps; when creating new targets or sample projects, copy the existing entitlement settings (Key-Value sync relies on `com.apple.developer.ubiquity-kvstore-identifier` matching the bundle ID).

## After Each Code Change

Follow this workflow after making any code changes:

1. **Run tests:** `swift test`
2. **Regenerate Xcode projects:** `cd apps && xcodegen generate`
3. **Verify success:** Both steps must pass without errors
4. **Commit & push:** Only if tests pass and xcodegen succeeds

```sh
swift test && cd apps && xcodegen generate && cd .. && git add -A && git commit -m "Your message" && git push
```
