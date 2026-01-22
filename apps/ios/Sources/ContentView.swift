import SwiftUI
import PomafocusKit

struct ContentView: View {
    @ObservedObject private var session: PomodoroSessionController

    init(session: PomodoroSessionController) {
        self.session = session
    }

    var body: some View {
        TabView {
            PomodoroDashboardView(session: session)
                .tabItem {
                    Label("Focus", systemImage: "timer")
                }

            StatsDashboardView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
        }
    }
}

#Preview {
    ContentView(session: PomodoroSessionController())
}
