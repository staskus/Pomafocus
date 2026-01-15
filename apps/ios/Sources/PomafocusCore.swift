import Foundation
import PomafocusKit

@MainActor
final class PomafocusCore: ObservableObject {
    static let shared = PomafocusCore()

    let session: PomodoroSessionController
    private let experienceCoordinator: PomodoroExperienceCoordinator

    private init() {
        let session = PomodoroSessionController()
        self.session = session
        self.experienceCoordinator = PomodoroExperienceCoordinator(session: session)
        wireRemoteCommands()
    }

    func refreshLiveActivity() async {
        await experienceCoordinator.refreshLiveActivity()
    }

    private func wireRemoteCommands() {
        PomodoroSyncManager.shared.onTimerCommand = { [weak self] command in
            self?.session.handleRemoteCommand(command)
        }
    }
}
