import AppKit

final class PomodoroTimer {
    var onTick: ((TimeInterval) -> Void)?
    var onStateChange: ((Bool) -> Void)?
    var onCompletion: (() -> Void)?

    private var timer: Timer?
    private(set) var remaining: TimeInterval = 0
    private(set) var isRunning = false

    func start(duration: TimeInterval) {
        stop()
        guard duration > 0 else { return }
        remaining = duration
        isRunning = true
        updateTick()
        onStateChange?(true)
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(handleTick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        remaining = 0
        if isRunning {
            isRunning = false
            onStateChange?(false)
        }
    }

    @objc private func handleTick() {
        remaining -= 1
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
        NSSound(named: NSSound.Name("Glass"))?.play()
    }
}
