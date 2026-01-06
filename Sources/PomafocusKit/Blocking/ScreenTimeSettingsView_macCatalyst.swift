#if os(iOS) && targetEnvironment(macCatalyst)
import SwiftUI
import FamilyControls

public struct ScreenTimeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var blocker = PomodoroBlocker.shared

    @State private var showingPicker = false
    @State private var authorizationError: String?
    @State private var isRequestInFlight = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Distraction Shield")
                .font(.title2.bold())

            Text("Choose which apps or websites macOS should pause whenever Pomafocus is running.")
                .foregroundColor(.secondary)

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text(blocker.hasSelection ? blocker.selectionSummary : "No items selected")
                        .font(.body.monospaced())

                    Button {
                        showingPicker = true
                    } label: {
                        Label("Pick distractions", systemImage: "cursorarrow.click")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    if blocker.hasSelection {
                        Button(role: .destructive) {
                            blocker.selection = FamilyActivitySelection()
                        } label: {
                            Text("Clear selection")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            if let authorizationError {
                Text(authorizationError)
                    .foregroundColor(.red)
                    .font(.footnote)
            }

            Spacer()

            HStack {
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    Task {
                        await requestAuthorization()
                    }
                } label: {
                    HStack {
                        if isRequestInFlight {
                            ProgressView()
                        }
                        Text("Request Access")
                    }
                }
                .disabled(isRequestInFlight)
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 320)
        .familyActivityPicker(isPresented: $showingPicker, selection: $blocker.selection)
        .task {
            await requestAuthorization()
        }
    }

    private func requestAuthorization() async {
        guard !isRequestInFlight else { return }
        isRequestInFlight = true
        let granted = await blocker.ensureAuthorization()
        await MainActor.run {
            authorizationError = granted ? nil : "Screen Time access is required in macOS Settings → Screen Time."
            isRequestInFlight = false
        }
    }
}
#endif
