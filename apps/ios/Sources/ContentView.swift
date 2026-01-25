import SwiftUI
import PomafocusKit

struct ContentView: View {
    @ObservedObject private var session: PomodoroSessionController
    private let scheduleStore: ScheduleStore

    init(session: PomodoroSessionController, scheduleStore: ScheduleStore) {
        self.session = session
        self.scheduleStore = scheduleStore
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

            ScheduleDashboardView(store: scheduleStore)
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
        }
    }
}

#Preview {
    ContentView(session: PomodoroSessionController(), scheduleStore: ScheduleStore())
}
