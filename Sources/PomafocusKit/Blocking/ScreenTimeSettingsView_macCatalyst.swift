#if os(iOS) && targetEnvironment(macCatalyst)
import SwiftUI

public struct ScreenTimeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var blocker = PomodoroBlocker.shared
    @State private var websitesText: String

    public init() {
        _websitesText = State(initialValue: PomodoroBlocker.shared.blockedWebsites.joined(separator: "\n"))
    }

    public var body: some View {
        Form {
            Section("Blocked websites") {
                TextEditor(text: $websitesText)
                    .font(.body.monospaced())
                    .frame(minHeight: 200)
                Text("Enter one domain per line. Pomafocus will remember this list locally on this Mac.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section {
                Button("Save") {
                    applyChanges()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 320)
    }

    private func applyChanges() {
        let websites = websitesText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        blocker.setBlockedWebsites(websites)
    }
}
#endif
