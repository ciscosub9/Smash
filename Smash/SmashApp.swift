import SwiftUI
import SwiftData

@main
struct SmashApp: App {
    @State private var store = SmashStore(syncMode: SmashStore.currentMode())
    @AppStorage(AppearancePreference.storageKey) private var appearanceRaw = AppearancePreference.system.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(store.container)
                .environment(store)
                .tint(.accentColor)
                .preferredColorScheme(AppearancePreference(rawValue: appearanceRaw)?.colorScheme)
                .task {
                    if CommandLine.arguments.contains("-sampleData") {
                        SampleData.seedIfNeeded(context: store.container.mainContext)
                    }
                }
        }
    }
}
