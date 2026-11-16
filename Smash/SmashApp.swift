import SwiftUI
import SwiftData

@main
struct SmashApp: App {
    @State private var store = SmashStore(syncMode: SmashStore.currentMode())

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(store.container)
                .environment(store)
                .tint(.accentColor)
        }
    }
}
