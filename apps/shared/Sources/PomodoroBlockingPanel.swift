import SwiftUI
import PomafocusKit

@MainActor
struct PlatformBlockingPanel: View {
    @StateObject private var blocker: PomodoroBlocker
    @State private var showingScreenTime = false
    private let isDisabled: Bool

    init(blocker: PomodoroBlocker? = nil, isDisabled: Bool = false) {
        _blocker = StateObject(wrappedValue: blocker ?? PomodoroBlocker.shared)
        self.isDisabled = isDisabled
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
            .disabled(isDisabled)
        }
        .sheet(isPresented: $showingScreenTime) {
            ScreenTimeSettingsView()
        }
        .opacity(isDisabled ? 0.5 : 1)
        .allowsHitTesting(!isDisabled)
    }

    private var blockingSummary: String {
        blocker.hasSelection ? blocker.selectionSummary : "No distractions selected"
    }
}
