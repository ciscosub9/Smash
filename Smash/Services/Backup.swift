import Foundation
import SwiftData
import CryptoKit
import CommonCrypto

// MARK: - Snapshots
//
// Plain `Codable` structs mirroring each model. Backups are deliberately
// decoupled from SwiftData so they stay readable, diffable, and stable
// across schema migrations.

nonisolated struct PlaySessionSnapshot: Codable {
    var date: Date
    var durationMinutes: Int
    var discipline: String
    var intensity: String?
    var location: String?
    var opponents: [String]
    var notes: String?

    init(_ session: PlaySession) {
        date = session.date
        durationMinutes = session.durationMinutes
        discipline = session.disciplineRaw
        intensity = session.intensityRaw
        location = session.location
        opponents = session.opponents
        notes = session.notes
    }

    func insert(into context: ModelContext) {
        let session = PlaySession()
        session.date = date
        session.durationMinutes = durationMinutes
        session.disciplineRaw = discipline
        session.intensityRaw = intensity
        session.location = location
        session.opponents = opponents
        session.notes = notes
        context.insert(session)
    }
}

nonisolated struct TrainingSessionSnapshot: Codable {
    var date: Date
    var durationMinutes: Int
    var coach: String?
    var focusAreas: [String]
    var drillsDescription: String
    var drillName: String?
    var setsDone: Int?
    var intensity: String?
    var notes: String?

    init(_ session: TrainingSession) {
        date = session.date
        durationMinutes = session.durationMinutes
        coach = session.coach
        focusAreas = session.focusAreas
        drillsDescription = session.drillsDescription
        drillName = session.drillName
        setsDone = session.setsDone
        intensity = session.intensityRaw
        notes = session.notes
    }

    func insert(into context: ModelContext) {
        let session = TrainingSession()
        session.date = date
        session.durationMinutes = durationMinutes
        session.coach = coach
        session.focusAreas = focusAreas
        session.drillsDescription = drillsDescription
        session.drillName = drillName
        session.setsDone = setsDone
        session.intensityRaw = intensity
        session.notes = notes
        context.insert(session)
    }
}

nonisolated struct TournamentSnapshot: Codable {
    var id: UUID
    var name: String
    var type: String
    var startDate: Date
    var endDate: Date?
    var placement: String?
    var strategyNotes: String?

    init(_ tournament: Tournament) {
        id = tournament.id
        name = tournament.name
        type = tournament.typeRaw
        startDate = tournament.startDate
        endDate = tournament.endDate
        placement = tournament.placementRaw
        strategyNotes = tournament.strategyNotes
    }

    func insert(into context: ModelContext) -> Tournament {
        let tournament = Tournament()
        tournament.id = id
        tournament.name = name
        tournament.typeRaw = type
        tournament.startDate = startDate
        tournament.endDate = endDate
        tournament.placementRaw = placement
        tournament.strategyNotes = strategyNotes
        context.insert(tournament)
        return tournament
    }
}

nonisolated struct MatchSnapshot: Codable {
    var date: Date
    var opponent: String
    var discipline: String
    var pointSystem: String
    var format: String
    var myGameScores: [Int]
    var opponentGameScores: [Int]
    var notes: String?
    var opponentLevel: String?
    var intensity: String?
    var tournamentID: UUID?

    init(_ match: Match) {
        date = match.date
        opponent = match.opponent
        discipline = match.disciplineRaw
        pointSystem = match.pointSystemRaw
        format = match.formatRaw
        myGameScores = match.myGameScores
        opponentGameScores = match.opponentGameScores
        notes = match.notes
        opponentLevel = match.opponentLevelRaw
        intensity = match.intensityRaw
        tournamentID = match.tournament?.id
    }

    func insert(into context: ModelContext, tournament: Tournament?) {
        let match = Match()
        match.date = date
        match.opponent = opponent
        match.disciplineRaw = discipline
        match.pointSystemRaw = pointSystem
        match.formatRaw = format
        match.myGameScores = myGameScores
        match.opponentGameScores = opponentGameScores
        match.notes = notes
        match.opponentLevelRaw = opponentLevel
        match.intensityRaw = intensity
        match.tournament = tournament
        context.insert(match)
    }
}

nonisolated struct BackupBundle: Codable {
    /// Bump when the snapshot format changes; importers can migrate.
    var formatVersion: Int = 1
    var exportedAt: Date = Date()
    var player: PlayerProfileSnapshot?
    var playSessions: [PlaySessionSnapshot] = []
    var trainingSessions: [TrainingSessionSnapshot] = []
    var tournaments: [TournamentSnapshot] = []
    var matches: [MatchSnapshot] = []
}

// MARK: - Encryption
//
// Optional password protection for exported files:
// PBKDF2-SHA256 derives the key, AES-GCM authenticates and encrypts.
// A wrong password fails loudly (GCM tag mismatch) — never silently
// imports garbage.

