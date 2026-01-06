import Foundation
import Testing
@testable import PomafocusKit

@MainActor
@Suite struct PomodoroTimerTests {
    @Test func startSetsStateAndRemaining() {
        let ticker = MockTicker()
        let currentDate = Date()
        let timer = PomodoroTimer(now: { currentDate }, ticker: ticker)
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
        let ticker = MockTicker()
        let timer = PomodoroTimer(now: Date.init, ticker: ticker)
        var stateChanges: [Bool] = []
        timer.onStateChange = { stateChanges.append($0) }

        timer.start(duration: 5)
        timer.stop()

        #expect(stateChanges == [true, false])
        #expect(timer.isRunning == false)
        #expect(timer.remaining == 0)
    }

    @Test func completionFiresWhenElapsed() async {
        let ticker = MockTicker()
        var currentDate = Date()
        let timer = PomodoroTimer(now: { currentDate }, ticker: ticker)

        var completions = 0
        var stateChanges: [Bool] = []
        timer.onCompletion = { completions += 1 }
        timer.onStateChange = { stateChanges.append($0) }

        timer.start(duration: 3, startDate: currentDate)
        #expect(ticker.handler != nil)

        currentDate = currentDate.addingTimeInterval(3)
        ticker.fire()
        await Task.yield()
        await Task.yield()
        #expect(completions == 1)
        #expect(stateChanges == [true, false])
        #expect(timer.isRunning == false)
        #expect(timer.remaining == 0)
    }
}

@MainActor
private final class MockTicker: PomodoroTicker {
    var handler: (@MainActor () -> Void)?
    private(set) var invalidateCount = 0

    func schedule(interval: TimeInterval, handler: @escaping @MainActor () -> Void) -> PomodoroTickerToken {
        self.handler = handler
        return MockToken { [weak self] in
            self?.invalidateCount += 1
        }
    }

    func fire() {
        handler?()
    }

    private struct MockToken: PomodoroTickerToken {
        let onInvalidate: () -> Void
        func invalidate() { onInvalidate() }
    }
}
