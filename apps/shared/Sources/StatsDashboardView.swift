import SwiftUI
import PomafocusKit

@MainActor
public struct StatsDashboardView: View {
    private let statsStore: StatsStore
    @State private var rollups: [DailyFocusStats] = []
    @State private var recentSummaries: [FocusSessionSummary] = []
    @State private var weeklySummary = WeeklyFocusSummary(
        totalMinutes: 0,
        sessionsStarted: 0,
        sessionsCompleted: 0,
        sessionsStopped: 0,
        completionRate: 0,
        currentStreakDays: 0
    )
    @State private var previousSummary = WeeklyFocusSummary(
        totalMinutes: 0,
        sessionsStarted: 0,
        sessionsCompleted: 0,
        sessionsStopped: 0,
        completionRate: 0,
        currentStreakDays: 0
    )

    public init(statsStore: StatsStore = .shared) {
        self.statsStore = statsStore
    }

    public var body: some View {
        ZStack {
            BrutalistColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: BrutalistSpacing.lg) {
                    header
                    weeklyHero
                    weeklyDeltaCard
                    streakRow
                    deepBreathRow
                    weeklyChart
                    sessionLengthChart
                }
                .padding(BrutalistSpacing.md)
            }
        }
        .onAppear(perform: refreshStats)
    }

    private var header: some View {
        HStack {
            Text("STATS")
                .font(BrutalistTypography.title(28))
                .foregroundStyle(BrutalistColors.textPrimary)
                .tracking(2)
            Spacer()
        }
        .padding(.top, BrutalistSpacing.sm)
    }

    private var weeklyHero: some View {
        VStack(alignment: .leading, spacing: BrutalistSpacing.sm) {
            Text("THIS WEEK")
                .font(BrutalistTypography.caption)
                .foregroundStyle(BrutalistColors.textSecondary)
                .tracking(1)

            HStack(alignment: .firstTextBaseline, spacing: BrutalistSpacing.sm) {
                Text("\(weeklySummary.totalMinutes)")
                    .font(BrutalistTypography.timer(48))
                    .foregroundStyle(BrutalistColors.textPrimary)
                    .monospacedDigit()
                Text("MIN")
                    .font(BrutalistTypography.headline)
                    .foregroundStyle(BrutalistColors.textSecondary)
            }

            HStack(spacing: BrutalistSpacing.md) {
                metricPill(title: "SESSIONS", value: "\(weeklySummary.sessionsCompleted)/\(weeklySummary.sessionsStarted)")
                metricPill(title: "COMPLETE", value: formattedPercent(weeklySummary.completionRate))
                metricPill(title: "STOPPED", value: "\(weeklySummary.sessionsStopped)")
            }
        }
        .padding(BrutalistSpacing.lg)
        .modifier(BrutalistCardModifier())
    }

    private var streakRow: some View {
        HStack(spacing: BrutalistSpacing.md) {
            statCard(title: "CURRENT STREAK", value: "\(weeklySummary.currentStreakDays) DAYS")
            statCard(title: "WEEKLY AVG", value: weeklyAverageText)
        }
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: BrutalistSpacing.sm) {
            Text("7-DAY FLOW")
                .font(BrutalistTypography.caption)
                .foregroundStyle(BrutalistColors.textSecondary)
                .tracking(1)

            HStack(alignment: .bottom, spacing: BrutalistSpacing.sm) {
                ForEach(rollups, id: \.date) { day in
                    VStack(spacing: BrutalistSpacing.xs) {
                        Rectangle()
                            .fill(BrutalistColors.red)
                            .frame(height: barHeight(for: day))
                            .frame(maxWidth: .infinity)
                        Text(shortWeekday(for: day.date))
                            .font(BrutalistTypography.mono)
                            .foregroundStyle(BrutalistColors.textSecondary)
                    }
                }
            }
            .frame(height: 140)
        }
        .padding(BrutalistSpacing.md)
        .modifier(BrutalistCardModifier())
    }

    private var weeklyDeltaCard: some View {
        VStack(alignment: .leading, spacing: BrutalistSpacing.sm) {
            Text("WEEKLY RECAP")
                .font(BrutalistTypography.caption)
                .foregroundStyle(BrutalistColors.textSecondary)
                .tracking(1)

            Text(weeklyDeltaHeadline)
                .font(BrutalistTypography.headline)
                .foregroundStyle(BrutalistColors.textPrimary)

            Text(weeklyDeltaSubhead)
                .font(BrutalistTypography.body)
                .foregroundStyle(BrutalistColors.textSecondary)
        }
        .padding(BrutalistSpacing.md)
        .modifier(BrutalistCardModifier())
    }

    private var deepBreathRow: some View {
        HStack(spacing: BrutalistSpacing.md) {
            statCard(title: "DEEP BREATH", value: deepBreathSummaryText)
            statCard(title: "TIMEOUTS", value: "\(deepBreathTimeouts) TOTAL")
        }
    }

    private func refreshStats() {
        weeklySummary = statsStore.weeklySummary()
        previousSummary = statsStore.weeklySummary(referenceDate: previousWeekDate)
        rollups = statsStore.dailyRollups(days: 7)
        recentSummaries = statsStore.recentSummaries(days: 14)
    }

    private func metricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(BrutalistTypography.caption)
                .foregroundStyle(BrutalistColors.textSecondary)
                .tracking(1)
            Text(value)
                .font(BrutalistTypography.headline)
                .foregroundStyle(BrutalistColors.textPrimary)
        }
        .padding(.vertical, BrutalistSpacing.sm)
        .padding(.horizontal, BrutalistSpacing.md)
        .background(BrutalistColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BrutalistRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: BrutalistRadius.sm)
                .stroke(BrutalistColors.border, lineWidth: 1)
        )
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: BrutalistSpacing.sm) {
            Text(title)
                .font(BrutalistTypography.caption)
                .foregroundStyle(BrutalistColors.textSecondary)
                .tracking(1)
            Text(value)
                .font(BrutalistTypography.headline)
                .foregroundStyle(BrutalistColors.textPrimary)
        }
        .padding(BrutalistSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(BrutalistCardModifier())
    }

    private func barHeight(for day: DailyFocusStats) -> CGFloat {
        let maxMinutes = max(rollups.map(\.totalMinutes).max() ?? 0, 1)
        let ratio = CGFloat(day.totalMinutes) / CGFloat(maxMinutes)
        return max(8, ratio * 110)
    }

    private func shortWeekday(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EE"
        return formatter.string(from: date).uppercased()
    }

    private func formattedPercent(_ value: Double) -> String {
        let percent = Int(round(value * 100))
        return "\(percent)%"
    }

    private var weeklyAverageText: String {
        let average = rollups.isEmpty ? 0 : weeklySummary.totalMinutes / max(rollups.count, 1)
        return "\(average) MIN"
    }

    private var previousWeekDate: Date {
        Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    }

    private var deepBreathStarts: Int {
        rollups.reduce(0) { $0 + $1.deepBreathStarts }
    }

    private var deepBreathConfirms: Int {
        rollups.reduce(0) { $0 + $1.deepBreathConfirms }
    }

    private var deepBreathTimeouts: Int {
        rollups.reduce(0) { $0 + $1.deepBreathTimeouts }
    }

    private var deepBreathSummaryText: String {
        if deepBreathStarts == 0 {
            return "NO USE"
        }
        let rate = Int(round(Double(deepBreathConfirms) / Double(max(deepBreathStarts, 1)) * 100))
        return "\(deepBreathConfirms)/\(deepBreathStarts) (\(rate)%)"
    }

    private var sessionLengthChart: some View {
        let buckets = sessionLengthBuckets()
        return VStack(alignment: .leading, spacing: BrutalistSpacing.sm) {
            Text("SESSION LENGTHS")
                .font(BrutalistTypography.caption)
                .foregroundStyle(BrutalistColors.textSecondary)
                .tracking(1)

            HStack(alignment: .bottom, spacing: BrutalistSpacing.sm) {
                ForEach(buckets) { bucket in
                    VStack(spacing: BrutalistSpacing.xs) {
                        Rectangle()
                            .fill(BrutalistColors.red)
                            .frame(height: lengthBarHeight(for: bucket.count, in: buckets))
                            .frame(maxWidth: .infinity)
                        Text(bucket.label)
                            .font(BrutalistTypography.mono)
                            .foregroundStyle(BrutalistColors.textSecondary)
                    }
                }
            }
            .frame(height: 120)
        }
        .padding(BrutalistSpacing.md)
        .modifier(BrutalistCardModifier())
    }

    private var weeklyDeltaHeadline: String {
        let delta = weeklySummary.totalMinutes - previousSummary.totalMinutes
        if delta == 0 {
            return "Same as last week"
        }
        let sign = delta > 0 ? "+" : ""
        return "\(sign)\(delta) MIN VS LAST WEEK"
    }

    private var weeklyDeltaSubhead: String {
        let completionDelta = Int(round((weeklySummary.completionRate - previousSummary.completionRate) * 100))
        if completionDelta == 0 {
            return "Completion rate steady"
        }
        let sign = completionDelta > 0 ? "+" : ""
        return "Completion \(sign)\(completionDelta)%"
    }

    private struct LengthBucket: Identifiable {
        let id: String
        let label: String
        let count: Int
    }

    private func sessionLengthBuckets() -> [LengthBucket] {
        let minutes = recentSummaries
            .filter { $0.outcome == .completed }
            .map { max(1, Int(round(Double($0.durationSeconds) / 60.0))) }

        let ranges: [(String, ClosedRange<Int>)] = [
            ("0-25", 1...25),
            ("26-45", 26...45),
            ("46-60", 46...60),
            ("61-90", 61...90),
            ("90+", 91...10_000)
        ]

        return ranges.map { label, range in
            let count = minutes.filter { range.contains($0) }.count
            return LengthBucket(id: label, label: label, count: count)
        }
    }

    private func lengthBarHeight(for count: Int, in buckets: [LengthBucket]) -> CGFloat {
        let maxCount = max(buckets.map(\.count).max() ?? 0, 1)
        let ratio = CGFloat(count) / CGFloat(maxCount)
        return max(8, ratio * 90)
    }
}

#Preview {
    StatsDashboardView()
}
