import Foundation

public protocol PomodoroTickerToken {
    func invalidate()
}

public protocol PomodoroTicker {
    @MainActor
    func schedule(interval: TimeInterval, handler: @escaping @MainActor () -> Void) -> PomodoroTickerToken
}

@MainActor
public final class PomodoroTimer {
    public var onTick: ((TimeInterval) -> Void)?
    public var onStateChange: ((Bool) -> Void)?
    public var onCompletion: (() -> Void)?

    private let now: () -> Date
    private let ticker: PomodoroTicker
    private var tickerToken: PomodoroTickerToken?
    private var endDate: Date?
    public private(set) var remaining: TimeInterval = 0
    public private(set) var isRunning = false

    public init(
        now: @escaping () -> Date = Date.init,
        ticker: PomodoroTicker? = nil
    ) {
        self.now = now
        self.ticker = ticker ?? DefaultPomodoroTicker()
    }

    public func start(duration: TimeInterval, startDate: Date = Date()) {
        stop()
        guard duration > 0 else { return }
        let endDate = startDate.addingTimeInterval(duration)
        let remaining = max(0, endDate.timeIntervalSince(now()))
        self.endDate = endDate
        self.remaining = remaining
        isRunning = true
        updateTick()
        onStateChange?(true)
        scheduleTimer()
    }

    public func stop() {
        tickerToken?.invalidate()
        tickerToken = nil
        endDate = nil
        remaining = 0
        if isRunning {
            isRunning = false
            onStateChange?(false)
        }
    }

    private func scheduleTimer() {
        guard tickerToken == nil else { return }
        tickerToken = ticker.schedule(interval: 1) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.handleTick()
            }
        }
    }

    private func handleTick() {
        guard let endDate else {
            stop()
            return
        }
        remaining = max(0, endDate.timeIntervalSince(now()))
        if remaining <= 0 {
            finish()
        } else {
            updateTick()
        }
    }

    private func updateTick() {
        onTick?(remaining)
    }

    private func finish() {
        stop()
        onCompletion?()
    }
}

@MainActor
final class DefaultPomodoroTicker: PomodoroTicker {
    func schedule(interval: TimeInterval, handler: @escaping @MainActor () -> Void) -> PomodoroTickerToken {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                handler()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        return TimerTickerToken(timer: timer)
    }

    private struct TimerTickerToken: PomodoroTickerToken {
        let timer: Timer

        func invalidate() {
            timer.invalidate()
        }
    }
}
