#if os(macOS)
import Foundation
import Testing
@testable import PomafocusKit

@MainActor
@Suite struct PomodoroBlockerMacOSTests {
    @Test func initialStateHasNoSelection() {
        let blocker = PomodoroBlocker(defaults: isolatedDefaults(), hostsModifier: MockHostsModifier())
        #expect(blocker.hasSelection == false)
        #expect(blocker.selectionSummary == "No domains selected")
        #expect(blocker.blockedDomains.isEmpty)
    }

    @Test func addAndRemoveDomains() {
        let blocker = PomodoroBlocker(defaults: isolatedDefaults(), hostsModifier: MockHostsModifier())

        blocker.addDomain("x.com")
        blocker.addDomain("youtube.com")
        #expect(blocker.blockedDomains == ["x.com", "youtube.com"])
        #expect(blocker.hasSelection == true)
        #expect(blocker.selectionSummary == "2 domains blocked")

        blocker.removeDomain("x.com")
        #expect(blocker.blockedDomains == ["youtube.com"])
        #expect(blocker.selectionSummary == "1 domain blocked")
    }

    @Test func addDomainNormalizesAndDeduplicates() {
        let blocker = PomodoroBlocker(defaults: isolatedDefaults(), hostsModifier: MockHostsModifier())

        blocker.addDomain("  X.COM  ")
        #expect(blocker.blockedDomains == ["x.com"])

        blocker.addDomain("x.com")
        #expect(blocker.blockedDomains == ["x.com"])

        blocker.addDomain("")
        #expect(blocker.blockedDomains == ["x.com"])
    }

    @Test func domainsPersistToDefaults() {
        let defaults = isolatedDefaults()
        let blocker = PomodoroBlocker(defaults: defaults, hostsModifier: MockHostsModifier())
        blocker.addDomain("test.com")

        let restored = PomodoroBlocker(defaults: defaults, hostsModifier: MockHostsModifier())
        #expect(restored.blockedDomains == ["test.com"])
    }

    @Test func beginBlockingCallsHostsModifier() {
        let mock = MockHostsModifier()
        let blocker = PomodoroBlocker(defaults: isolatedDefaults(), hostsModifier: mock)

        blocker.addDomain("x.com")
        blocker.addDomain("youtube.com")
        blocker.beginBlocking()

        #expect(mock.applyCount == 1)
        #expect(mock.lastDomains == ["x.com", "youtube.com"])
    }

    @Test func endBlockingCallsHostsModifier() {
        let mock = MockHostsModifier()
        let blocker = PomodoroBlocker(defaults: isolatedDefaults(), hostsModifier: mock)

        blocker.addDomain("x.com")
        blocker.beginBlocking()
        blocker.endBlocking()

        #expect(mock.clearCount == 1)
    }

    @Test func endBlockingIsIdempotent() {
        let mock = MockHostsModifier()
        let blocker = PomodoroBlocker(defaults: isolatedDefaults(), hostsModifier: mock)

        blocker.addDomain("x.com")
        blocker.beginBlocking()
        blocker.endBlocking()
        blocker.endBlocking()

        #expect(mock.clearCount == 1)
    }

    @Test func beginBlockingSkipsWhenNoDomains() {
        let mock = MockHostsModifier()
        let blocker = PomodoroBlocker(defaults: isolatedDefaults(), hostsModifier: mock)

        blocker.beginBlocking()
        #expect(mock.applyCount == 0)
    }

    @Test func hostsBlockContentGeneration() {
        let content = PomodoroBlocker.hostsBlockContent(for: ["x.com", "test.org"])
        let expected = """
        # POMAFOCUS BLOCK START
        127.0.0.1 x.com
        ::1 x.com
        127.0.0.1 test.org
        ::1 test.org
        # POMAFOCUS BLOCK END
        """
        #expect(content == expected)
    }

    @Test func conformsToPomodoroBlocking() {
        let blocker = PomodoroBlocker(defaults: isolatedDefaults(), hostsModifier: MockHostsModifier())
        let blocking: any PomodoroBlocking = blocker
        #expect(blocking.hasSelection == false)
        blocking.beginBlocking()
        blocking.endBlocking()
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "PomodoroBlockerMacOSTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
#endif
