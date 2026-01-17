import Foundation

public struct WidgetTimerState: Codable {
    public var isRunning: Bool
    public var remainingSeconds: Int
    public var durationSeconds: Int
    public var startedAt: Date?
    public var endsAt: Date?
    public var minutes: Int

    public init(
        isRunning: Bool = false,
        remainingSeconds: Int = 1500,
        durationSeconds: Int = 1500,
        startedAt: Date? = nil,
        endsAt: Date? = nil,
        minutes: Int = 25
    ) {
        self.isRunning = isRunning
        self.remainingSeconds = remainingSeconds
        self.durationSeconds = durationSeconds
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.minutes = minutes
    }

    public var formattedRemaining: String {
        let seconds = max(0, remainingSeconds)
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    public var progress: Double {
        let total = max(durationSeconds, 1)
        let elapsed = total - remainingSeconds
        return Double(elapsed) / Double(total)
    }
}

public final class WidgetStateManager: Sendable {
    public static let shared = WidgetStateManager()

    private static let appGroupIdentifier = "group.com.staskus.pomafocus"
    private static let stateKey = "pomafocus.widget.state"
    private static let commandKey = "pomafocus.widget.command"

    public enum Command: String, Codable {
        case start
        case stop
    }

    private init() {}

    public var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    public func saveState(_ state: WidgetTimerState) {
        guard let defaults = sharedDefaults,
              let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.stateKey)
    }

    public func loadState() -> WidgetTimerState {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: Self.stateKey),
              let state = try? JSONDecoder().decode(WidgetTimerState.self, from: data) else {
            return WidgetTimerState()
        }
        return state
    }

    public func saveCommand(_ command: Command) {
        guard let defaults = sharedDefaults else { return }
        defaults.set(command.rawValue, forKey: Self.commandKey)
        defaults.set(Date().timeIntervalSince1970, forKey: Self.commandKey + ".timestamp")
    }

    public func consumeCommand() -> Command? {
        guard let defaults = sharedDefaults,
              let rawValue = defaults.string(forKey: Self.commandKey),
              let timestamp = defaults.object(forKey: Self.commandKey + ".timestamp") as? TimeInterval else {
            return nil
        }

        // Only consume commands less than 5 seconds old
        let age = Date().timeIntervalSince1970 - timestamp
        guard age < 5 else {
            defaults.removeObject(forKey: Self.commandKey)
            defaults.removeObject(forKey: Self.commandKey + ".timestamp")
            return nil
        }

        let command = Command(rawValue: rawValue)
        defaults.removeObject(forKey: Self.commandKey)
        defaults.removeObject(forKey: Self.commandKey + ".timestamp")
        return command
    }
}
