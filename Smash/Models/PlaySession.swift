import Foundation
import SwiftData

/// A casual play session — the daily badminton habit.
/// Tracks how long you played, with whom, and how it felt.
@Model
final class PlaySession {
    var date: Date = Date()
    /// Duration of the session in minutes.
    var durationMinutes: Int = 60
    var disciplineRaw: String = Discipline.singles.rawValue
    var intensityRaw: String? = nil
    var location: String? = nil
    /// Names of opponents / partners played with.
    var opponents: [String] = []
    var notes: String? = nil

    init(
        date: Date = Date(),
        durationMinutes: Int = 60,
        discipline: Discipline = .singles,
        intensity: Intensity? = nil,
        location: String? = nil,
        opponents: [String] = [],
        notes: String? = nil
    ) {
        self.date = date
        self.durationMinutes = durationMinutes
        self.disciplineRaw = discipline.rawValue
        self.intensityRaw = intensity?.rawValue
        self.location = location
        self.opponents = opponents
        self.notes = notes
    }

    var discipline: Discipline {
        get { Discipline(rawValue: disciplineRaw) ?? .singles }
        set { disciplineRaw = newValue.rawValue }
    }

    var intensity: Intensity? {
        get { intensityRaw.flatMap(Intensity.init(rawValue:)) }
        set { intensityRaw = newValue?.rawValue }
    }

    var duration: TimeInterval { TimeInterval(durationMinutes) * 60 }
}
