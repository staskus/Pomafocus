import Foundation
import PomafocusKit

@MainActor
final class PomafocusCore: ObservableObject {
    static let shared = PomafocusCore()

    let session: PomodoroSessionController
    let scheduleStore: ScheduleStore
    private let experienceCoordinator: PomodoroExperienceCoordinator
    private let scheduleCoordinator: ScheduleCoordinator
    private var widgetCommandTimer: Timer?

    private init() {
        let session = PomodoroSessionController()
        self.session = session
        let store = ScheduleStore()
        self.scheduleStore = store
        self.experienceCoordinator = PomodoroExperienceCoordinator(session: session)
        self.scheduleCoordinator = ScheduleCoordinator(session: session, blocker: PomodoroBlocker.shared, store: store)
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
