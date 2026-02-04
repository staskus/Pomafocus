#if os(macOS)
import Foundation
import Testing
@testable import PomafocusKit

@MainActor
@Suite struct PomodoroBlockerMacOSTests {
    @Test func usesCompanionCommandsWhenEnabled() {
        let defaults = isolatedDefaults()
        var openedHosts: [String] = []
        let blocker = PomodoroBlocker(
            defaults: defaults,
            openURL: { url in
                openedHosts.append(url.host ?? "")
                return true
            },
            canOpenCommandURL: { _ in true },
            openCommandWithCompanion: { _ in false },
            launchCompanionApp: { false }
        )

        blocker.beginBlocking()
        #expect(openedHosts.isEmpty)
        #expect(blocker.hasSelection == false)

        blocker.setScreenTimeCompanionEnabled(true)
        #expect(blocker.hasSelection == true)
        #expect(blocker.selectionSummary == "Screen Time via companion app")

        blocker.beginBlocking()
        blocker.endBlocking()
        let openedSettings = blocker.openScreenTimeSettings()

        #expect(openedHosts == ["block-on", "block-off", "screen-time"])
        #expect(openedSettings == true)
    }

    @Test func reportsFailureWhenURLCommandCannotBeOpened() {
        let blocker = PomodoroBlocker(
            defaults: isolatedDefaults(),
            openURL: { _ in false },
            canOpenCommandURL: { _ in true },
            openCommandWithCompanion: { _ in false },
            launchCompanionApp: { false }
        )
        blocker.setScreenTimeCompanionEnabled(true)
        #expect(blocker.openScreenTimeSettings() == false)
    }

    @Test func launchesCompanionWhenCustomURLSchemeUnavailable() {
        var launchCount = 0
        let blocker = PomodoroBlocker(
            defaults: isolatedDefaults(),
            openURL: { _ in
                Issue.record("openURL should not be called when command URL has no handler")
                return false
            },
            canOpenCommandURL: { _ in false },
            openCommandWithCompanion: { _ in false },
            launchCompanionApp: {
                launchCount += 1
                return true
            }
        )

        blocker.setScreenTimeCompanionEnabled(true)
        blocker.beginBlocking()
        blocker.openScreenTimeSettings()

        #expect(launchCount == 2)
    }

    @Test func usesCompanionBundleToOpenCommandWhenSchemeHasNoGlobalHandler() {
        var receivedHosts: [String] = []
        let blocker = PomodoroBlocker(
            defaults: isolatedDefaults(),
            openURL: { _ in
                Issue.record("openURL should not be called when command URL has no global handler")
                return false
            },
            canOpenCommandURL: { _ in false },
            openCommandWithCompanion: { url in
                receivedHosts.append(url.host ?? "")
                return true
            },
            launchCompanionApp: {
                Issue.record("launchCompanionApp should not run when opening URL via companion succeeds")
                return false
            }
        )

        blocker.setScreenTimeCompanionEnabled(true)
        blocker.beginBlocking()
        blocker.endBlocking()

        #expect(receivedHosts == ["block-on", "block-off"])
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "PomodoroBlockerMacOSTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
#endif
