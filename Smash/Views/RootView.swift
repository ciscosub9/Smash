import SwiftUI

/// Root navigation: five tabs, each named for its contents (wayfinding —
/// specific labels beat vague ones). Settings lives on the Dashboard toolbar.
struct RootView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }

            PlayListView()
                .tabItem { Label("Play", systemImage: "figure.play") }

            MatchListView()
                .tabItem { Label("Matches", systemImage: "trophy") }

            TrainingListView()
                .tabItem { Label("Training", systemImage: "dumbbell") }

            TournamentListView()
                .tabItem { Label("Tournaments", systemImage: "medal") }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewContainer.container)
}
