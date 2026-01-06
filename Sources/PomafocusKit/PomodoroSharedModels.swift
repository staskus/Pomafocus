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
    public var updatedAt: Date
    public var originIdentifier: String

    public init(minutes: Int, updatedAt: Date, originIdentifier: String) {
        self.minutes = minutes
        self.updatedAt = updatedAt
        self.originIdentifier = originIdentifier
    }
}
