import Foundation

// MARK: - Shared option sets
//
// Enums are persisted as raw `String` values (not as Codable payloads) so that
// they stay CloudKit-compatible and usable in SwiftData predicates. Each model
// exposes a typed computed accessor over the raw property.

enum Discipline: String, CaseIterable, Identifiable {
    case singles
    case doubles
    case mixedDoubles

    var id: String { rawValue }

    var label: String {
        switch self {
        case .singles: "Singles"
        case .doubles: "Doubles"
        case .mixedDoubles: "Mixed doubles"
        }
    }

    var symbol: String {
        switch self {
        case .singles: "figure.2"
        case .doubles: "person.2"
        case .mixedDoubles: "person.2.wave.2"
        }
    }
}

enum Intensity: String, CaseIterable, Identifiable {
    case easy
    case moderate
    case hard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .easy: "Easy"
        case .moderate: "Moderate"
        case .hard: "Hard"
        }
    }
}

// MARK: - Match scoring

enum PointSystem: String, CaseIterable, Identifiable {
    /// Traditional 15-point system (side-in scoring era).
    case points15
    /// Modern rally-point system, games to 21.
    case points21
    /// Free play with no fixed point cap — a single continuous game.
    case continuous

    var id: String { rawValue }

    var label: String {
        switch self {
        case .points15: "15 points"
        case .points21: "21 points"
        case .continuous: "Continuous"
        }
    }

    var summary: String {
        switch self {
        case .points15: "Games to 15"
        case .points21: "Games to 21, rally point"
        case .continuous: "One long game, no cap"
        }
    }
}

enum MatchFormat: String, CaseIterable, Identifiable {
    case singleGame
    case bestOf3

    var id: String { rawValue }

    var label: String {
        switch self {
        case .singleGame: "Single game"
        case .bestOf3: "Best of 3"
        }
    }

    var gameCount: Int {
        switch self {
        case .singleGame: 1
        case .bestOf3: 3
        }
    }
}

// MARK: - Tournament

enum TournamentType: String, CaseIterable, Identifiable {
    case roundRobin
    case knockout
    case league
    case ladder
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .roundRobin: "Round robin"
        case .knockout: "Knockout"
        case .league: "League"
        case .ladder: "Ladder"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .roundRobin: "arrow.triangle.2.circlepath"
        case .knockout: "flag.2.crossed"
        case .league: "tablecells"
        case .ladder: "list.number"
        case .other: "trophy"
        }
    }
}

enum Placement: String, CaseIterable, Identifiable {
    case champion
    case runnerUp
    case third
    case semiFinal
    case quarterFinal
    case groupStage
    case participated

    var id: String { rawValue }

    var label: String {
        switch self {
        case .champion: "Champion"
        case .runnerUp: "Runner-up"
        case .third: "Third place"
        case .semiFinal: "Semi-final"
        case .quarterFinal: "Quarter-final"
        case .groupStage: "Group stage"
        case .participated: "Participated"
        }
    }

    var rank: Int? {
        switch self {
        case .champion: 1
        case .runnerUp: 2
        case .third: 3
        case .semiFinal: 4
        case .quarterFinal: 5
        case .groupStage: 6
        case .participated: 7
        }
    }
}

// MARK: - Training

/// Common focus areas offered as quick chips on the training form.
enum TrainingFocus: String, CaseIterable, Identifiable {
    case footwork
    case clears
    case smashes
    case drops
    case netPlay
    case serves
    case defense
    case strategy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .footwork: "Footwork"
        case .clears: "Clears"
        case .smashes: "Smashes"
        case .drops: "Drops"
        case .netPlay: "Net play"
        case .serves: "Serves"
        case .defense: "Defense"
        case .strategy: "Strategy"
        }
    }
}
