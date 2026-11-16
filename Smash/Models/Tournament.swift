import Foundation
import SwiftData

/// A badminton tournament the user took part in, grouping related matches.
@Model
final class Tournament {
    var name: String = ""
    var typeRaw: String = TournamentType.roundRobin.rawValue
    var startDate: Date = Date()
    var endDate: Date? = nil
    var placementRaw: String? = nil
    /// Tactics, game plans, lessons learned.
    var strategyNotes: String? = nil

    @Relationship(deleteRule: .nullify)
    var matches: [Match] = []

    init(
        name: String = "",
        type: TournamentType = .roundRobin,
        startDate: Date = Date(),
        endDate: Date? = nil,
        placement: Placement? = nil,
        strategyNotes: String? = nil
    ) {
        self.name = name
        self.typeRaw = type.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.placementRaw = placement?.rawValue
        self.strategyNotes = strategyNotes
    }

    var type: TournamentType {
        get { TournamentType(rawValue: typeRaw) ?? .roundRobin }
        set { typeRaw = newValue.rawValue }
    }

    var placement: Placement? {
        get { placementRaw.flatMap(Placement.init(rawValue:)) }
        set { placementRaw = newValue?.rawValue }
    }
}

// MARK: - Derived stats

extension Tournament {
    var wins: Int { matches.filter { MatchLogic.outcome($0) == .win }.count }
    var losses: Int { matches.filter { MatchLogic.outcome($0) == .loss }.count }
    var draws: Int { matches.filter { MatchLogic.outcome($0) == .draw }.count }
    var winRate: Double { MatchLogic.winRate(of: matches) }

    /// "3 – 1" style record, ignoring draws.
    var recordDescription: String {
        "\(wins) – \(losses)"
    }
}