nonisolated enum BackupCrypto {
    private struct EncryptedFile: Codable {
        /// Marker distinguishing encrypted files from plain JSON.
        var smashEncryptedBackup: Payload
    }

    private struct Payload: Codable {
        var salt: String
        var iterations: Int
        /// AES-GCM combined box: nonce + ciphertext + tag, base64.
        var ciphertext: String
    }

    static let iterations = 600_000

    static func isEncrypted(_ data: Data) -> Bool {
        (try? JSONDecoder().decode(EncryptedFile.self, from: data)) != nil
    }

    static func encrypt(_ plaintext: Data, password: String) throws -> Data {
        guard !password.isEmpty else {
            throw Backup.Failure(message: "Password can't be empty.")
        }

        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw Backup.Failure(message: "Couldn't generate encryption salt.")
        }

        let key = Self.key(password: password, salt: salt, iterations: iterations)
        let box = try AES.GCM.seal(plaintext, using: key)
        guard let combined = box.combined else {
            throw Backup.Failure(message: "Encryption failed.")
        }

        let file = EncryptedFile(smashEncryptedBackup: Payload(
            salt: salt.base64EncodedString(),
            iterations: iterations,
            ciphertext: combined.base64EncodedString()
        ))
        return try prettyJSONEncoder().encode(file)
    }

    static func decrypt(_ data: Data, password: String) throws -> Data {
        let file = try JSONDecoder().decode(EncryptedFile.self, from: data)
        guard let salt = Data(base64Encoded: file.smashEncryptedBackup.salt),
              let combined = Data(base64Encoded: file.smashEncryptedBackup.ciphertext) else {
            throw Backup.Failure(message: "Backup file is damaged.")
        }

        let key = Self.key(password: password, salt: salt, iterations: file.smashEncryptedBackup.iterations)
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(box, using: key)
        } catch {
            throw Backup.Failure(message: "Wrong password — the backup couldn't be decrypted.")
        }
    }

    private static func key(password: String, salt: Data, iterations: Int) -> SymmetricKey {
        SymmetricKey(data: pbkdf2(password: password, salt: salt, iterations: iterations))
    }

    /// PBKDF2-SHA256 via CommonCrypto.
    private static func pbkdf2(password: String, salt: Data, iterations: Int, keyLength: Int = 32) -> Data {
        let passwordData = Data(password.utf8)
        var derived = Data(repeating: 0, count: keyLength)

        let status = derived.withUnsafeMutableBytes { derivedBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.bindMemory(to: Int8.self).baseAddress,
                        passwordData.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedBytes.bindMemory(to: UInt8.self).baseAddress,
                        keyLength
                    )
                }
            }
        }
        precondition(status == kCCSuccess, "PBKDF2 key derivation failed")
        return derived
    }

    private static func prettyJSONEncoder() -> JSONEncoder {
        BackupFormat.prettyJSONEncoder()
    }
}

/// Shared by `BackupCrypto` and `Backup` — pretty, stable key order.
nonisolated enum BackupFormat {
    static func prettyJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

// MARK: - Export / import

nonisolated struct ImportSummary: Equatable {
    var playSessions = 0
    var trainingSessions = 0
    var tournaments = 0
    var matches = 0

    var description: String {
        var parts: [String] = []
        if playSessions > 0 { parts.append("\(playSessions) play") }
        if trainingSessions > 0 { parts.append("\(trainingSessions) training") }
        if matches > 0 { parts.append("\(matches) match" + (matches == 1 ? "" : "es")) }
        if tournaments > 0 { parts.append("\(tournaments) tournament" + (tournaments == 1 ? "" : "s")) }
        return parts.isEmpty ? "No records found in the file." : "Added " + parts.joined(separator: ", ") + "."
    }
}

nonisolated enum Backup {
    /// Human-readable failure messages surfaced directly in the Settings alert.
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Serializes everything in the store (plus the player profile) to JSON.
    static func exportData(context: ModelContext) throws -> Data {
        var bundle = BackupBundle()

        bundle.player = PlayerProfileSnapshot(
            name: PlayerProfile.name,
            skillLevel: PlayerProfile.skillLevel,
            goalKind: PlayerGoal.kind == .none ? nil : PlayerGoal.kind,
            goalTarget: PlayerGoal.kind == .none ? nil : PlayerGoal.target
        )
        bundle.playSessions = try context.fetch(FetchDescriptor<PlaySession>()).map(PlaySessionSnapshot.init)
        bundle.trainingSessions = try context.fetch(FetchDescriptor<TrainingSession>()).map(TrainingSessionSnapshot.init)
        bundle.tournaments = try context.fetch(FetchDescriptor<Tournament>()).map(TournamentSnapshot.init)
        bundle.matches = try context.fetch(FetchDescriptor<Match>()).map(MatchSnapshot.init)

        return try BackupFormat.prettyJSONEncoder().encode(bundle)
    }

    /// Inserts every record in the bundle. Existing records are never
    /// touched or replaced; tournament ↔ match links are re-established.
    static func importData(_ data: Data, into context: ModelContext) throws -> ImportSummary {
        let bundle: BackupBundle
        do {
            bundle = try JSONDecoder().decode(BackupBundle.self, from: data)
        } catch {
            throw Backup.Failure(message: "This isn't a Smash backup file.")
        }

        var summary = ImportSummary()

        if let player = bundle.player {
            PlayerProfile.name = player.name
            PlayerProfile.skillLevel = player.skill
            if let goal = player.goal {
                PlayerGoal.kind = goal
                PlayerGoal.target = player.goalTarget ?? PlayerGoal.target
            }
        }

        let tournamentsById = Dictionary(
            uniqueKeysWithValues: bundle.tournaments.map { ($0.id, $0.insert(into: context)) }
        )
        summary.tournaments = bundle.tournaments.count

        for snapshot in bundle.playSessions {
            snapshot.insert(into: context)
            summary.playSessions += 1
        }
        for snapshot in bundle.trainingSessions {
            snapshot.insert(into: context)
            summary.trainingSessions += 1
        }
        for snapshot in bundle.matches {
            snapshot.insert(into: context, tournament: snapshot.tournamentID.flatMap { tournamentsById[$0] })
            summary.matches += 1
        }

        return summary
    }
}
