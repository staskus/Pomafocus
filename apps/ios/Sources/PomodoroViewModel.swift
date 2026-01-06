import AudioToolbox
import Foundation
import PomafocusKit

@MainActor
final class PomodoroViewModel: ObservableObject {
    @Published var minutes: Int
    @Published var remainingDisplay: String
    @Published var isRunning: Bool

    private let timer = PomodoroTimer()
    private let syncManager = PomodoroSyncManager.shared
    private var activeDuration: Int = 0

    init() {
        syncManager.start()
        let preferences = syncManager.currentPreferences()
        let initialMinutes = preferences.minutes
        minutes = initialMinutes
        remainingDisplay = PomodoroViewModel.format(seconds: initialMinutes * 60)
        let state = syncManager.currentState()
        isRunning = state.isRunning
        bindTimer()
        configureSync()
        if state.isRunning, let startDate = state.startedAt {
            startSession(durationSeconds: state.duration, startDate: startDate, shouldSync: false)
        }
    }

    func toggleTimer() {
        if isRunning {
            stopSession(shouldSync: true)
        } else {
            startSession(durationSeconds: minutes * 60, startDate: Date(), shouldSync: true)
        }
    }

    func setMinutes(_ newValue: Int) {
        minutes = newValue
        if !isRunning {
            remainingDisplay = Self.format(seconds: newValue * 60)
        }
        syncManager.publishPreferences(minutes: newValue)
    }

    private func bindTimer() {
        timer.onTick = { [weak self] remaining in
            guard let self else { return }
            remainingDisplay = Self.format(seconds: Int(remaining))
        }

        timer.onStateChange = { [weak self] isRunning in
            guard let self else { return }
            self.isRunning = isRunning
            if isRunning {
                self.playStartSound()
            }
        }

        timer.onCompletion = { [weak self] in
            guard let self else { return }
            self.playCompletionSound()
            self.stopSession(shouldSync: true)
        }
    }

    private func configureSync() {
        syncManager.onPreferencesChange = { [weak self] snapshot in
            guard let self else { return }
            self.applyPreferences(snapshot, ignoreIfLocalOrigin: true)
        }

        syncManager.onStateChange = { [weak self] state in
            guard let self else { return }
            self.applyState(state, ignoreIfLocalOrigin: true)
        }

        applyPreferences(syncManager.currentPreferences(), ignoreIfLocalOrigin: false)
        applyState(syncManager.currentState(), ignoreIfLocalOrigin: false)
    }

    private func applyPreferences(_ snapshot: PomodoroPreferencesSnapshot, ignoreIfLocalOrigin: Bool) {
        if ignoreIfLocalOrigin && snapshot.originIdentifier == syncManager.deviceIdentifier {
            return
        }
        minutes = snapshot.minutes
        if !isRunning {
            remainingDisplay = Self.format(seconds: minutes * 60)
        }
    }

    private func applyState(_ state: PomodoroSharedState, ignoreIfLocalOrigin: Bool) {
        if ignoreIfLocalOrigin && state.originIdentifier == syncManager.deviceIdentifier {
            return
        }
        guard state.isRunning, let start = state.startedAt else {
            stopSession(shouldSync: false)
            return
        }
        minutes = max(1, state.duration / 60)
        startSession(durationSeconds: state.duration, startDate: start, shouldSync: false)
    }

    private func startSession(durationSeconds: Int, startDate: Date, shouldSync: Bool) {
        activeDuration = durationSeconds
        timer.start(duration: TimeInterval(durationSeconds), startDate: startDate)
        isRunning = true
        if shouldSync {
            syncManager.publishState(duration: durationSeconds, startedAt: startDate, isRunning: true)
        }
    }

    private func stopSession(shouldSync: Bool) {
        timer.stop()
        isRunning = false
        if shouldSync {
            let duration = activeDuration == 0 ? minutes * 60 : activeDuration
            syncManager.publishState(duration: duration, startedAt: nil, isRunning: false)
        }
        activeDuration = 0
        remainingDisplay = Self.format(seconds: minutes * 60)
    }

    private func playStartSound() {
        AudioServicesPlaySystemSound(1104)
    }

    private func playCompletionSound() {
        AudioServicesPlaySystemSound(1111)
    }

    private static func format(seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let seconds = max(0, seconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
