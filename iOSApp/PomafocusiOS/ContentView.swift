import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PomodoroViewModel()

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text(viewModel.remainingDisplay)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(viewModel.isRunning ? "In progress" : "Idle")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            Button(action: viewModel.toggleTimer) {
                Text(viewModel.isRunning ? "Stop" : "Start")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isRunning ? Color.red : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Session length")
                    Spacer()
                    Text("\(viewModel.minutes) min")
                        .font(.body.monospacedDigit())
                }
                Stepper(
                    value: Binding(
                        get: { viewModel.minutes },
                        set: { viewModel.setMinutes($0) }
                    ),
                    in: 1...90
                ) {
                    Text("Adjust duration")
                }
                .disabled(viewModel.isRunning)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
