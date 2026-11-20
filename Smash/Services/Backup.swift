import Foundation
import SwiftData
import CryptoKit
import CommonCrypto

// MARK: - Snapshots
//
// Plain `Codable` structs mirroring each model. Backups are deliberately
// decoupled from SwiftData so they stay readable, diffable, and stable
// across schema migrations. Nothing here is trusted until `Backup.prepare`
// has sanitized it.

nonisolated struct PlaySessionSnapshot: Codable, Sendable {
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

nonisolated struct TrainingSessionSnapshot: Codable, Sendable {
    var date: Date
    var durationMinutes: Int
    var focusAreas: [String]
    var drillsDescription: String
    var drillNames: [String]
    var drillSets: [Int]
    var drillIntensities: [String]
    var setsDone: Int?
    var intensity: String?
    var notes: String?

    /// Older backups stored one `drillName`; it becomes the first entry of
    /// `drillNames`. A legacy `coach` key is ignored during decoding.
    var drillName: String?

    private enum CodingKeys: String, CodingKey {
        case date, durationMinutes, focusAreas, drillsDescription
        case drillNames, drillSets, drillIntensities, setsDone, intensity, notes, drillName
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        date = try values.decode(Date.self, forKey: .date)
        durationMinutes = try values.decode(Int.self, forKey: .durationMinutes)
        focusAreas = try values.decodeIfPresent([String].self, forKey: .focusAreas) ?? []
        drillsDescription = try values.decodeIfPresent(String.self, forKey: .drillsDescription) ?? ""
        drillNames = try values.decodeIfPresent([String].self, forKey: .drillNames) ?? []
        drillSets = try values.decodeIfPresent([Int].self, forKey: .drillSets) ?? []
        drillIntensities = try values.decodeIfPresent([String].self, forKey: .drillIntensities) ?? []
        setsDone = try values.decodeIfPresent(Int.self, forKey: .setsDone)
        intensity = try values.decodeIfPresent(String.self, forKey: .intensity)
        notes = try values.decodeIfPresent(String.self, forKey: .notes)
        drillName = try values.decodeIfPresent(String.self, forKey: .drillName)
    }

    init(_ session: TrainingSession) {
        date = session.date
        durationMinutes = session.durationMinutes
        focusAreas = session.focusAreas
        drillsDescription = session.drillsDescription
        drillNames = session.drillNames
        drillSets = session.drillSets
        drillIntensities = session.drillIntensities
        setsDone = session.setsDone
        intensity = session.intensityRaw
        notes = session.notes
        drillName = nil
    }

    func insert(into context: ModelContext) {
        let session = TrainingSession()
        session.date = date
        session.durationMinutes = durationMinutes
        session.focusAreas = focusAreas
        session.drillsDescription = drillsDescription
        let names = drillNames.isEmpty ? (drillName.map { [$0] } ?? []) : drillNames
        session.drillNames = names
        if !drillSets.isEmpty || !drillIntensities.isEmpty {
            session.drillSets = drillSets
            session.drillIntensities = drillIntensities
        } else {
            session.drillSets = setsDone.map { Array(repeating: $0, count: names.count) } ?? []
            session.drillIntensities = intensity.map { Array(repeating: $0, count: names.count) } ?? []
        }
        session.setsDone = setsDone
        session.intensityRaw = intensity
        session.notes = notes
        context.insert(session)
    }
}

nonisolated struct TournamentSnapshot: Codable, Sendable {
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

nonisolated struct MatchSnapshot: Codable, Sendable {
    var date: Date
    var opponent: String
    /// Optional so backups made before partners existed still import cleanly.
    var partner: String?
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
        partner = match.partner.isEmpty ? nil : match.partner
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
        match.partner = partner ?? ""
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

nonisolated struct PlayerSnapshot: Codable, Sendable {
    var name: String
    var level: String?
    var notes: String?
    var addedAt: Date

    init(_ player: Player) {
        name = player.name
        level = player.levelRaw
        notes = player.notes
        addedAt = player.addedAt
    }

    func insert(into context: ModelContext) {
        context.insert(Player(name: name, level: level.flatMap(SkillLevel.init(rawValue:)), notes: notes, addedAt: addedAt))
    }
}

nonisolated struct BackupBundle: Codable, Sendable {
    /// Bump when the snapshot format changes; importers can migrate.
    var formatVersion: Int = 1
    var exportedAt: Date = Date()
    var player: PlayerProfileSnapshot?
    var playSessions: [PlaySessionSnapshot] = []
    var trainingSessions: [TrainingSessionSnapshot] = []
    var tournaments: [TournamentSnapshot] = []
    var matches: [MatchSnapshot] = []
    var players: [PlayerSnapshot] = []
}

/// A fully decoded, bounds-checked snapshot. Created off the main actor by
/// `Backup.prepare`, then handed to `Backup.apply` for the SwiftData writes.
nonisolated struct ValidatedBackup: Sendable {
    var player: PlayerProfileSnapshot?
    var playSessions: [PlaySessionSnapshot] = []
    var trainingSessions: [TrainingSessionSnapshot] = []
    var tournaments: [TournamentSnapshot] = []
    var matches: [MatchSnapshot] = []
    var players: [PlayerSnapshot] = []
}

// MARK: - Encryption
//
// Optional password protection for exported files:
// PBKDF2-SHA256 derives the key, AES-GCM authenticates and encrypts.
// A wrong password fails loudly (GCM tag mismatch) — never silently
// imports garbage. Attacker-controlled encryption parameters are validated
// before they reach CommonCrypto so a bad file can't trap or hang the app.

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
    static let minIterations = 1
    static let maxIterations = 1_000_000
    private static let minSaltBytes = 8
    private static let maxSaltBytes = 64
    /// AES-GCM combined boxes carry a 12-byte nonce and a 16-byte tag.
    private static let gcmOverhead = 28

    static func isEncrypted(_ data: Data) -> Bool {
        (try? JSONDecoder().decode(EncryptedFile.self, from: data)) != nil
    }

    static func encrypt(_ plaintext: Data, password: String) throws -> Data {
        guard !password.isEmpty else {
            throw Backup.Failure(message: "Password can't be empty.")
        }
        guard plaintext.count <= BackupFormat.maxBackupBytes else {
            throw Backup.Failure(message: "This backup is too large to encrypt.")
        }

        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw Backup.Failure(message: "Couldn't generate encryption salt.")
        }

        let key = try Self.key(password: password, salt: salt, iterations: iterations)
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
        guard data.count <= BackupFormat.maxBackupBytes else {
            throw Backup.Failure(message: "This backup file is too large to import (over 50 MB).")
        }
        let file = try JSONDecoder().decode(EncryptedFile.self, from: data)
        let payload = file.smashEncryptedBackup

        guard payload.iterations >= minIterations, payload.iterations <= maxIterations else {
            throw Backup.Failure(message: "This backup's encryption settings are unsupported.")
        }
        guard let salt = Data(base64Encoded: payload.salt),
              (minSaltBytes...maxSaltBytes).contains(salt.count) else {
            throw Backup.Failure(message: "Backup file is damaged (invalid salt).")
        }
        guard let combined = Data(base64Encoded: payload.ciphertext),
              combined.count >= Self.gcmOverhead,
              combined.count <= BackupFormat.maxBackupBytes + Self.gcmOverhead else {
            throw Backup.Failure(message: "Backup file is damaged (invalid ciphertext).")
        }
        guard !password.isEmpty else {
            throw Backup.Failure(message: "Password can't be empty.")
        }

        let key = try Self.key(password: password, salt: salt, iterations: payload.iterations)
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            let plaintext = try AES.GCM.open(box, using: key)
            guard plaintext.count <= BackupFormat.maxBackupBytes else {
                throw Backup.Failure(message: "This backup file is too large to import (over 50 MB).")
            }
            return plaintext
        } catch let failure as Backup.Failure {
            throw failure
        } catch {
            throw Backup.Failure(message: "Wrong password — the backup couldn't be decrypted.")
        }
    }

    private static func key(password: String, salt: Data, iterations: Int) throws -> SymmetricKey {
        SymmetricKey(data: try pbkdf2(password: password, salt: salt, iterations: iterations))
    }

    /// PBKDF2-SHA256 via CommonCrypto. Every parameter is validated before it
    /// is converted or passed to C — no traps, no unbounded work.
    private static func pbkdf2(password: String, salt: Data, iterations: Int, keyLength: Int = 32) throws -> Data {
        guard (minIterations...maxIterations).contains(iterations) else {
            throw Backup.Failure(message: "This backup's encryption settings are unsupported.")
        }
        guard (minSaltBytes...maxSaltBytes).contains(salt.count) else {
            throw Backup.Failure(message: "Backup file is damaged (invalid salt).")
        }
        let passwordData = Data(password.utf8)
        guard !passwordData.isEmpty else {
            throw Backup.Failure(message: "Password can't be empty.")
        }
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
        guard status == kCCSuccess else {
            throw Backup.Failure(message: "Couldn't derive an encryption key from this password.")
        }
        return derived
    }

    private static func prettyJSONEncoder() -> JSONEncoder {
        BackupFormat.prettyJSONEncoder()
    }
}

