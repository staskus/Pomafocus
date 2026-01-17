import WidgetKit
import SwiftUI
import AppIntents
import PomafocusKit

// MARK: - Colors

private let accentRed = Color(red: 0.92, green: 0.25, blue: 0.20)
private let accentYellow = Color(red: 1.0, green: 0.82, blue: 0.20)
private let darkBackground = Color(white: 0.08)
private let surfaceColor = Color(white: 0.12)

// MARK: - App Intents

struct ToggleTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Focus Timer"
    static var description = IntentDescription("Start or stop the focus timer")

    func perform() async throws -> some IntentResult {
        let state = WidgetStateManager.shared.loadState()
        if state.isRunning {
            WidgetStateManager.shared.saveCommand(.stop)
        } else {
            WidgetStateManager.shared.saveCommand(.start)
        }
        return .result()
    }
}

struct StartTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Focus"
    static var description = IntentDescription("Start a focus session")

    func perform() async throws -> some IntentResult {
        WidgetStateManager.shared.saveCommand(.start)
        return .result()
    }
}

struct StopTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Focus"
    static var description = IntentDescription("Stop the current focus session")

    func perform() async throws -> some IntentResult {
        WidgetStateManager.shared.saveCommand(.stop)
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

        var entries: [PomafocusEntry] = []

        if state.isRunning, let endsAt = state.endsAt {
            // Generate entries for each second while running
            let remainingTime = max(0, Int(endsAt.timeIntervalSince(currentDate)))
            let entryCount = min(remainingTime, 60) // Max 60 entries

            for offset in 0..<entryCount {
                let entryDate = currentDate.addingTimeInterval(TimeInterval(offset))
                let remaining = remainingTime - offset
                var entryState = state
                entryState.remainingSeconds = remaining
                entries.append(PomafocusEntry(date: entryDate, state: entryState))
            }

            // Schedule next timeline update
            let nextUpdate = currentDate.addingTimeInterval(60)
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            completion(timeline)
        } else {
            // Not running - single entry, refresh in 15 minutes
            entries.append(PomafocusEntry(date: currentDate, state: state))
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

                    Text(entry.state.isRunning ? "FOCUS" : "READY")
                        .font(.system(size: 10, weight: .black))
                        .tracking(1)
                        .foregroundStyle(entry.state.isRunning ? accentYellow : .white.opacity(0.6))

                    Spacer()
                }

                Spacer()

                // Timer display
                Text(entry.state.formattedRemaining)
                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)

                Spacer()

                // Action button
                Button(intent: ToggleTimerIntent()) {
                    Text(entry.state.isRunning ? "STOP" : "START")
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

                        Text(entry.state.isRunning ? "ACTIVE" : "READY")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(entry.state.isRunning ? .black : .white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(entry.state.isRunning ? accentYellow : Color.white.opacity(0.2))
                    }

                    // Timer
                    Text(entry.state.formattedRemaining)
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
                            Text(entry.state.isRunning ? "STOP" : "START")
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

                    Text(entry.state.isRunning ? "ACTIVE" : "READY")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(entry.state.isRunning ? .black : .white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(entry.state.isRunning ? accentYellow : Color.white.opacity(0.2))
                }

                Spacer()

                // Large timer display
                Text(entry.state.formattedRemaining)
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
                        Text(entry.state.isRunning ? "STOP SESSION" : "START SESSION")
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

            VStack(spacing: 2) {
                Image(systemName: entry.state.isRunning ? "timer" : "timer")
                    .font(.system(size: 14, weight: .bold))

                Text(shortTime)
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
            }
        }
        .widgetAccentable()
    }

    private var shortTime: String {
        let mins = entry.state.remainingSeconds / 60
        let secs = entry.state.remainingSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct AccessoryRectangularView: View {
    let entry: PomafocusEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 20, weight: .bold))
                .widgetAccentable()

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.state.isRunning ? "FOCUS" : "READY")
                    .font(.system(size: 10, weight: .black))

                Text(entry.state.formattedRemaining)
                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
            }

            Spacer()
        }
    }
}

struct AccessoryInlineView: View {
    let entry: PomafocusEntry

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
            Text(entry.state.isRunning ? entry.state.formattedRemaining : "Ready")
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
