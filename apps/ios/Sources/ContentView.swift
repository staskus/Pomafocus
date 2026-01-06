import SwiftUI
import PomafocusKit

struct ContentView: View {
    @ObservedObject private var session: PomodoroSessionController

    init(session: PomodoroSessionController) {
        self.session = session
    }

    var body: some View {
        PomodoroDashboardView(session: session)
    }
}

#Preview {
    ContentView(session: PomodoroSessionController())
}
