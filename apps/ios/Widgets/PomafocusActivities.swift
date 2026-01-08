import ActivityKit
import WidgetKit
import SwiftUI
import PomafocusKit

// MARK: - Lock Screen / Notification Center Widget

struct PomafocusActivityView: View {
    let context: ActivityViewContext<PomodoroActivityAttributes>

    private let accentRed = Color(red: 0.92, green: 0.25, blue: 0.20)
    private let accentYellow = Color(red: 1.0, green: 0.82, blue: 0.20)

    var body: some View {
        HStack(spacing: 16) {
            // Timer icon
            Image(systemName: "timer")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(accentRed)

            VStack(alignment: .leading, spacing: 4) {
                // Title row
                HStack {
                    Text("POMAFOCUS")
                        .font(.system(size: 12, weight: .black))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    Text("ACTIVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accentYellow)
                }

                // Timer display
                timerLabel

                // Progress bar
                timerProgress
            }
        }
        .padding(16)
        .background(Color(white: 0.08))
        .activityBackgroundTint(Color(white: 0.08))
        .activitySystemActionForegroundColor(.white)
    }

    private var timerLabel: some View {
        Group {
            if let interval = timerInterval {
                Text(timerInterval: interval, countsDown: true)
                    .font(.system(size: 36, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
            } else {
                Text(formattedRemaining)
                    .font(.system(size: 36, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
    }

    private var timerProgress: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.15))

                Rectangle()
                    .fill(accentRed)
                    .frame(width: geo.size.width * progressValue)
            }
        }
        .frame(height: 4)
    }

    private var progressValue: CGFloat {
        let total = max(context.state.durationSeconds, 1)
        let elapsed = total - context.state.remainingSeconds
        return CGFloat(elapsed) / CGFloat(total)
    }

    private var timerInterval: ClosedRange<Date>? {
        guard let end = context.state.endsAt, end > Date.now else {
            return nil
        }
        return Date.now...end
    }

    private var formattedRemaining: String {
        let seconds = max(0, context.state.remainingSeconds)
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Dynamic Island

struct PomafocusActivities: Widget {
    private let accentRed = Color(red: 0.92, green: 0.25, blue: 0.20)
    private let accentYellow = Color(red: 1.0, green: 0.82, blue: 0.20)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            // Lock Screen / Notification Center
            PomafocusActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(accentRed)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FOCUS SESSION")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.6))

                        if let interval = context.timerInterval {
                            Text(timerInterval: interval, countsDown: true)
                                .font(.system(size: 32, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.white)
                        } else {
                            Text(shortTime(context.state.remainingSeconds))
                                .font(.system(size: 32, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("ACTIVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(accentYellow)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: progressValue(context))
                        .tint(accentRed)
                }
            } compactLeading: {
                // Compact: Icon + Time
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(accentRed)

                    if let interval = context.timerInterval {
                        Text(timerInterval: interval, countsDown: true)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    } else {
                        Text(shortTime(context.state.remainingSeconds))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
            } compactTrailing: {
                // Empty or minimal indicator
                Circle()
                    .fill(accentRed)
                    .frame(width: 8, height: 8)
            } minimal: {
                // Minimal: just icon
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accentRed)
            }
        }
    }

    private func shortTime(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let secs = max(0, seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func progressValue(_ context: ActivityViewContext<PomodoroActivityAttributes>) -> Double {
        let total = max(context.state.durationSeconds, 1)
        let elapsed = total - context.state.remainingSeconds
        return Double(elapsed) / Double(total)
    }
}

private extension ActivityViewContext where Attributes == PomodoroActivityAttributes {
    var timerInterval: ClosedRange<Date>? {
        guard let end = state.endsAt, end > Date.now else {
            return nil
        }
        return Date.now...end
    }
}

@main
struct PomafocusActivitiesBundle: WidgetBundle {
    var body: some Widget {
        PomafocusActivities()
    }
}
