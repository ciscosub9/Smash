import Foundation
import Observation
import SwiftData
import os

/// Where Smash stores its data.
enum SyncMode: String, CaseIterable {
    case local
    case iCloud
    var label: String {
        switch self {
        case .local: "On this iPhone"
        case .iCloud: "iCloud"
        }
    }

    var description: String {
        switch self {
        case .local:
            "Everything stays on this device. Private by default."
        case .iCloud:
            "Data syncs through your iCloud account to your other devices."
        }
    }
}

/// Owns the app's `ModelContainer` and rebuilds it when the user switches
/// between local and iCloud storage in Settings.
///
/// Note: the local and iCloud stores are separate files. Existing records
/// remain in the store they were created in — switching mode does not move
/// data. The Settings screen says so in plain words.
@MainActor
@Observable
final class SmashStore {
    private(set) var container: ModelContainer
    private(set) var syncMode: SyncMode
    /// Set when iCloud was requested but could not be set up
    /// (missing entitlement, no iCloud account, …). Falls back to local.
    private(set) var iCloudUnavailable = false

    private static let schema = Schema([
        PlaySession.self,
        TrainingSession.self,
        Match.self,
        Tournament.self,
    ])

    init(syncMode: SyncMode = .local) {
        self.syncMode = syncMode
        self.container = Self.makeContainer(for: syncMode).container
        self.iCloudUnavailable = syncMode == .iCloud && !Self.makeContainer(for: syncMode).cloudActive
    }

    /// Switches storage mode. Call from Settings.
    func switchMode(_ mode: SyncMode) {
        guard mode != syncMode else { return }
        syncMode = mode
        let result = Self.makeContainer(for: mode)
        container = result.container
        iCloudUnavailable = mode == .iCloud && !result.cloudActive
        UserDefaults.standard.set(mode.rawValue, forKey: Self.syncModeKey)
    }

    // MARK: - Container construction

    static let syncModeKey = "SmashSyncMode"

    static func currentMode() -> SyncMode {
        SyncMode(rawValue: UserDefaults.standard.string(forKey: syncModeKey) ?? "") ?? .local
    }

    private static func makeContainer(for mode: SyncMode) -> (container: ModelContainer, cloudActive: Bool) {
        switch mode {
        case .local:
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            let container = try! ModelContainer(for: schema, configurations: [config])
            return (container, false)

        case .iCloud:
            do {
                let config = ModelConfiguration(
                    schema: schema,
                    cloudKitDatabase: .private("iCloud.com.smashapp.smash")
                )
                let container = try ModelContainer(for: schema, configurations: [config])
                return (container, true)
            } catch {
                // CloudKit needs the iCloud entitlement, a signed-in account and
                // provisioning. If any of that is missing, fall back to local
                // storage rather than crashing.
                Logger(subsystem: "com.smashapp.smash", category: "Store")
                    .error("iCloud unavailable, falling back to local: \(error.localizedDescription)")
                let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
                let container = try! ModelContainer(for: schema, configurations: [config])
                return (container, false)
            }
        }
    }
}
