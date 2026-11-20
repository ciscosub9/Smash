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
    /// Partner for doubles / mixed doubles. Empty for singles.
    var partner: String = ""
    var disciplineRaw: String = Discipline.singles.rawValue
    var pointSystemRaw: String = PointSystem.points21.rawValue
    var formatRaw: String = MatchFormat.bestOf3.rawValue

    /// Points scored per game, parallel to `opponentGameScores`.
    /// One entry per game played: three for best of three, or as many as
    /// needed for a variable-length continuous match.
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
        partner: String = "",
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
        self.partner = partner
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

    /// Partners only exist in doubles and mixed doubles.
    var usesPartner: Bool { discipline != .singles }

    /// How many games were played. Best of three always has three slots;
    /// continuous games can run as long as the session did.
    var gameCount: Int {
        switch format {
        case .bestOf3: 3
        case .singleGame: max(1, max(myGameScores.count, opponentGameScores.count))
        }
    }

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

    /// Pads the shorter score array with zeroes so both arrays have the same
    /// number of slots. This keeps an index valid in either array and stops a
    /// game recorded on only one side from being dropped by `zip`.
    private static func alignedScores(
        myGameScores: [Int],
        opponentGameScores: [Int],
        count: Int
    ) -> (mine: [Int], theirs: [Int]) {
        let limit = max(0, count)
        let mine = Array(myGameScores.prefix(limit))
        let theirs = Array(opponentGameScores.prefix(limit))
        // At least one slot when a game count is expected, so a match with
        // completely empty arrays is still recognised as all-unplayed.
        let length = max(mine.count, theirs.count, limit > 0 ? 1 : 0)
        return (
            mine + Array(repeating: 0, count: length - mine.count),
            theirs + Array(repeating: 0, count: length - theirs.count)
        )
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
        // A game can be present in only one array after a partial save. Align
        // first, then every pair represents one real game slot.
        let aligned = alignedScores(
            myGameScores: myGameScores,
            opponentGameScores: opponentGameScores,
            count: max(myGameScores.count, opponentGameScores.count)
        )
        let mine = aligned.mine
        let theirs = aligned.theirs

        let gamesWon = zip(mine, theirs).reduce(into: (me: 0, opp: 0)) { acc, pair in
            switch gameOutcome(myPoints: pair.0, opponentPoints: pair.1) {
            case .win: acc.me += 1
            case .loss: acc.opp += 1
            case .draw: break
            }
        }

        var myGames = gamesWon.me
        var oppGames = gamesWon.opp

        if format == .bestOf3, myGames == oppGames {
            // Fall back to total points across played games. Sum the aligned
            // arrays so an offset entry is never dropped from the comparison.
            myGames = mine.reduce(0, +)
            oppGames = theirs.reduce(0, +)
        }

        if myGames > oppGames { return .win }
        if myGames < oppGames { return .loss }
        return .draw
    }

    // MARK: - Score validation

    /// Whether one game's score is a legal final score under the chosen rules.
    ///
    /// A rally-point game ends the moment a side reaches the target with a
    /// two-point lead, or the first side to the cap. So the score one point
    /// earlier must not already have been a winning score: 30–12 and 25–15
    /// are not possible finishes. At the cap the loser has to be one or two
    /// points behind (30–29 or 30–28; 21–20 or 21–19).
    /// `0 – 0` is an unplayed game, valid inside a best-of-three.
    static func isValidGame(
        myPoints: Int,
        opponentPoints: Int,
        pointSystem: PointSystem
    ) -> Bool {
        guard myPoints >= 0, opponentPoints >= 0 else { return false }
        if myPoints == 0, opponentPoints == 0 { return true }

        // Continuous play has no fixed target or cap.
        guard let target = pointSystem.targetPoints,
              let cap = pointSystem.capPoints else { return true }

        guard myPoints <= cap, opponentPoints <= cap else { return false }

        let winner = max(myPoints, opponentPoints)
        let loser = min(myPoints, opponentPoints)

        if winner == cap {
            return loser >= cap - 2 && loser < cap
        }

        guard winner >= target, winner - loser >= 2 else { return false }
        // The previous point must not already have ended the game.
        return winner - 1 < target || (winner - 1) - loser < 2
    }

    /// Indexes of games that still need a legal final score. Empty means valid.
    static func invalidGameIndexes(
        myGameScores: [Int],
        opponentGameScores: [Int],
        format: MatchFormat,
        pointSystem: PointSystem,
        gameCount: Int? = nil
    ) -> [Int] {
        let aligned = alignedScores(
            myGameScores: myGameScores,
            opponentGameScores: opponentGameScores,
            count: gameCount ?? format.gameCount
        )
        let mine = aligned.mine
        let theirs = aligned.theirs
        let played = mine.indices.filter { mine[$0] > 0 || theirs[$0] > 0 }
        guard !played.isEmpty else { return Array(mine.indices) }

        return played.filter { index in
            !isValidGame(
                myPoints: mine[index],
                opponentPoints: theirs[index],
                pointSystem: pointSystem
            )
        }
    }

    /// A plain-language reason the score can't be saved yet, if any.
    static func validationMessage(
        myGameScores: [Int],
        opponentGameScores: [Int],
        format: MatchFormat,
        pointSystem: PointSystem,
        gameCount: Int? = nil
    ) -> String? {
        let count = gameCount ?? format.gameCount
        let aligned = alignedScores(
            myGameScores: myGameScores,
            opponentGameScores: opponentGameScores,
            count: count
        )
        let mine = aligned.mine
        let theirs = aligned.theirs
        let invalid = invalidGameIndexes(
            myGameScores: mine,
            opponentGameScores: theirs,
            format: format,
            pointSystem: pointSystem,
            gameCount: count
        )
        guard let first = invalid.first else { return nil }

        let allUnplayed = mine.indices.allSatisfy { index in
            mine[index] == 0 && opponentPoints(opponentGameScores: theirs, index: index) == 0
        }
        if allUnplayed {
            return "Enter a final score for at least one game."
        }
        let my = mine[first]
        let their = opponentPoints(opponentGameScores: theirs, index: first)
        let winner = max(my, their)
        let loser = min(my, their)

        let reason: String
        if min(my, their) < 0 {
            reason = "Scores can't be negative."
        } else if let cap = pointSystem.capPoints, winner > cap {
            reason = "Scores can't be higher than the \(cap)-point cap."
        } else if let cap = pointSystem.capPoints, winner == cap {
            reason = "At the \(cap)-point cap the other score has to be \(cap - 2) or \(cap - 1)."
        } else if let target = pointSystem.targetPoints, winner < target {
            reason = "A finished game needs at least \(target) points."
        } else if winner - loser < 2 {
            reason = "The winner has to lead by at least 2 points."
        } else {
            reason = "The game would already have ended at \(winner - 1)–\(loser)."
        }
        return "Game \(first + 1): \(my)–\(their) isn't possible. \(reason)"
    }

    /// Keeps the validation message readable even for a malformed score array.
    private static func opponentPoints(opponentGameScores: [Int], index: Int) -> Int {
        index < opponentGameScores.count ? opponentGameScores[index] : 0
    }

    /// Convenience for a saved match.
    static func isValid(_ match: Match) -> Bool {
        validationMessage(
            myGameScores: match.myGameScores,
            opponentGameScores: match.opponentGameScores,
            format: match.format,
            pointSystem: match.pointSystem,
            gameCount: match.gameCount
        ) == nil
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
