import Foundation

public struct WidgetTimerState: Codable {
    public var isRunning: Bool
    public var remainingSeconds: Int
    public var durationSeconds: Int
    public var startedAt: Date?
    public var endsAt: Date?
    public var minutes: Int
    public var deepBreathEnabled: Bool
    public var deepBreathRemainingSeconds: Int?
    public var deepBreathReady: Bool
    public var deepBreathConfirmationRemainingSeconds: Int?

    public static let deepBreathDuration: Int = 30
    public static let deepBreathConfirmationWindow: Int = 60

    public init(
        isRunning: Bool = false,
        remainingSeconds: Int = 1500,
        durationSeconds: Int = 1500,
        startedAt: Date? = nil,
        endsAt: Date? = nil,
        minutes: Int = 25,
        deepBreathEnabled: Bool = false,
        deepBreathRemainingSeconds: Int? = nil,
        deepBreathReady: Bool = false,
        deepBreathConfirmationRemainingSeconds: Int? = nil
    ) {
        self.isRunning = isRunning
        self.remainingSeconds = remainingSeconds
        self.durationSeconds = durationSeconds
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.minutes = minutes
        self.deepBreathEnabled = deepBreathEnabled
        self.deepBreathRemainingSeconds = deepBreathRemainingSeconds
        self.deepBreathReady = deepBreathReady
        self.deepBreathConfirmationRemainingSeconds = deepBreathConfirmationRemainingSeconds
    }

    private enum CodingKeys: String, CodingKey {
        case isRunning
        case remainingSeconds
        case durationSeconds
        case startedAt
        case endsAt
        case minutes
        case deepBreathEnabled
        case deepBreathRemainingSeconds
        case deepBreathReady
        case deepBreathConfirmationRemainingSeconds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isRunning = try container.decode(Bool.self, forKey: .isRunning)
        remainingSeconds = try container.decode(Int.self, forKey: .remainingSeconds)
        durationSeconds = try container.decode(Int.self, forKey: .durationSeconds)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        endsAt = try container.decodeIfPresent(Date.self, forKey: .endsAt)
        minutes = try container.decode(Int.self, forKey: .minutes)
        deepBreathEnabled = try container.decodeIfPresent(Bool.self, forKey: .deepBreathEnabled) ?? false
        deepBreathRemainingSeconds = try container.decodeIfPresent(Int.self, forKey: .deepBreathRemainingSeconds)
        deepBreathReady = try container.decodeIfPresent(Bool.self, forKey: .deepBreathReady) ?? false
        deepBreathConfirmationRemainingSeconds = try container.decodeIfPresent(Int.self, forKey: .deepBreathConfirmationRemainingSeconds)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isRunning, forKey: .isRunning)
        try container.encode(remainingSeconds, forKey: .remainingSeconds)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encodeIfPresent(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(endsAt, forKey: .endsAt)
        try container.encode(minutes, forKey: .minutes)
        try container.encode(deepBreathEnabled, forKey: .deepBreathEnabled)
        try container.encodeIfPresent(deepBreathRemainingSeconds, forKey: .deepBreathRemainingSeconds)
        try container.encode(deepBreathReady, forKey: .deepBreathReady)
        try container.encodeIfPresent(deepBreathConfirmationRemainingSeconds, forKey: .deepBreathConfirmationRemainingSeconds)
    }

    public var isDeepBreathing: Bool {
        deepBreathRemainingSeconds != nil || deepBreathReady
    }

    public var formattedDisplayRemaining: String {
        formattedSeconds(displayRemainingSeconds)
    }

    public var progress: Double {
        let rawValue: Double
        if isDeepBreathing {
            if deepBreathReady, let remaining = deepBreathConfirmationRemainingSeconds {
                rawValue = progressValue(remaining: remaining, total: Self.deepBreathConfirmationWindow)
            } else if let remaining = deepBreathRemainingSeconds {
                rawValue = progressValue(remaining: remaining, total: Self.deepBreathDuration)
            } else {
                rawValue = 0
            }
        } else {
            let total = max(durationSeconds, 1)
            let elapsed = total - remainingSeconds
            rawValue = Double(elapsed) / Double(total)
        }
        return min(max(rawValue, 0), 1)
    }

    public var statusLabel: String {
        if isDeepBreathing {
            return deepBreathReady ? "CONFIRM" : "BREATHE"
        }
        return isRunning ? "FOCUS" : "READY"
    }

    public var actionLabel: String {
        if isRunning {
            if isDeepBreathing {
                return deepBreathReady ? "CONFIRM" : "BREATHE"
            }
            return deepBreathEnabled ? "STOP" : "STOP"
        }
        return "START"
    }

    public func normalized(for date: Date) -> WidgetTimerState {
        guard isRunning, let endsAt, endsAt <= date else {
            return self
        }
        var updated = self
        updated.isRunning = false
        updated.remainingSeconds = 0
        updated.startedAt = nil
        updated.endsAt = nil
        updated.deepBreathRemainingSeconds = nil
        updated.deepBreathReady = false
        updated.deepBreathConfirmationRemainingSeconds = nil
        return updated
    }

    private var displayRemainingSeconds: Int {
        if deepBreathReady, let remaining = deepBreathConfirmationRemainingSeconds {
            return remaining
        }
        if let remaining = deepBreathRemainingSeconds {
            return remaining
        }
        return remainingSeconds
    }

    private func formattedSeconds(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let mins = clamped / 60
        let secs = clamped % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func progressValue(remaining: Int, total: Int) -> Double {
        let clampedTotal = max(total, 1)
        let elapsed = clampedTotal - max(0, remaining)
        return Double(elapsed) / Double(clampedTotal)
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

        // Allow enough time for cold app launches to receive widget commands.
        let age = Date().timeIntervalSince1970 - timestamp
        guard age < 30 else {
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
