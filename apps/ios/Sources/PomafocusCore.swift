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
    }

    func refreshLiveActivity() {
        experienceCoordinator.refreshLiveActivity()
    }
}
