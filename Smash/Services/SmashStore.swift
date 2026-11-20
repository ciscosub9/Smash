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
    /// Set when a store could not be opened. The app keeps running on an
    /// in-memory container so the UI doesn't crash; changes won't survive a
    /// relaunch until the underlying problem (disk, migration, …) is fixed.
    private(set) var storeError: String?

    private static let schema = Schema([
        PlaySession.self,
        TrainingSession.self,
        Match.self,
        Tournament.self,
        Player.self,
    ])

    init(syncMode: SyncMode = .local) {
        self.syncMode = syncMode
        let result = Self.makeContainer(for: syncMode)
        self.container = result.container
        self.iCloudUnavailable = syncMode == .iCloud && !result.cloudActive
        self.storeError = result.errorMessage
    }

    /// Copies every record from the current store into the destination store,
    /// then makes the destination active. Returns what was moved, or `nil`
    /// if nothing changed (or the destination couldn't be opened).
    @discardableResult
    func migrate(to mode: SyncMode, from sourceContext: ModelContext) async throws -> ImportSummary? {
        guard mode != syncMode else { return nil }

        let result = Self.makeContainer(for: mode)
        if mode == .iCloud && !result.cloudActive {
            // Don't leave the user on an empty/broken iCloud store.
            iCloudUnavailable = true
            storeError = result.errorMessage
            return nil
        }

        // Reading SwiftData models stays here on the main actor. Decoding and
        // validation run in a detached task so a large backup can't block UI.
        let bundle = try Backup.makeBundle(context: sourceContext)
        let validated = try await Task.detached(priority: .userInitiated) {
            try Backup.prepare(try Backup.encode(bundle))
        }.value

        let destinationContext = ModelContext(result.container)
        let summary = try Backup.apply(validated, into: destinationContext)

        container = result.container
        syncMode = mode
        iCloudUnavailable = false
        storeError = result.errorMessage
        UserDefaults.standard.set(mode.rawValue, forKey: Self.syncModeKey)
        return summary
    }

    // MARK: - Container construction

    static let syncModeKey = "SmashSyncMode"

    static func currentMode() -> SyncMode {
        SyncMode(rawValue: UserDefaults.standard.string(forKey: syncModeKey) ?? "") ?? .local
    }

    private struct ContainerResult {
        let container: ModelContainer
        let cloudActive: Bool
        let errorMessage: String?
    }

    private static func makeContainer(for mode: SyncMode) -> ContainerResult {
        switch mode {
        case .local:
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            do {
                return ContainerResult(
                    container: try ModelContainer(for: schema, configurations: [config]),
                    cloudActive: false,
                    errorMessage: nil
                )
            } catch {
                Logger(subsystem: "com.smashapp.smash", category: "Store")
                    .error("Local store unavailable, using memory: \(error.localizedDescription)")
                return fallback(error: error)
            }

        case .iCloud:
            do {
                let config = ModelConfiguration(
                    schema: schema,
                    cloudKitDatabase: .private("iCloud.com.smashapp.smash")
                )
                let container = try ModelContainer(for: schema, configurations: [config])
                return ContainerResult(container: container, cloudActive: true, errorMessage: nil)
            } catch {
                // CloudKit needs the iCloud entitlement, a signed-in account and
                // provisioning. If any of that is missing, fall back to local
                // storage rather than crashing.
                Logger(subsystem: "com.smashapp.smash", category: "Store")
                    .error("iCloud unavailable, falling back to local: \(error.localizedDescription)")
                let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
                do {
                    return ContainerResult(
                        container: try ModelContainer(for: schema, configurations: [config]),
                        cloudActive: false,
                        errorMessage: "iCloud isn't available right now. Smash is using on-device storage."
                    )
                } catch {
                    Logger(subsystem: "com.smashapp.smash", category: "Store")
                        .error("Local store also unavailable: \(error.localizedDescription)")
                    return fallback(error: error)
                }
            }
        }
    }

    /// Last resort: keep the app running with a transient store and surface
    /// the reason in Settings. A fixed-schema in-memory container only fails
    /// for an impossible system state, so the forced try is confined here.
    private static func fallback(error: Error) -> ContainerResult {
        let message = "Smash couldn't open your saved data (\(error.localizedDescription)). Changes made now won't be kept after you close the app."
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(for: schema, configurations: [config])
        return ContainerResult(container: container, cloudActive: false, errorMessage: message)
    }
}
