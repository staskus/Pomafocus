import Foundation
import PomafocusKit

@MainActor
final class PomafocusCore: ObservableObject {
    static let shared = PomafocusCore()

    let session: PomodoroSessionController
    private let experienceCoordinator: PomodoroExperienceCoordinator
    private var widgetCommandTimer: Timer?

    private init() {
        let session = PomodoroSessionController()
        self.session = session
        self.experienceCoordinator = PomodoroExperienceCoordinator(session: session)
        startWidgetCommandPolling()
    }

    func refreshLiveActivity() async {
        await experienceCoordinator.refreshLiveActivity()
    }

    func checkWidgetCommands() {
        session.checkWidgetCommands()
    }

    private func startWidgetCommandPolling() {
        // Check for widget commands every 0.5 seconds
        widgetCommandTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkWidgetCommands()
            }
        }
    }
}
