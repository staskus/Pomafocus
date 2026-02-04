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
            }
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
            openURL: { _ in false }
        )
        blocker.setScreenTimeCompanionEnabled(true)
        #expect(blocker.openScreenTimeSettings() == false)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "PomodoroBlockerMacOSTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
#endif
