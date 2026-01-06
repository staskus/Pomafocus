import Foundation
import Testing
@testable import PomafocusKit

@MainActor
@Suite struct PomodoroTimerTests {
    @Test func startSetsStateAndRemaining() {
        let timer = PomodoroTimer()
        var stateChanges: [Bool] = []
        var initialTick: TimeInterval?

        timer.onStateChange = { stateChanges.append($0) }
        timer.onTick = { remaining in
            if initialTick == nil {
                initialTick = remaining
            }
        }

        timer.start(duration: 5)

        #expect(timer.isRunning == true)
        #expect((initialTick ?? 0) > 0)
        #expect(stateChanges == [true])
    }

    @Test func stopEmitsStateChangeAndClearsRemaining() {
        let timer = PomodoroTimer()
        var stateChanges: [Bool] = []
        timer.onStateChange = { stateChanges.append($0) }

        timer.start(duration: 5)
        timer.stop()

        #expect(stateChanges == [true, false])
        #expect(timer.isRunning == false)
        #expect(timer.remaining == 0)
    }
}
