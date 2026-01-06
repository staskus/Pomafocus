#if canImport(ActivityKit) && os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import Foundation

public struct PomodoroActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var remainingSeconds: Int
        public var durationSeconds: Int
        public var startedAt: Date?
        public var endsAt: Date?
        public var isRunning: Bool

        public init(
            remainingSeconds: Int,
            durationSeconds: Int,
            startedAt: Date?,
            endsAt: Date?,
            isRunning: Bool
        ) {
            self.remainingSeconds = remainingSeconds
            self.durationSeconds = durationSeconds
            self.startedAt = startedAt
            self.endsAt = endsAt
            self.isRunning = isRunning
        }
    }

    public var title: String

    public init(title: String) {
        self.title = title
    }
}
#endif
