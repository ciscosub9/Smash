import SwiftUI

/// Root navigation: five tabs, each named for its contents (wayfinding —
/// specific labels beat vague ones). Settings lives on the Dashboard toolbar.
struct RootView: View {
    @State private var selection = Tab.initialFromLaunchArguments

    enum Tab: String, CaseIterable {
        case dashboard, play, matches, training, tournaments

        /// Screenshots and UI tests can open the app directly on a tab:
        /// `simctl launch com.smashapp.smash -tab matches`
        static var initialFromLaunchArguments: Tab {
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: "-tab"), index + 1 < arguments.count,
                  let tab = Tab(rawValue: arguments[index + 1]) else { return .dashboard }
            return tab
        }
    }

    var body: some View {
        TabView(selection: $selection) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
                .tag(Tab.dashboard)

            PlayListView()
                .tabItem { Label("Play", systemImage: "figure.play") }
                .tag(Tab.play)

            MatchListView()
                .tabItem { Label("Matches", systemImage: "trophy") }
                .tag(Tab.matches)

            TrainingListView()
                .tabItem { Label("Training", systemImage: "dumbbell") }
                .tag(Tab.training)

            TournamentListView()
                .tabItem { Label("Tournaments", systemImage: "medal") }
                .tag(Tab.tournaments)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewContainer.container)
}
