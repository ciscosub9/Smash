import Foundation

// MARK: - Shared option sets
//
// Enums are persisted as raw `String` values (not as Codable payloads) so that
// they stay CloudKit-compatible and usable in SwiftData predicates. Each model
// exposes a typed computed accessor over the raw property.

nonisolated enum Discipline: String, CaseIterable, Identifiable {
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
        case .singles: "figure.stand"
        case .doubles: "person.2"
        case .mixedDoubles: "person.2.wave.2"
        }
    }

    /// Partners only exist in doubles and mixed doubles.
    var usesPartner: Bool { self != .singles }
}

nonisolated enum Intensity: String, CaseIterable, Identifiable {
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

/// Skill tiers — used for opponents on matches and for the player's own profile.
nonisolated enum SkillLevel: String, CaseIterable, Identifiable {
    case beginner
    case amateur
    case intermediate
    case advanced
    case professional

    var id: String { rawValue }

    var label: String {
        switch self {
        case .beginner: "Beginner"
        case .amateur: "Amateur"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        case .professional: "Professional"
        }
    }
}

// MARK: - Match scoring

nonisolated enum PointSystem: String, CaseIterable, Identifiable {
    /// Traditional 15-point system (side-in scoring era).
    case points15
    /// Modern rally-point system, games to 21.
    case points21
    /// Free play with no fixed point cap — a single continuous game.
    case continuous

    var id: String { rawValue }

    /// Only the two fixed-length systems are offered when scoring a game.
    static let scoringOptions: [PointSystem] = [.points15, .points21]

    var label: String {
        switch self {
        case .points15: "15 points"
        case .points21: "21 points"
        case .continuous: "Continuous"
        }
    }

    var summary: String {
        switch self {
        case .points15: "Games to 15 · win by 2 · cap at 21"
        case .points21: "Games to 21 · win by 2 · cap at 30"
        case .continuous: "One long game, no cap"
        }
    }

    /// Points needed to win a game. `nil` for continuous play.
    var targetPoints: Int? {
        switch self {
        case .points15: 15
        case .points21: 21
        case .continuous: nil
        }
    }

    /// Hard ceiling on a game's score. `nil` for continuous play.
    var capPoints: Int? {
        switch self {
        case .points15: 21
        case .points21: 30
        case .continuous: nil
        }
    }
}

nonisolated enum MatchFormat: String, CaseIterable, Identifiable {
    case singleGame
    case bestOf3

    var id: String { rawValue }

    var label: String {
        switch self {
        case .singleGame: "Continuous games"
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

nonisolated enum TournamentType: String, CaseIterable, Identifiable {
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

nonisolated enum Placement: String, CaseIterable, Identifiable {
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

/// One drill in the training library. Names are the stored value; free text is
/// still allowed on the form, so the library is a shortcut, not a cage.
struct BadmintonDrill: Identifiable, Hashable {
    let name: String
    let category: String
    let detail: String

    var id: String { name }
}

/// A broad, searchable library of badminton drills across the main skill
/// areas. Used by the training form and its drill browser.
nonisolated enum BadmintonDrillLibrary {
    static let categories = [
        "Footwork", "Clears", "Smashes", "Drops", "Net play", "Serves",
        "Defense", "Drives", "Multishuttle", "Conditioning", "Doubles", "Match play",
    ]

    static let drills: [BadmintonDrill] = [
        // Footwork
        BadmintonDrill(name: "Shadow footwork", category: "Footwork",
                       detail: "Move through the six corners without a shuttle; recover to base after every stroke."),
        BadmintonDrill(name: "Footwork ladder", category: "Footwork",
                       detail: "Agility-ladder patterns for quick first steps and split-step timing."),
        BadmintonDrill(name: "Six-point footwork", category: "Footwork",
                       detail: "Coach calls six corners at random; sprint, recover, and play a shadow stroke."),
        BadmintonDrill(name: "Split-step drill", category: "Footwork",
                       detail: "Split-step on the coach's feed, then push off to the called corner."),
        BadmintonDrill(name: "Court coverage", category: "Footwork",
                       detail: "Cover lures to the front and rear court, returning to base after each."),
        BadmintonDrill(name: "Side-to-side shuffles", category: "Footwork",
                       detail: "Lateral shuffles between sidelines with a low stance and fast recovery."),
        // Clears
        BadmintonDrill(name: "Clear drills", category: "Clears",
                       detail: "Repeat high, deep clears to the back court, alternating straight and cross-court."),
        BadmintonDrill(name: "High clear consistency", category: "Clears",
                       detail: "Feed shuttle after shuttle to the rear court; aim for height and a repeatable swing."),
        BadmintonDrill(name: "Backhand clear", category: "Clears",
                       detail: "Rear-court backhand clears focused on wrist snap and a high contact point."),
        BadmintonDrill(name: "Clear to corners", category: "Clears",
                       detail: "Call the target corner before each clear and score the landing zone."),
        BadmintonDrill(name: "Underarm clear", category: "Clears",
                       detail: "Defensive underarm clears from a deep, pressured position."),
        // Smashes
        BadmintonDrill(name: "Smash practice", category: "Smashes",
                       detail: "Half-court smashes with a feed, concentrating on steep angle and recovery."),
        BadmintonDrill(name: "Half-court smash", category: "Smashes",
                       detail: "Work only the front half of the opponent's court; placement over power."),
        BadmintonDrill(name: "Jump smash reps", category: "Smashes",
                       detail: "Timed jump smashes with controlled landings and immediate base recovery."),
        BadmintonDrill(name: "Smash to zones", category: "Smashes",
                       detail: "Aim smashes at called zones: body, wide forehand, wide backhand."),
        BadmintonDrill(name: "Smash and net kill", category: "Smashes",
                       detail: "Smash, recover, then rush the net for the kill on a blocked return."),
        // Drops
        BadmintonDrill(name: "Drop shots", category: "Drops",
                       detail: "Slow drops from the rear court to the front third, alternating slice and fast drops."),
        BadmintonDrill(name: "Slice drop", category: "Drops",
                       detail: "Use a slicing action to disguise the drop until contact."),
        BadmintonDrill(name: "Fast drop", category: "Drops",
                       detail: "A steeper, quicker drop aimed just over the net."),
        BadmintonDrill(name: "Drop to target", category: "Drops",
                       detail: "Place drops into a target hoop in the front court."),
        // Net play
        BadmintonDrill(name: "Net shots", category: "Net play",
                       detail: "Tight net shots with tumbling spin and a low trajectory over the tape."),
        BadmintonDrill(name: "Hairpin net shot", category: "Net play",
                       detail: "Play a hairpin that peaks just above the tape and dies on the far side."),
        BadmintonDrill(name: "Net kill", category: "Net play",
                       detail: "Punish a lifted shuttle with a downward kill from above tape height."),
        BadmintonDrill(name: "Net lift", category: "Net play",
                       detail: "Lift a tight net shot deep to the rear court under pressure."),
        BadmintonDrill(name: "Net rally", category: "Net play",
                       detail: "Sustained net-only rally to build touch, control, and patience."),
        // Serves
        BadmintonDrill(name: "Serve accuracy", category: "Serves",
                       detail: "Low serves to called spots in the opponent's front service court."),
        BadmintonDrill(name: "Low serve", category: "Serves",
                       detail: "Keep the shuttle below the tape and land it just past the short service line."),
        BadmintonDrill(name: "High serve", category: "Serves",
                       detail: "Deep high serves to the back court with consistent height and landing."),
        BadmintonDrill(name: "Flick serve", category: "Serves",
                       detail: "A quick flick over an opponent reaching for the low serve."),
        BadmintonDrill(name: "Serve and third shot", category: "Serves",
                       detail: "Serve, read the return, then play a pre-planned third shot."),
        // Defense
        BadmintonDrill(name: "Defense drills", category: "Defense",
                       detail: "Block and lift returns against smashes, then counter-attack."),
        BadmintonDrill(name: "Block defense", category: "Defense",
                       detail: "Block smashes softly to the front court and recover to base."),
        BadmintonDrill(name: "Lift defense", category: "Defense",
                       detail: "Lift smashes high and deep to reset the rally."),
        BadmintonDrill(name: "Drive defense", category: "Defense",
                       detail: "Counter fast drives with flat, low returns down the line."),
        BadmintonDrill(name: "Counter-attack", category: "Defense",
                       detail: "Turn a defensive block into an attacking clear or drop."),
        // Drives
        BadmintonDrill(name: "Drive rally", category: "Drives",
                       detail: "Flat, fast drives down the sidelines with a compact swing."),
        BadmintonDrill(name: "Cross-court drive", category: "Drives",
                       detail: "Drive diagonally across the court; change direction only when called."),
        BadmintonDrill(name: "Drive to body", category: "Drives",
                       detail: "Aim drives at the opponent's body to jam their swing."),
        // Multishuttle
        BadmintonDrill(name: "Multi-shuttle", category: "Multishuttle",
                       detail: "Coach feeds a continuous sequence of shuttles; play the called shot each time."),
        BadmintonDrill(name: "Multiball clear-smash", category: "Multishuttle",
                       detail: "Alternate a high clear with a smash on consecutive feeds."),
        BadmintonDrill(name: "Multiball footwork", category: "Multishuttle",
                       detail: "Feed to moving targets while you cover the court and return to base."),
        // Conditioning
        BadmintonDrill(name: "Conditioning", category: "Conditioning",
                       detail: "Court sprints, shadow rallies, and a short core circuit between blocks."),
        BadmintonDrill(name: "Court sprints", category: "Conditioning",
                       detail: "Repeat six-corner sprints with short, timed rest between sets."),
        BadmintonDrill(name: "Shadow rally", category: "Conditioning",
                       detail: "Play a full rally with no shuttle to rehearse movement and timing."),
        BadmintonDrill(name: "Jump rope", category: "Conditioning",
                       detail: "Skip-rope intervals for foot speed and stamina."),
        // Doubles
        BadmintonDrill(name: "Front-back rotation", category: "Doubles",
                       detail: "Attacking formation: one at the net, one at the rear, rotating after each shot."),
        BadmintonDrill(name: "Side-by-side defense", category: "Doubles",
                       detail: "Hold a parallel defensive shape and cover smashes down the middle and wide."),
        BadmintonDrill(name: "Serve return patterns", category: "Doubles",
                       detail: "Drill low and flick serve returns with a planned third shot."),
        BadmintonDrill(name: "Third-shot follow-up", category: "Doubles",
                       detail: "After the serve return, both players move into the planned attacking shape."),
        // Match play
        BadmintonDrill(name: "Match simulation", category: "Match play",
                       detail: "Play short games with scoring, tactics, and a clear game plan."),
        BadmintonDrill(name: "Pressure games", category: "Match play",
                       detail: "Start at 18–18 or 10–10 to practise closing out tight finishes."),
        BadmintonDrill(name: "Best-of-one review", category: "Match play",
                       detail: "Play one game, then note three things to repeat and one to fix."),
    ]

    /// Names only, for the training form's quick-pick menu.
    static var presets: [String] { drills.map(\.name) }

    static func drills(in category: String) -> [BadmintonDrill] {
        drills.filter { $0.category == category }
    }

    static func drill(named name: String) -> BadmintonDrill? {
        drills.first { $0.name == name }
    }
}

// MARK: - Training

/// Common focus areas offered as quick chips on the training form.
nonisolated enum TrainingFocus: String, CaseIterable, Identifiable {
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
