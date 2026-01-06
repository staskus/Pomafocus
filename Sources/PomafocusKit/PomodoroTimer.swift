import Foundation

@MainActor
public final class PomodoroTimer {
    public var onTick: ((TimeInterval) -> Void)?
    public var onStateChange: ((Bool) -> Void)?
    public var onCompletion: (() -> Void)?

    private var timer: Timer?
    private var endDate: Date?
    public private(set) var remaining: TimeInterval = 0
    public private(set) var isRunning = false

    public init() {}

    public func start(duration: TimeInterval, startDate: Date = Date()) {
        stop()
        guard duration > 0 else { return }
        let endDate = startDate.addingTimeInterval(duration)
        let remaining = max(0, endDate.timeIntervalSinceNow)
        self.endDate = endDate
        self.remaining = remaining
        isRunning = true
        updateTick()
        onStateChange?(true)
        scheduleTimer()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        remaining = 0
        if isRunning {
            isRunning = false
            onStateChange?(false)
        }
    }

    private func scheduleTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.handleTick()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    @objc private func handleTick() {
        guard let endDate else {
            stop()
            return
        }
        remaining = max(0, endDate.timeIntervalSinceNow)
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
