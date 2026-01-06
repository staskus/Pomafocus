import ActivityKit
import WidgetKit
import SwiftUI
import PomafocusKit

struct PomafocusActivityView: View {
    let context: ActivityViewContext<PomodoroActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pomafocus")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
            timerLabel
            timerProgress
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color("AccentDeep"), Color("AccentBright")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var timerLabel: some View {
        if let interval = timerInterval {
            return AnyView(
                Text(timerInterval: interval, countsDown: true)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
            )
        } else {
            return AnyView(
                Text(formattedRemaining)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
            )
        }
    }

    private var timerProgress: some View {
        if let interval = timerInterval {
            return AnyView(
                ProgressView(timerInterval: interval)
                    .progressViewStyle(.linear)
                    .tint(Color("AccentGlow"))
            )
        } else {
            return AnyView(
                ProgressView(value: Double(context.state.durationSeconds - context.state.remainingSeconds),
                             total: Double(max(context.state.durationSeconds, 1)))
                    .progressViewStyle(.linear)
                    .tint(Color("AccentGlow"))
            )
        }
    }

    private var timerInterval: ClosedRange<Date>? {
        guard let start = context.state.startedAt, let end = context.state.endsAt else {
            return nil
        }
        return start...end
    }

    private var formattedRemaining: String {
        let seconds = max(0, context.state.remainingSeconds)
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

struct PomafocusActivities: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            PomafocusActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    PomafocusActivityView(context: context)
                }
            } compactLeading: {
                if let interval = context.timerInterval {
                    Text(timerInterval: interval, countsDown: true)
                        .font(.body.monospacedDigit())
                } else {
                    Text(shortTime(context.state.remainingSeconds))
                        .font(.body.monospacedDigit())
                }
            } compactTrailing: {
                Image(systemName: "timer")
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }

    private func shortTime(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let secs = max(0, seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

private extension ActivityViewContext where Attributes == PomodoroActivityAttributes {
    var timerInterval: ClosedRange<Date>? {
        guard let start = state.startedAt, let end = state.endsAt else {
            return nil
        }
        return start...end
    }
}
