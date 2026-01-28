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
            PomodoroDashboardView(session: session, bannerText: scheduleBannerText)
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

    private var scheduleBannerText: String? {
        guard scheduleStore.activeBlock != nil else { return nil }
        return "Schedule in progress"
    }
}

#Preview {
    ContentView(session: PomodoroSessionController(), scheduleStore: ScheduleStore())
}
