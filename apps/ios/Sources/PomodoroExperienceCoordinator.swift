import Foundation
import Combine
import Dispatch
import PomafocusKit

@MainActor
final class PomodoroExperienceCoordinator: ObservableObject {
    private let soundPlayer = PomodoroSoundPlayer()
    private let liveActivityManager = PomodoroLiveActivityManager()
    private let session: PomodoroSessionController
    private var cancellables: Set<AnyCancellable> = []

    init(session: PomodoroSessionController) {
        self.session = session
        liveActivityManager.bind(to: session)

        session.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak session] event in
                guard let self, let session else { return }
                switch event {
                case .started:
                    self.soundPlayer.playStart()
                    self.liveActivityManager.startOrUpdate(from: session)
                case .stopped:
                    self.liveActivityManager.end()
                case .completed:
                    self.soundPlayer.playCompletion()
                    self.liveActivityManager.end()
                }
            }
            .store(in: &cancellables)

        session.$remaining
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak session] _ in
                guard let self, let session, session.isRunning else { return }
                self.liveActivityManager.startOrUpdate(from: session)
            }
            .store(in: &cancellables)
    }

    func refreshLiveActivity() async {
        await liveActivityManager.startOrUpdateImmediately(from: session)
    }
}
