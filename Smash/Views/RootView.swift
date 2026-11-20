import SwiftUI

/// Root navigation: four tabs — Dashboard, Players, Sessions and Tournaments.
/// Everything you log lives in Sessions, so there's one place to look and one
/// way to add something. The player card, with Settings inside it, sits in the
/// Dashboard's top-left corner.
struct RootView: View {
    @State private var selection = Tab.initialFromLaunchArguments
    @State private var showOnboarding = !PlayerProfile.onboardingCompleted
    @State private var showTour = PlayerProfile.onboardingCompleted && !PlayerProfile.appTourCompleted
    /// Set once when the app is launched. Minimising only backgrounds the
    /// scene, so this stays false and the splash does not replay.
    @State private var showSplash = true

    enum Tab: String, CaseIterable {
        case dashboard, players, sessions, tournaments

        /// Screenshots and UI tests can open the app directly on a tab:
        /// `simctl launch com.smashapp.smash -tab sessions`
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

            PlayersView()
                .tabItem { Label("Players", systemImage: "person.2") }
                .tag(Tab.players)

            SessionsView()
                .tabItem { Label("Sessions", systemImage: "figure.play") }
                .tag(Tab.sessions)

            TournamentListView()
                .tabItem { Label("Tournaments", systemImage: "medal") }
                .tag(Tab.tournaments)
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showTour) {
            AppTourView()
        }
        .onChange(of: showOnboarding) { _, isShowing in
            if !isShowing && !PlayerProfile.appTourCompleted { showTour = true }
        }
        .overlay {
            if showSplash {
                SplashView { showSplash = false }
            }
        }
        .environment(\.tabSelection, $selection)
    }
}

/// Lets a screen send the user back to All sessions after saving an edit, no
/// matter which tab they opened the detail from.
private struct TabSelectionKey: EnvironmentKey {
    static let defaultValue: Binding<RootView.Tab> = .constant(.dashboard)
}

extension EnvironmentValues {
    var tabSelection: Binding<RootView.Tab> {
        get { self[TabSelectionKey.self] }
        set { self[TabSelectionKey.self] = newValue }
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewContainer.container)
}
