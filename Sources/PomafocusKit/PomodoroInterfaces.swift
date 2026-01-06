import Foundation

@MainActor
public protocol PomodoroSyncManaging: AnyObject {
    var onStateChange: ((PomodoroSharedState) -> Void)? { get set }
    var onPreferencesChange: ((PomodoroPreferencesSnapshot) -> Void)? { get set }
    var deviceIdentifier: String { get }

    func start()
    func currentState() -> PomodoroSharedState
    func currentPreferences() -> PomodoroPreferencesSnapshot
    func publishState(duration: Int, startedAt: Date?, isRunning: Bool)
    func publishPreferences(minutes: Int, deepBreathEnabled: Bool)
}

@MainActor
public protocol PomodoroBlocking: AnyObject {
    var hasSelection: Bool { get }
    var selectionSummary: String { get }

    func beginBlocking()
    func endBlocking()
}
