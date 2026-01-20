# Pomafocus - Claude Code Instructions

## Git Workflow

- Always commit and push changes after completing tasks
- Do not add co-author lines to commits
- Do not mention Claude Code in commit messages
- Use conventional commit style (fix:, feat:, refactor:, etc.)

## Project Structure

- **Sources/PomafocusKit/** - Shared Swift package (timer, sync, models)
- **apps/ios/** - iOS app with XcodeGen manifest
- **apps/macos/** - macOS menu bar app
- **Scripts/** - Build and setup scripts

## Build Commands

```sh
# Generate iOS project
./Scripts/generate_ios_project.sh

# Generate macOS project
./Scripts/generate_macos_project.sh

# Run tests
swift test
```

## Signing Setup

Signing uses Fastlane with environment-based configuration in `apps/ios/.env` (gitignored).

Required environment variables:
- `APPLE_ID` - Apple Developer email
- `TEAM_ID` - Apple Developer Team ID
- `BUNDLE_ID_PREFIX` - Base bundle identifier
- `APP_GROUP_ID` - App Group identifier
- `ICLOUD_CONTAINER_ID` - iCloud container identifier

Run `./Scripts/setup_signing.sh` to register App Groups, App IDs, and generate provisioning profiles.

## Key Files

- `apps/ios/project.yml` - XcodeGen manifest for iOS targets
- `apps/ios/.env.example` - Environment template (committed)
- `apps/ios/.env` - Actual credentials (gitignored)
- `apps/ios/fastlane/Fastfile` - Signing automation lanes

## Testing

Always run `swift test` before committing to verify shared logic works correctly.
