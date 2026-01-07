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
            timerRing
            stopButton
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
                .disabled(settingsLocked)
            }

            PlatformBlockingPanel(isDisabled: settingsLocked)
            Toggle(isOn: deepBreathBinding) {
                Label("Deep breath before stopping", systemImage: "lungs.fill")
                    .foregroundColor(.white.opacity(0.85))
            }
            .toggleStyle(.switch)
            .disabled(settingsLocked)
            .opacity(settingsLocked ? 0.5 : 1)
        }
    }

    private var progress: CGFloat {
        let total = Double(session.minutes * 60)
        guard total > 0 else { return 0 }
        return CGFloat(1 - (session.remaining / total))
    }

    private var timerRing: some View {
        let ringWidth: CGFloat = 14
        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: ringWidth)
                .frame(width: 220, height: 220)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.white, Color("AccentGlow")]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 220, height: 220)
                .animation(.easeInOut(duration: 0.4), value: progress)

            VStack(spacing: 4) {
                Text(session.remainingDisplay)
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                Text(session.isRunning ? "Stay in flow" : "Ready to focus")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.subheadline)
            }
        }
    }

    private var stopButton: some View {
        Button(action: session.toggleTimer) {
            VStack(spacing: 6) {
                Text(stopButtonTitle)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .foregroundColor(Color("AccentDeep"))
                if let progress = deepBreathProgress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(Color("AccentGlow"))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(16)
        }
        .disabled(stopButtonDisabled)
    }

    private var stopButtonTitle: String {
        if session.isRunning {
            if session.deepBreathEnabled {
                if session.deepBreathReady {
                    return "Confirm Stop"
                }
                if let remaining = session.deepBreathRemaining {
                    return "Deep breath \(PomodoroSessionController.format(seconds: Int(remaining)))"
                }
            }
            return "Stop Session"
        } else {
            return "Start Focus"
        }
    }

    private var stopButtonDisabled: Bool {
        session.isRunning && session.deepBreathEnabled && session.deepBreathRemaining != nil && !session.deepBreathReady
    }

    private var deepBreathProgress: Double? {
        if let remaining = session.deepBreathRemaining {
            let elapsed = PomodoroSessionController.deepBreathDuration - remaining
            return min(max(elapsed / PomodoroSessionController.deepBreathDuration, 0), 1)
        }
        if session.deepBreathReady, let confirmation = session.deepBreathConfirmationRemaining {
            let elapsed = PomodoroSessionController.deepBreathConfirmationWindow - confirmation
            return min(max(elapsed / PomodoroSessionController.deepBreathConfirmationWindow, 0), 1)
        }
        return nil
    }

    private var deepBreathBinding: Binding<Bool> {
        Binding(
            get: { session.deepBreathEnabled },
            set: { session.setDeepBreathEnabled($0) }
        )
    }

    private var settingsLocked: Bool {
        session.isRunning
    }
}
