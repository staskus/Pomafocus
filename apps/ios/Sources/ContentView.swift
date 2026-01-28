import SwiftUI
import Observation
import PomafocusKit

struct ContentView: View {
    @ObservedObject private var session: PomodoroSessionController
    @Bindable private var scheduleStore: ScheduleStore

    init(session: PomodoroSessionController, scheduleStore: ScheduleStore) {
        self.session = session
        self.scheduleStore = scheduleStore
    }

    var body: some View {
        TabView {
            PomodoroDashboardView(
                session: session,
                statusOverrideText: scheduleStatusText,
                statusOverrideColor: scheduleStatusColor
            )
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

    private var scheduleStatusText: String? {
        scheduleStore.activeBlock != nil ? "Schedule in progress" : nil
    }

    private var scheduleStatusColor: Color? {
        scheduleStore.activeBlock != nil ? BrutalistColors.yellow : nil
    }
}

#Preview {
    ContentView(session: PomodoroSessionController(), scheduleStore: ScheduleStore())
}
