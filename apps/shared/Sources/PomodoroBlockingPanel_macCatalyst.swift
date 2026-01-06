#if os(iOS) && targetEnvironment(macCatalyst)
import SwiftUI
import PomafocusKit

struct PlatformBlockingPanel: View {
    @ObservedObject private var blocker: PomodoroBlocker
    @State private var showingSettings = false

    init(blocker: PomodoroBlocker = .shared) {
        self.blocker = blocker
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Distraction control", systemImage: "shield.righthalf.fill")
                .foregroundColor(.white.opacity(0.9))
                .font(.headline)
            Text(blockingSummary)
                .font(.footnote.monospaced())
                .foregroundColor(.white.opacity(0.8))

            Button {
                showingSettings = true
            } label: {
                Text("Manage Screen Time access")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showingSettings) {
            ScreenTimeSettingsView()
        }
    }

    private var blockingSummary: String {
        blocker.hasSelection ? blocker.selectionSummary : "No distractions configured"
    }
}
#endif
