import Foundation

public struct PomodoroSharedState: Codable, Equatable {
    public var duration: Int
    public var startedAt: Date?
    public var isRunning: Bool
    public var updatedAt: Date
    public var originIdentifier: String

    public init(duration: Int, startedAt: Date?, isRunning: Bool, updatedAt: Date, originIdentifier: String) {
        self.duration = duration
        self.startedAt = startedAt
        self.isRunning = isRunning
        self.updatedAt = updatedAt
        self.originIdentifier = originIdentifier
    }
}

public struct PomodoroPreferencesSnapshot: Codable, Equatable {
    public var minutes: Int
    public var deepBreathEnabled: Bool
    public var updatedAt: Date
    public var originIdentifier: String

    public init(minutes: Int, deepBreathEnabled: Bool, updatedAt: Date, originIdentifier: String) {
        self.minutes = minutes
        self.deepBreathEnabled = deepBreathEnabled
        self.updatedAt = updatedAt
        self.originIdentifier = originIdentifier
    }

    private enum CodingKeys: String, CodingKey {
        case minutes
        case deepBreathEnabled
        case updatedAt
        case originIdentifier
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        minutes = try container.decode(Int.self, forKey: .minutes)
        deepBreathEnabled = try container.decodeIfPresent(Bool.self, forKey: .deepBreathEnabled) ?? false
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        originIdentifier = try container.decode(String.self, forKey: .originIdentifier)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(minutes, forKey: .minutes)
        try container.encode(deepBreathEnabled, forKey: .deepBreathEnabled)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(originIdentifier, forKey: .originIdentifier)
    }
}
