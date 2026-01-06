import SwiftUI
import PomafocusKit

public struct PomodoroDashboardView: View {
    @ObservedObject private var session: PomodoroSessionController

    public init(
        session: PomodoroSessionController
    ) {
        self.session = session
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("AccentDeep"), Color("AccentBright")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                header
                timerCard
                controls
                Spacer()
            }
            .padding()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pomafocus")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            Text(session.displayStateText)
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timerCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 12)
                    .frame(width: 220, height: 220)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.white, Color("AccentGlow")]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 220, height: 220)
                    .animation(.easeInOut(duration: 0.4), value: progress)

                VStack {
                    Text(session.remainingDisplay)
                        .font(.system(size: 48, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    Text(session.isRunning ? "Stay in flow" : "Ready to focus")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.subheadline)
                }
            }

            Button(action: session.toggleTimer) {
                Text(session.isRunning ? "Stop Session" : "Start Focus")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(Color("AccentDeep"))
                    .cornerRadius(16)
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(28)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Session length")
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text("\(session.minutes) min")
                        .foregroundColor(.white)
                        .font(.title3.bold())
                        .monospacedDigit()
                }

                Slider(
                    value: Binding(
                        get: { Double(session.minutes) },
                        set: { session.setMinutes(Int($0.rounded())) }
                    ),
                    in: 10...90,
                    step: 1
                )
                .tint(.white)
                .disabled(!session.canAdjustMinutes)
            }

            PlatformBlockingPanel()
        }
    }

    private var progress: CGFloat {
        let total = Double(session.minutes * 60)
        guard total > 0 else { return 0 }
        return CGFloat(1 - (session.remaining / total))
    }

}
