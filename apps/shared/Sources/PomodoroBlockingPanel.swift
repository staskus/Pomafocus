import SwiftUI
import PomafocusKit

@MainActor
struct PlatformBlockingPanel: View {
    @StateObject private var blocker: PomodoroBlocker
    @State private var showingScreenTime = false

    init(blocker: PomodoroBlocker? = nil) {
        _blocker = StateObject(wrappedValue: blocker ?? PomodoroBlocker.shared)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Screen Time blocking", systemImage: "shield.lefthalf.fill")
                .foregroundColor(.white.opacity(0.9))
                .font(.headline)
            Text(blockingSummary)
                .font(.footnote.monospaced())
                .foregroundColor(.white.opacity(0.8))

            Button {
                showingScreenTime = true
            } label: {
                Text("Choose apps & websites")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showingScreenTime) {
            ScreenTimeSettingsView()
        }
    }

    private var blockingSummary: String {
        blocker.hasSelection ? blocker.selectionSummary : "No distractions selected"
    }
}
