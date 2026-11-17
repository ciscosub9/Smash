import Testing
import Foundation
import SwiftData
@testable import Smash

@Suite("Backup export / import")
struct BackupTests {

    // MARK: Helpers

    private func makeContainer() -> ModelContainer {
        let schema = Schema([
            PlaySession.self,
            TrainingSession.self,
            Match.self,
            Tournament.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try! ModelContainer(for: schema, configurations: [config])
    }

    // MARK: Plain round-trip

    @Test("Export then import preserves every record type")
    func roundTrip() throws {
        let source = makeContainer()
        SampleData.seed(context: source.mainContext)

        let data = try Backup.exportData(context: source.mainContext)

        let destination = makeContainer()
        let summary = try Backup.importData(data, into: destination.mainContext)

        #expect(summary.matches == 3)
        #expect(summary.playSessions == 4)
        #expect(summary.trainingSessions == 2)
        #expect(summary.tournaments == 1)

        let importedMatches = try destination.mainContext.fetch(FetchDescriptor<Match>())
        #expect(importedMatches.count == 3)

        // Tournament ↔ match link survives the trip.
        let linked = importedMatches.first { $0.tournament != nil }
        #expect(linked?.tournament?.name == "Club Open 2026")

        // New per-record fields survive too.
        #expect(linked?.opponentLevel == .intermediate)
        #expect(linked?.intensity == .hard)

        let importedTraining = try destination.mainContext.fetch(FetchDescriptor<TrainingSession>())
        #expect(importedTraining.contains { $0.drillName == "Multi-shuttle" && $0.setsDone == 6 && $0.intensity == .hard })
    }

    // MARK: Encryption

    @Test("Encrypted round-trip returns the original bytes")
    func encryptedRoundTrip() throws {
        let source = makeContainer()
        SampleData.seed(context: source.mainContext)
        let plaintext = try Backup.exportData(context: source.mainContext)

        let encrypted = try BackupCrypto.encrypt(plaintext, password: "smash123")

        #expect(BackupCrypto.isEncrypted(encrypted))
        #expect(!BackupCrypto.isEncrypted(plaintext))

        let decrypted = try BackupCrypto.decrypt(encrypted, password: "smash123")
        #expect(decrypted == plaintext)
    }

    @Test("Wrong password fails loudly, not silently")
    func wrongPasswordThrows() throws {
        let source = makeContainer()
        SampleData.seed(context: source.mainContext)
        let plaintext = try Backup.exportData(context: source.mainContext)

        let encrypted = try BackupCrypto.encrypt(plaintext, password: "correct-horse")

        #expect(throws: (any Error).self) {
            try BackupCrypto.decrypt(encrypted, password: "battery-staple")
        }
    }

    @Test("Empty password is rejected before encryption")
    func emptyPasswordRejected() throws {
        #expect(throws: (any Error).self) {
            try BackupCrypto.encrypt(Data("secret".utf8), password: "")
        }
    }
}
