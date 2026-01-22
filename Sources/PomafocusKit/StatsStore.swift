import Foundation

public enum FocusSessionOutcome: String, Codable {
    case completed
    case stopped
}

public struct FocusSessionSummary: Codable, Identifiable, Hashable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date
    public let durationSeconds: Int
    public let outcome: FocusSessionOutcome

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int,
        outcome: FocusSessionOutcome
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.outcome = outcome
    }
}

public struct DailyFocusStats: Codable, Hashable {
    public let date: Date
    public let totalMinutes: Int
    public let sessionsStarted: Int
    public let sessionsCompleted: Int

    public var completionRate: Double {
        guard sessionsStarted > 0 else { return 0 }
        return Double(sessionsCompleted) / Double(sessionsStarted)
    }
}

public struct WeeklyFocusSummary: Hashable {
    public let totalMinutes: Int
    public let sessionsStarted: Int
    public let sessionsCompleted: Int
    public let completionRate: Double
    public let currentStreakDays: Int

    public init(
        totalMinutes: Int,
        sessionsStarted: Int,
        sessionsCompleted: Int,
        completionRate: Double,
        currentStreakDays: Int
    ) {
        self.totalMinutes = totalMinutes
        self.sessionsStarted = sessionsStarted
        self.sessionsCompleted = sessionsCompleted
        self.completionRate = completionRate
        self.currentStreakDays = currentStreakDays
    }
}

@MainActor
public final class StatsStore {
    public static let shared = StatsStore()

    private let summariesKey = "pomafocus.stats.summaries"
    private let calendar = Calendar.current
    private let defaults: UserDefaults

    private init() {
        if let appGroup = UserDefaults(suiteName: "group.com.staskus.pomafocus") {
            self.defaults = appGroup
        } else {
            self.defaults = .standard
        }
    }

    public func recordSession(
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int,
        outcome: FocusSessionOutcome
    ) {
        var summaries = loadSummaries()
        summaries.append(
            FocusSessionSummary(
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: max(0, durationSeconds),
                outcome: outcome
            )
        )
        saveSummaries(summaries)
    }

    public func weeklySummary(referenceDate: Date = Date()) -> WeeklyFocusSummary {
        let rollups = dailyRollups(days: 7, referenceDate: referenceDate)
        let totalMinutes = rollups.reduce(0) { $0 + $1.totalMinutes }
        let sessionsStarted = rollups.reduce(0) { $0 + $1.sessionsStarted }
        let sessionsCompleted = rollups.reduce(0) { $0 + $1.sessionsCompleted }
        let completionRate = sessionsStarted > 0 ? Double(sessionsCompleted) / Double(sessionsStarted) : 0
        return WeeklyFocusSummary(
            totalMinutes: totalMinutes,
            sessionsStarted: sessionsStarted,
            sessionsCompleted: sessionsCompleted,
            completionRate: completionRate,
            currentStreakDays: currentStreakDays(referenceDate: referenceDate)
        )
    }

    public func dailyRollups(days: Int, referenceDate: Date = Date()) -> [DailyFocusStats] {
        guard days > 0 else { return [] }
        let summaries = loadSummaries()
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: startOfToday) ?? startOfToday

        var buckets: [Date: [FocusSessionSummary]] = [:]
        for summary in summaries where summary.startedAt >= startDate {
            let bucketDate = calendar.startOfDay(for: summary.startedAt)
            buckets[bucketDate, default: []].append(summary)
        }

        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            let daySummaries = buckets[date, default: []]
            let minutes = daySummaries.reduce(0) { $0 + Int(round(Double($1.durationSeconds) / 60.0)) }
            let sessionsStarted = daySummaries.count
            let sessionsCompleted = daySummaries.filter { $0.outcome == .completed }.count
            return DailyFocusStats(
                date: date,
                totalMinutes: minutes,
                sessionsStarted: sessionsStarted,
                sessionsCompleted: sessionsCompleted
            )
        }
    }

    public func clearAll() {
        defaults.removeObject(forKey: summariesKey)
    }

    private func currentStreakDays(referenceDate: Date) -> Int {
        let summaries = loadSummaries().filter { $0.outcome == .completed }
        guard !summaries.isEmpty else { return 0 }

        let grouped = Dictionary(grouping: summaries) { calendar.startOfDay(for: $0.startedAt) }
        var streak = 0
        var cursor = calendar.startOfDay(for: referenceDate)

        while grouped[cursor]?.isEmpty == false {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private func loadSummaries() -> [FocusSessionSummary] {
        guard let data = defaults.data(forKey: summariesKey),
              let summaries = try? JSONDecoder().decode([FocusSessionSummary].self, from: data) else {
            return []
        }
        return summaries
    }

    private func saveSummaries(_ summaries: [FocusSessionSummary]) {
        guard let data = try? JSONEncoder().encode(summaries) else { return }
        defaults.set(data, forKey: summariesKey)
    }
}
