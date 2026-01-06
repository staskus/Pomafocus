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
            Text(timeRemaining)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
            progressBar
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

    private var timeRemaining: String {
        let seconds = max(0, context.state.remainingSeconds)
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 8)
                Capsule()
                    .fill(Color("AccentGlow"))
                    .frame(width: geometry.size.width * progress, height: 8)
            }
        }
        .frame(height: 8)
    }

    private var progress: CGFloat {
        guard context.state.durationSeconds > 0 else { return 0 }
        let elapsed = context.state.durationSeconds - context.state.remainingSeconds
        return CGFloat(min(max(Double(elapsed) / Double(context.state.durationSeconds), 0), 1))
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
                Text(shortTime(context.state.remainingSeconds))
                    .font(.body.monospacedDigit())
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
