import Foundation
import SwiftData

/// The outcome of a single match, derived from the recorded game scores.
nonisolated enum MatchOutcome: Equatable {
    case win
    case loss
    case draw
}

/// A competitive match against an opponent — standalone or part of a tournament.
@Model
final class Match {
    var date: Date = Date()
    var opponent: String = ""
    var disciplineRaw: String = Discipline.singles.rawValue
    var pointSystemRaw: String = PointSystem.points21.rawValue
    var formatRaw: String = MatchFormat.bestOf3.rawValue

    /// Points scored per game, parallel to `opponentGameScores`.
    /// One entry per game played (1 for single game, up to 3 for best of 3).
    var myGameScores: [Int] = []
    var opponentGameScores: [Int] = []
    var notes: String? = nil

    /// Opponent's skill tier (Beginner…Professional).
    var opponentLevelRaw: String? = nil
    /// How hard the match felt.
    var intensityRaw: String? = nil

    @Relationship(inverse: \Tournament.matches)
    var tournament: Tournament? = nil

    init(
        date: Date = Date(),
        opponent: String = "",
        discipline: Discipline = .singles,
        pointSystem: PointSystem = .points21,
        format: MatchFormat = .bestOf3,
        myGameScores: [Int] = [],
        opponentGameScores: [Int] = [],
        notes: String? = nil,
        opponentLevel: SkillLevel? = nil,
        intensity: Intensity? = nil,
        tournament: Tournament? = nil
    ) {
        self.date = date
        self.opponent = opponent
        self.disciplineRaw = discipline.rawValue
        self.pointSystemRaw = pointSystem.rawValue
        self.formatRaw = format.rawValue
        self.myGameScores = myGameScores
        self.opponentGameScores = opponentGameScores
        self.notes = notes
        self.opponentLevelRaw = opponentLevel?.rawValue
        self.intensityRaw = intensity?.rawValue
        self.tournament = tournament
    }

    // MARK: Typed accessors

    var discipline: Discipline {
        get { Discipline(rawValue: disciplineRaw) ?? .singles }
        set { disciplineRaw = newValue.rawValue }
    }

    var pointSystem: PointSystem {
        get { PointSystem(rawValue: pointSystemRaw) ?? .points21 }
        set { pointSystemRaw = newValue.rawValue }
    }

    var format: MatchFormat {
        get { MatchFormat(rawValue: formatRaw) ?? .bestOf3 }
        set { formatRaw = newValue.rawValue }
    }

    var opponentLevel: SkillLevel? {
        get { opponentLevelRaw.flatMap(SkillLevel.init(rawValue:)) }
        set { opponentLevelRaw = newValue?.rawValue }
    }

    var intensity: Intensity? {
        get { intensityRaw.flatMap(Intensity.init(rawValue:)) }
        set { intensityRaw = newValue?.rawValue }
    }

    /// Score of one game as "(me) – (them)".
    func gameDescription(_ index: Int) -> String {
        guard index < myGameScores.count, index < opponentGameScores.count else { return "" }
        return "\(myGameScores[index]) – \(opponentGameScores[index])"
    }
}

// MARK: - Outcome logic (pure, unit-testable)

nonisolated enum MatchLogic {
    /// Outcome for a single game: higher points wins.
    static func gameOutcome(myPoints: Int, opponentPoints: Int) -> MatchOutcome {
        if myPoints > opponentPoints { return .win }
        if myPoints < opponentPoints { return .loss }
        return .draw
    }

    /// Overall match outcome.
    ///
    /// - Single game / continuous: decided by the one game's points.
    /// - Best of 3: decided by games won. If games won are equal
    ///   (e.g. the third game was not played), the played games so far
    ///   decide via points won across games.
    static func matchOutcome(
        myGameScores: [Int],
        opponentGameScores: [Int],
        format: MatchFormat
    ) -> MatchOutcome {
        let pairs = zip(myGameScores, opponentGameScores)
        guard let gamesWon = pairs.reduce(into: (me: 0, opp: 0), { acc, pair in
            switch gameOutcome(myPoints: pair.0, opponentPoints: pair.1) {
            case .win: acc.me += 1
            case .loss: acc.opp += 1
            case .draw: break
            }
        }) as (me: Int, opp: Int)? else { return .draw }

        var myGames = gamesWon.me
        var oppGames = gamesWon.opp

        if format == .bestOf3, myGames == oppGames {
            // Fall back to total points across played games.
            let myPoints = myGameScores.reduce(0, +)
            let oppPoints = opponentGameScores.reduce(0, +)
            myGames = myPoints
            oppGames = oppPoints
        }

        if myGames > oppGames { return .win }
        if myGames < oppGames { return .loss }
        return .draw
    }

    /// Win rate across a set of matches, as a fraction in 0...1.
    /// Draws count as non-wins in the denominator.
    static func winRate(of matches: [Match]) -> Double {
        guard !matches.isEmpty else { return 0 }
        let wins = matches.filter { outcome($0) == .win }.count
        return Double(wins) / Double(matches.count)
    }

    /// Outcome of a single match instance.
    static func outcome(_ match: Match) -> MatchOutcome {
        matchOutcome(
            myGameScores: match.myGameScores,
            opponentGameScores: match.opponentGameScores,
            format: match.format
        )
    }
}
