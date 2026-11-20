import Testing
import Foundation
import SwiftData
@testable import Smash

@Suite("Backup export / import")
struct BackupTests {

    // MARK: Helpers

    private func makeContainer() -> ModelContainer {
        let schema = Schema([
            Player.self,
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

    @Test("Encrypted backup rejects an attacker-chosen work factor")
    func rejectsUnsupportedIterations() throws {
        let file: [String: Any] = [
            "smashEncryptedBackup": [
                "salt": Data(repeating: 1, count: 16).base64EncodedString(),
                "iterations": 1_000_000,
                "ciphertext": Data(repeating: 0, count: 28).base64EncodedString(),
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: file)
        #expect(throws: (any Error).self) {
            try BackupCrypto.decrypt(data, password: "smash123")
        }
    }

    // MARK: Import hardening

    private func bundleJSON(matches: [[String: Any]] = [], players: [[String: Any]] = []) throws -> Data {
        let root: [String: Any] = [
            "formatVersion": 1,
            "exportedAt": 0,
            "playSessions": [],
            "trainingSessions": [],
            "tournaments": [],
            "matches": matches,
            "players": players,
        ]
        return try JSONSerialization.data(withJSONObject: root)
    }

    private func matchJSON(games mine: [Int] = [21], _ theirs: [Int] = [10], date: Double = 0) -> [String: Any] {
        [
            "date": date,
            "opponent": "Ravi",
            "discipline": "singles",
            "pointSystem": "points21",
            "format": "bestOf3",
            "myGameScores": mine,
            "opponentGameScores": theirs,
        ]
    }

    @Test("Import clamps extreme and future dates")
    func clampsImportedDates() throws {
        let data = try bundleJSON(
            matches: [matchJSON(date: 1e300)],
            players: [["name": "Ravi", "addedAt": -1e300]]
        )
        let validated = try Backup.prepare(data)
        #expect(validated.matches.count == 1)
        #expect(validated.matches[0].date >= BackupFormat.minDate)
        #expect(validated.matches[0].date <= Date.now)
        #expect(validated.players[0].addedAt >= BackupFormat.minDate)
    }

    @Test("Import trims games a format never validates")
    func trimsExtraGames() throws {
        let data = try bundleJSON(matches: [matchJSON(games: [21, 10, 21, 50, 99], [10, 21, 15, 1, 1])])
        let validated = try Backup.prepare(data)
        #expect(validated.matches[0].myGameScores.count == 3)
        #expect(validated.matches[0].opponentGameScores.count == 3)
    }

    @Test("Import rejects an oversized record count before decoding models")
    func rejectsOversizedImport() throws {
        let matches = (0..<(BackupFormat.maxRecordsPerKind + 1)).map { _ in matchJSON() }
        let data = try bundleJSON(matches: matches)
        #expect(throws: (any Error).self) {
            try Backup.prepare(data)
        }
    }
}
