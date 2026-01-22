import WidgetKit
import SwiftUI
import AppIntents
import PomafocusWidgetKit

// MARK: - Colors

private let accentRed = Color(red: 0.92, green: 0.25, blue: 0.20)
private let accentYellow = Color(red: 1.0, green: 0.82, blue: 0.20)
private let darkBackground = Color(white: 0.08)
private let surfaceColor = Color(white: 0.12)

// MARK: - App Intents

struct ToggleTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Focus Timer"
    static var description = IntentDescription("Start or stop the focus timer")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        let state = WidgetStateManager.shared.loadState()
        if state.isRunning {
            WidgetStateManager.shared.saveCommand(.stop)
        } else {
            WidgetStateManager.shared.saveCommand(.start)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct StartTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Focus"
    static var description = IntentDescription("Start a focus session")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        WidgetStateManager.shared.saveCommand(.start)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct StopTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Focus"
    static var description = IntentDescription("Stop the current focus session")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        WidgetStateManager.shared.saveCommand(.stop)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Timeline Provider

struct PomafocusTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PomafocusEntry {
        PomafocusEntry(date: Date(), state: WidgetTimerState())
    }

    func getSnapshot(in context: Context, completion: @escaping (PomafocusEntry) -> Void) {
        let state = WidgetStateManager.shared.loadState()
        completion(PomafocusEntry(date: Date(), state: state))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PomafocusEntry>) -> Void) {
        let state = WidgetStateManager.shared.loadState()
        let currentDate = Date()
        let normalizedState = state.normalized(for: currentDate)

        var entries: [PomafocusEntry] = []

        if normalizedState.isRunning, let endsAt = normalizedState.endsAt {
            // Generate entries for each second while running
            let remainingTime = max(0, Int(endsAt.timeIntervalSince(currentDate)))
            let entryCount = min(remainingTime, 60) // Max 60 entries

            for offset in 0..<entryCount {
                let entryDate = currentDate.addingTimeInterval(TimeInterval(offset))
                let remaining = remainingTime - offset
                var entryState = normalizedState
                entryState.remainingSeconds = remaining
                entries.append(PomafocusEntry(date: entryDate, state: entryState))
            }

            if remainingTime <= 60 {
                var finalState = normalizedState
                finalState.isRunning = false
                finalState.remainingSeconds = 0
                finalState.startedAt = nil
                finalState.endsAt = nil
                finalState.deepBreathRemainingSeconds = nil
                finalState.deepBreathReady = false
                finalState.deepBreathConfirmationRemainingSeconds = nil
                entries.append(PomafocusEntry(date: endsAt, state: finalState))
                let nextUpdate = endsAt.addingTimeInterval(900)
                completion(Timeline(entries: entries, policy: .after(nextUpdate)))
            } else {
                // Schedule next timeline update
                let nextUpdate = currentDate.addingTimeInterval(60)
                completion(Timeline(entries: entries, policy: .after(nextUpdate)))
            }
        } else {
            // Not running - single entry, refresh in 15 minutes
            entries.append(PomafocusEntry(date: currentDate, state: normalizedState))
            let nextUpdate = currentDate.addingTimeInterval(900)
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

struct PomafocusEntry: TimelineEntry {
    let date: Date
    let state: WidgetTimerState
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: PomafocusEntry

    var body: some View {
        ZStack {
            darkBackground

            VStack(spacing: 8) {
                // Status indicator
                HStack {
                    Circle()
                        .fill(entry.state.isRunning ? accentRed : Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)

                    Text(entry.state.statusLabel)
                        .font(.system(size: 10, weight: .black))
                        .tracking(1)
                        .foregroundStyle(entry.state.isRunning ? accentYellow : .white.opacity(0.6))

                    Spacer()
                }

                Spacer()

                // Timer display
                Text(entry.state.formattedDisplayRemaining)
                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)

                Spacer()

                // Action button
                Button(intent: ToggleTimerIntent()) {
                    Text(entry.state.actionLabel)
                        .font(.system(size: 12, weight: .black))
                        .tracking(1)
                        .foregroundStyle(entry.state.isRunning ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(entry.state.isRunning ? Color.white.opacity(0.15) : accentRed)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
        }
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: PomafocusEntry

    var body: some View {
        ZStack {
            darkBackground

            HStack(spacing: 16) {
                // Left: Timer info
                VStack(alignment: .leading, spacing: 8) {
                    // Title and status
                    HStack {
                        Text("POMAFOCUS")
                            .font(.system(size: 11, weight: .black))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.6))

                        Spacer()

                        Text(entry.state.statusLabel)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(entry.state.isRunning ? .black : .white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(entry.state.isRunning ? accentYellow : Color.white.opacity(0.2))
                    }

                    // Timer
                    Text(entry.state.formattedDisplayRemaining)
                        .font(.system(size: 40, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.15))
                            Rectangle()
                                .fill(accentRed)
                                .frame(width: geo.size.width * entry.state.progress)
                        }
                    }
                    .frame(height: 4)
                }

                // Right: Action button
                VStack {
                    Spacer()

                    Button(intent: ToggleTimerIntent()) {
                        VStack(spacing: 4) {
                            Image(systemName: entry.state.isRunning ? "stop.fill" : "play.fill")
                                .font(.system(size: 24, weight: .bold))
                            Text(entry.state.actionLabel)
                                .font(.system(size: 10, weight: .black))
                                .tracking(1)
                        }
                        .foregroundStyle(entry.state.isRunning ? .white : .black)
                        .frame(width: 64, height: 64)
                        .background(entry.state.isRunning ? Color.white.opacity(0.15) : accentRed)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Large Widget View

struct LargeWidgetView: View {
    let entry: PomafocusEntry

    var body: some View {
        ZStack {
            darkBackground

            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "timer")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(accentRed)

                    Text("POMAFOCUS")
                        .font(.system(size: 14, weight: .black))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    Text(entry.state.statusLabel)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(entry.state.isRunning ? .black : .white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(entry.state.isRunning ? accentYellow : Color.white.opacity(0.2))
                }

                Spacer()

                // Large timer display
                Text(entry.state.formattedDisplayRemaining)
                    .font(.system(size: 72, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                        Rectangle()
                            .fill(accentRed)
                            .frame(width: geo.size.width * entry.state.progress)
                    }
                }
                .frame(height: 6)

                // Duration info
                Text("\(entry.state.minutes) MINUTE SESSION")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                // Action button
                Button(intent: ToggleTimerIntent()) {
                    HStack {
                        Image(systemName: entry.state.isRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                        Text(entry.state.isRunning ? (entry.state.isDeepBreathing ? entry.state.actionLabel : "STOP SESSION") : "START SESSION")
                            .font(.system(size: 14, weight: .black))
                            .tracking(1)
                    }
                    .foregroundStyle(entry.state.isRunning ? .white : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(entry.state.isRunning ? Color.white.opacity(0.15) : accentRed)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
    }
}

// MARK: - Lock Screen Widget View (Accessory)

struct AccessoryCircularView: View {
    let entry: PomafocusEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            Gauge(value: entry.state.progress, in: 0...1) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .gaugeStyle(.accessoryCircular)
            .tint(accentRed)

            VStack(spacing: 2) {
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .bold))
                Text(entry.state.formattedDisplayRemaining)
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
            }
            .widgetAccentable()
        }
    }

    private var iconName: String {
        entry.state.isDeepBreathing ? "wind" : "timer"
    }
}

struct AccessoryRectangularView: View {
    let entry: PomafocusEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            HStack(spacing: 8) {
                Image(systemName: entry.state.isDeepBreathing ? "wind" : "timer")
                    .font(.system(size: 20, weight: .bold))
                    .widgetAccentable()

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.state.statusLabel)
                        .font(.system(size: 10, weight: .black))

                    Text(entry.state.formattedDisplayRemaining)
                        .font(.system(size: 18, weight: .heavy, design: .monospaced))

                    ProgressView(value: entry.state.progress)
                        .progressViewStyle(.linear)
                        .tint(accentRed)
                }

                Spacer()
            }
        }
    }
}

struct AccessoryInlineView: View {
    let entry: PomafocusEntry

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.state.isDeepBreathing ? "wind" : "timer")
            Text("\(entry.state.statusLabel) \(entry.state.formattedDisplayRemaining)")
        }
    }
}

