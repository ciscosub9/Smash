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
        PlayerGoal.kind = .weekly
        PlayerGoal.target = 5

        let sourceMatches = try source.mainContext.fetch(FetchDescriptor<Match>())
        let sourcePlay = try source.mainContext.fetch(FetchDescriptor<PlaySession>())
        let sourceTraining = try source.mainContext.fetch(FetchDescriptor<TrainingSession>())
        let sourceTournaments = try source.mainContext.fetch(FetchDescriptor<Tournament>())

        let data = try Backup.exportData(context: source.mainContext)

        let destination = makeContainer()
        let summary = try Backup.importData(data, into: destination.mainContext)

        #expect(summary.matches == sourceMatches.count)
        #expect(summary.playSessions == sourcePlay.count)
        #expect(summary.trainingSessions == sourceTraining.count)
        #expect(summary.tournaments == sourceTournaments.count)

        // The goal rides along in the backup.
        #expect(PlayerGoal.kind == .weekly)
        #expect(PlayerGoal.target == 5)
        PlayerGoal.kind = .none

        let importedMatches = try destination.mainContext.fetch(FetchDescriptor<Match>())
        #expect(importedMatches.count == sourceMatches.count)

        // Tournament ↔ match link survives the trip.
        let clubOpenMatch = importedMatches.first {
            $0.tournament?.name == "Club Open 2026" && $0.opponent == "Ravi"
        }
        #expect(clubOpenMatch != nil)
        #expect(clubOpenMatch?.opponentLevel == .intermediate)
        #expect(clubOpenMatch?.intensity == .hard)

        let importedTraining = try destination.mainContext.fetch(FetchDescriptor<TrainingSession>())
        let multiShuttle = importedTraining.first { $0.drillNames.contains("Multi-shuttle") }
        #expect(multiShuttle != nil)
        #expect(multiShuttle?.drillNames == ["Multi-shuttle", "Net kills"])
        #expect(multiShuttle?.drillSets == [6, 4])
        #expect(multiShuttle?.drillEntries.map(\.intensity) == [.hard, .moderate])
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
