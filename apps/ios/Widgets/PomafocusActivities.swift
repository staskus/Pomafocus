import ActivityKit
import WidgetKit
import SwiftUI
import PomafocusKit

struct PomafocusActivityView: View {
    let context: ActivityViewContext<PomodoroActivityAttributes>

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color("AccentDeep"))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("POMAFOCUS")
                        .font(.system(size: 13, weight: .black))
                        .tracking(1.5)
                        .foregroundColor(.white.opacity(0.8))

                    Spacer()

                    Text("ACTIVE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color("AccentBright"))
                }

                timerLabel
                timerProgress
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(.white)
    }

    private var timerLabel: some View {
        Group {
            if let interval = timerInterval {
                Text(timerInterval: interval, countsDown: true)
                    .font(.system(size: 44, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
            } else {
                Text(formattedRemaining)
                    .font(.system(size: 44, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
    }

    private var timerProgress: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.2))

                Rectangle()
                    .fill(Color("AccentGlow"))
                    .frame(width: geo.size.width * progressValue)
            }
        }
        .frame(height: 6)
    }

    private var progressValue: CGFloat {
        let total = max(context.state.durationSeconds, 1)
        let elapsed = total - context.state.remainingSeconds
        return CGFloat(elapsed) / CGFloat(total)
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
                .contentMargins(.all, 12)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    PomafocusActivityView(context: context)
                }
            } compactLeading: {
                if let interval = context.timerInterval {
                    Text(timerInterval: interval, countsDown: true)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color("AccentGlow"))
                } else {
                    Text(shortTime(context.state.remainingSeconds))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color("AccentGlow"))
                }
            } compactTrailing: {
                Image(systemName: "timer")
                    .foregroundColor(Color("AccentBright"))
            } minimal: {
                Image(systemName: "timer")
                    .foregroundColor(Color("AccentBright"))
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

@main
struct PomafocusActivitiesBundle: WidgetBundle {
    var body: some Widget {
        PomafocusActivities()
    }
}