// MARK: - Widget Definitions

struct PomafocusHomeWidget: Widget {
    let kind = "PomafocusHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PomafocusTimelineProvider()) { entry in
            SmallWidgetView(entry: entry)
                .containerBackground(darkBackground, for: .widget)
        }
        .configurationDisplayName("Focus Timer")
        .description("Start and track your focus sessions.")
        .supportedFamilies([.systemSmall])
    }
}

struct PomafocusMediumWidget: Widget {
    let kind = "PomafocusMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PomafocusTimelineProvider()) { entry in
            MediumWidgetView(entry: entry)
                .containerBackground(darkBackground, for: .widget)
        }
        .configurationDisplayName("Focus Timer")
        .description("Start and track your focus sessions.")
        .supportedFamilies([.systemMedium])
    }
}

struct PomafocusLargeWidget: Widget {
    let kind = "PomafocusLargeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PomafocusTimelineProvider()) { entry in
            LargeWidgetView(entry: entry)
                .containerBackground(darkBackground, for: .widget)
        }
        .configurationDisplayName("Focus Timer")
        .description("Start and track your focus sessions with a large display.")
        .supportedFamilies([.systemLarge])
    }
}

struct PomafocusLockScreenWidget: Widget {
    let kind = "PomafocusLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PomafocusTimelineProvider()) { entry in
            AccessoryCircularView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Focus Timer")
        .description("Quick glance at your focus timer.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct PomafocusLockScreenRectWidget: Widget {
    let kind = "PomafocusLockScreenRectWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PomafocusTimelineProvider()) { entry in
            AccessoryRectangularView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Focus Timer")
        .description("Focus timer with status.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct PomafocusLockScreenInlineWidget: Widget {
    let kind = "PomafocusLockScreenInlineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PomafocusTimelineProvider()) { entry in
            AccessoryInlineView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Focus Timer")
        .description("Inline focus timer status.")
        .supportedFamilies([.accessoryInline])
    }
}

// MARK: - Widget Bundle

@main
struct PomafocusWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PomafocusHomeWidget()
        PomafocusMediumWidget()
        PomafocusLargeWidget()
        PomafocusLockScreenWidget()
        PomafocusLockScreenRectWidget()
        PomafocusLockScreenInlineWidget()
    }
}