/// Shared limits and encoder used by `BackupCrypto` and `Backup`.
nonisolated enum BackupFormat {
    /// Plaintext and encrypted backup files are rejected above this size.
    static let maxBackupBytes = 50 * 1024 * 1024
    static let maxRecordsPerKind = 50_000
    static let maxTotalRecords = 100_000
    static let maxDurationMinutes = 365 * 24 * 60
    static let maxGamesPerMatch = 100
    static let maxPointsPerGame = 1_000
    static let maxDrillsPerSession = 50
    static let maxTextLength = 20_000

    static func prettyJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

// MARK: - Export / import

nonisolated struct ImportSummary: Equatable, Sendable {
    var playSessions = 0
    var trainingSessions = 0
    var tournaments = 0
    var matches = 0
    var players = 0

    var description: String {
        var parts: [String] = []
        if playSessions > 0 { parts.append("\(playSessions) play") }
        if trainingSessions > 0 { parts.append("\(trainingSessions) training") }
        if matches > 0 { parts.append("\(matches) match" + (matches == 1 ? "" : "es")) }
        if tournaments > 0 { parts.append("\(tournaments) tournament" + (tournaments == 1 ? "" : "s")) }
        if players > 0 { parts.append("\(players) player" + (players == 1 ? "" : "s")) }
        return parts.isEmpty ? "No records found in the file." : "Added " + parts.joined(separator: ", ") + "."
    }
}

nonisolated enum Backup {
    /// Human-readable failure messages surfaced directly in the Settings alert.
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    // MARK: Export

    /// Builds the snapshot from the store. Runs on the main actor because it
    /// reads SwiftData models and the locally cached profile values.
    static func makeBundle(context: ModelContext) throws -> BackupBundle {
        var bundle = BackupBundle()

        bundle.player = PlayerProfileSnapshot(
            name: PlayerProfile.name,
            skillLevel: PlayerProfile.skillLevel,
            avatar: PlayerProfile.avatar,
            avatarColor: PlayerProfile.avatarColor,
            goalKind: PlayerGoal.kind,
            goalTarget: PlayerGoal.kind == .none ? nil : PlayerGoal.target
        )
        bundle.playSessions = try context.fetch(FetchDescriptor<PlaySession>()).map(PlaySessionSnapshot.init)
        bundle.trainingSessions = try context.fetch(FetchDescriptor<TrainingSession>()).map(TrainingSessionSnapshot.init)
        bundle.tournaments = try context.fetch(FetchDescriptor<Tournament>()).map(TournamentSnapshot.init)
        bundle.matches = try context.fetch(FetchDescriptor<Match>()).map(MatchSnapshot.init)
        bundle.players = try context.fetch(FetchDescriptor<Player>()).map(PlayerSnapshot.init)

        return bundle
    }

    /// Pure JSON encoding — safe to call from a detached task.
    static func encode(_ bundle: BackupBundle) throws -> Data {
        try BackupFormat.prettyJSONEncoder().encode(bundle)
    }

    /// Convenience for tests and manual exports; migration uses the granular API.
    static func exportData(context: ModelContext) throws -> Data {
        try encode(makeBundle(context: context))
    }

    // MARK: Validation

    /// Decodes and sanitizes a backup without touching SwiftData or
    /// UserDefaults. Safe to call from a detached task: nothing here mutates
    /// app state, and every value is bounded before models are created.
    static func prepare(_ data: Data) throws -> ValidatedBackup {
        guard data.count <= BackupFormat.maxBackupBytes else {
            throw Failure(message: "This backup file is too large to import (over 50 MB).")
        }

        let bundle: BackupBundle
        do {
            bundle = try JSONDecoder().decode(BackupBundle.self, from: data)
        } catch {
            throw Failure(message: "This isn't a Smash backup file.")
        }

        guard bundle.formatVersion == 1 else {
            throw Failure(message: "This backup uses format version \(bundle.formatVersion); this version of Smash supports version 1 only.")
        }

        let counts = [
            bundle.playSessions.count, bundle.trainingSessions.count,
            bundle.tournaments.count, bundle.matches.count, bundle.players.count,
        ]
        guard counts.allSatisfy({ $0 <= BackupFormat.maxRecordsPerKind }),
              counts.reduce(0, +) <= BackupFormat.maxTotalRecords else {
            throw Failure(message: "This backup contains too many records to import.")
        }

        var result = ValidatedBackup()
        result.player = sanitize(bundle.player)
        result.playSessions = bundle.playSessions.map(sanitize)
        result.trainingSessions = bundle.trainingSessions.map(sanitize)
        result.tournaments = bundle.tournaments.map(sanitize)
        result.matches = bundle.matches.map(sanitize)
        result.players = bundle.players.map(sanitize)
        return result
    }

    private static func text(_ value: String?, limit: Int = BackupFormat.maxTextLength) -> String? {
        value.map { String($0.prefix(limit)) }
    }

    private static func duration(_ minutes: Int) -> Int {
        min(max(minutes, 0), BackupFormat.maxDurationMinutes)
    }

    private static func sanitize(_ snapshot: PlayerProfileSnapshot?) -> PlayerProfileSnapshot? {
        guard var player = snapshot else { return nil }
        player.name = String(player.name.prefix(200))
        player.skillLevel = player.skillLevel.flatMap { SkillLevel(rawValue: $0)?.rawValue }
        player.avatar = player.avatar.flatMap { PlayerProfile.avatarChoices.contains($0) ? $0 : nil }
        player.avatarColor = player.avatarColor.flatMap { PlayerProfile.avatarColors.contains($0) ? $0 : nil }
        player.goalKind = player.goalKind.flatMap { GoalKind(rawValue: $0)?.rawValue }
        player.goalTarget = player.goalTarget.map {
            min(max($0, 1), GoalKind.monthly.targetRange.upperBound)
        }
        return player
    }

    private static func sanitize(_ snapshot: PlaySessionSnapshot) -> PlaySessionSnapshot {
        var session = snapshot
        session.durationMinutes = duration(session.durationMinutes)
        session.discipline = (Discipline(rawValue: session.discipline) ?? .singles).rawValue
        session.intensity = session.intensity.flatMap { Intensity(rawValue: $0)?.rawValue }
        session.location = text(session.location, limit: 500)
        session.notes = text(session.notes)
        session.opponents = Array(session.opponents.prefix(100).map { String($0.prefix(200)) })
        return session
    }

    private static func sanitize(_ snapshot: TrainingSessionSnapshot) -> TrainingSessionSnapshot {
        var session = snapshot
        session.durationMinutes = duration(session.durationMinutes)
        session.focusAreas = Array(session.focusAreas.prefix(50).map { String($0.prefix(100)) })
        session.drillsDescription = text(session.drillsDescription) ?? ""
        session.notes = text(session.notes)
        session.setsDone = session.setsDone.map { min(max($0, 1), 50) }
        session.intensity = session.intensity.flatMap { Intensity(rawValue: $0)?.rawValue }

        let legacyName = session.drillName.flatMap { text($0, limit: 200) }.flatMap { $0.isEmpty ? nil : $0 }
        let names = session.drillNames.isEmpty
            ? (legacyName.map { [$0] } ?? [])
            : session.drillNames
        let drills = Array(names.prefix(BackupFormat.maxDrillsPerSession)
            .map { String($0.prefix(200)) }
            .filter { !$0.isEmpty })

        // Parallel arrays always match the drill count: pad or trim instead of
        // letting a malformed file leave the detail view reading past an index.
        var sets = Array(session.drillSets.prefix(drills.count))
        sets.append(contentsOf: repeatElement(1, count: drills.count - sets.count))
        var intensities = Array(session.drillIntensities.prefix(drills.count))
        intensities.append(contentsOf: repeatElement("", count: drills.count - intensities.count))

        session.drillNames = drills
        session.drillSets = sets.map { min(max($0, 1), 50) }
        session.drillIntensities = intensities.map { Intensity(rawValue: $0)?.rawValue ?? "" }
        session.drillName = nil
        return session
    }

    private static func sanitize(_ snapshot: TournamentSnapshot) -> TournamentSnapshot {
        var tournament = snapshot
        tournament.name = text(tournament.name, limit: 200) ?? ""
        tournament.type = (TournamentType(rawValue: tournament.type) ?? .roundRobin).rawValue
        tournament.placement = tournament.placement.flatMap { Placement(rawValue: $0)?.rawValue }
        tournament.strategyNotes = text(tournament.strategyNotes)
        if let end = tournament.endDate, end < tournament.startDate { tournament.endDate = nil }
        return tournament
    }

    private static func sanitize(_ snapshot: MatchSnapshot) -> MatchSnapshot {
        var match = snapshot
        match.opponent = text(match.opponent, limit: 200) ?? ""
        match.partner = text(match.partner, limit: 200)
        match.discipline = (Discipline(rawValue: match.discipline) ?? .singles).rawValue
        match.pointSystem = (PointSystem(rawValue: match.pointSystem) ?? .points21).rawValue
        match.format = (MatchFormat(rawValue: match.format) ?? .bestOf3).rawValue
        match.opponentLevel = match.opponentLevel.flatMap { SkillLevel(rawValue: $0)?.rawValue }
        match.intensity = match.intensity.flatMap { Intensity(rawValue: $0)?.rawValue }
        match.notes = text(match.notes)

        let count = min(max(match.myGameScores.count, match.opponentGameScores.count), BackupFormat.maxGamesPerMatch)
        var mine = Array(match.myGameScores.prefix(count))
        var theirs = Array(match.opponentGameScores.prefix(count))
        mine.append(contentsOf: repeatElement(0, count: count - mine.count))
        theirs.append(contentsOf: repeatElement(0, count: count - theirs.count))
        match.myGameScores = mine.map { min(max($0, 0), BackupFormat.maxPointsPerGame) }
        match.opponentGameScores = theirs.map { min(max($0, 0), BackupFormat.maxPointsPerGame) }
        return match
    }

    private static func sanitize(_ snapshot: PlayerSnapshot) -> PlayerSnapshot {
        var player = snapshot
        player.name = text(player.name, limit: 200) ?? ""
        player.level = player.level.flatMap { SkillLevel(rawValue: $0)?.rawValue }
        player.notes = text(player.notes)
        return player
    }

    // MARK: Import

    /// Convenience for callers that already hold raw file bytes. Import is
    /// validated before any model is inserted, and the profile is written
    /// only after the SwiftData save succeeds.
    static func importData(_ data: Data, into context: ModelContext) throws -> ImportSummary {
        try apply(prepare(data), into: context)
    }

    /// Inserts every record in the validated snapshot, saves once, then
    /// restores the profile. Existing records are never touched or replaced;
    /// tournament ↔ match links are re-established defensively.
    static func apply(_ backup: ValidatedBackup, into context: ModelContext) throws -> ImportSummary {
        var summary = ImportSummary()
        var tournamentsById: [UUID: Tournament] = [:]

        do {
            // Duplicate IDs are legal in an edited backup file but would trap
            // Dictionary(uniqueKeysWithValues:). Keep the first, skip the rest.
            for snapshot in backup.tournaments {
                guard tournamentsById[snapshot.id] == nil else { continue }
                tournamentsById[snapshot.id] = snapshot.insert(into: context)
                summary.tournaments += 1
            }
            for snapshot in backup.playSessions {
                snapshot.insert(into: context)
                summary.playSessions += 1
            }
            for snapshot in backup.trainingSessions {
                snapshot.insert(into: context)
                summary.trainingSessions += 1
            }
            for snapshot in backup.matches {
                snapshot.insert(into: context, tournament: snapshot.tournamentID.flatMap { tournamentsById[$0] })
                summary.matches += 1
            }
            for snapshot in backup.players {
                snapshot.insert(into: context)
                summary.players += 1
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }

        // Only now, once the records are safely committed, do we overwrite the
        // profile. A failed save leaves both the store and the profile alone.
        if let player = backup.player { applyProfile(player) }
        return summary
    }

    private static func applyProfile(_ player: PlayerProfileSnapshot) {
        PlayerProfile.name = player.name
        PlayerProfile.skillLevel = player.skill
        if let avatar = player.avatar { PlayerProfile.avatar = avatar }
        if let color = player.avatarColor { PlayerProfile.avatarColor = color }
        if let goal = player.goal {
            PlayerGoal.kind = goal
            if goal != .none, let target = player.goalTarget { PlayerGoal.target = target }
        }
    }
}
