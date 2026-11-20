import SwiftUI
import SwiftData

@main
struct SmashApp: App {
    @State private var store = SmashStore(syncMode: SmashStore.currentMode())
    @AppStorage(AppearancePreference.storageKey) private var appearanceRaw = AppearancePreference.dark.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(store.container)
                .environment(store)
                .tint(.accentColor)
                .preferredColorScheme(AppearancePreference(rawValue: appearanceRaw)?.colorScheme)
                .task {
                    // Demo content is a test-only aid; never seed it in a
                    // shipping build (Apple 2.5.19, no dormant features).
                    #if DEBUG
                    if CommandLine.arguments.contains("-sampleData") {
                        SampleData.seedIfNeeded(context: store.container.mainContext)
                    }
                    #endif
                }
        }
    }
}
