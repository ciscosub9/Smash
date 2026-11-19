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

/// Owns the app's `ModelContainer` and migrates data when the user switches
/// between local and iCloud storage in Settings.
@MainActor
@Observable
final class SmashStore {
    private(set) var container: ModelContainer
    private(set) var syncMode: SyncMode
    /// Set when iCloud was requested but could not be set up
    /// (missing entitlement, no iCloud account, …). The previous store stays active.
    private(set) var iCloudUnavailable = false

    private static let schema = Schema([
        PlaySession.self,
        TrainingSession.self,
        Match.self,
        Tournament.self,
    ])

    init(syncMode: SyncMode = .local) {
        self.syncMode = syncMode
        let result = Self.makeContainer(for: syncMode)
        self.container = result.container
        self.iCloudUnavailable = syncMode == .iCloud && !result.cloudActive
    }

    /// Copies every record from the current store into the destination store,
    /// then makes the destination active. Returns what was moved, or `nil`
    /// if nothing changed (or the destination couldn't be opened).
    @discardableResult
    func migrate(to mode: SyncMode, from sourceContext: ModelContext) throws -> ImportSummary? {
        guard mode != syncMode else { return nil }

        let result = Self.makeContainer(for: mode)
        if mode == .iCloud && !result.cloudActive {
            // Don't leave the user on an empty/broken iCloud store.
            iCloudUnavailable = true
            return nil
        }

        let snapshot = try Backup.exportData(context: sourceContext)
        let destinationContext = ModelContext(result.container)
        let summary = try Backup.importData(snapshot, into: destinationContext)
        try destinationContext.save()

        container = result.container
        syncMode = mode
        iCloudUnavailable = false
        UserDefaults.standard.set(mode.rawValue, forKey: Self.syncModeKey)
        return summary
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
