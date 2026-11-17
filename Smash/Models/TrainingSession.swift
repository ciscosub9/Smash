import Foundation
import SwiftData

/// A training / coaching session — skill work rather than match play.
@Model
final class TrainingSession {
    var date: Date = Date()
    /// Duration of the session in minutes.
    var durationMinutes: Int = 60
    var coach: String? = nil
    /// Quick chips describing what the session focused on.
    var focusAreas: [String] = []
    /// Free-form description of what was actually done (drills, routines…).
    var drillsDescription: String = ""
    /// The primary drill worked on — a preset name or custom text.
    var drillName: String? = nil
    /// Number of sets completed of that drill.
    var setsDone: Int? = nil
    /// How hard the session felt (Easy / Moderate / Hard).
    var intensityRaw: String? = nil
    var notes: String? = nil

    init(
        date: Date = Date(),
        durationMinutes: Int = 60,
        coach: String? = nil,
        focusAreas: [String] = [],
        drillsDescription: String = "",
        drillName: String? = nil,
        setsDone: Int? = nil,
        intensity: Intensity? = nil,
        notes: String? = nil
    ) {
        self.date = date
        self.durationMinutes = durationMinutes
        self.coach = coach
        self.focusAreas = focusAreas
        self.drillsDescription = drillsDescription
        self.drillName = drillName
        self.setsDone = setsDone
        self.intensityRaw = intensity?.rawValue
        self.notes = notes
    }

    var intensity: Intensity? {
        get { intensityRaw.flatMap(Intensity.init(rawValue:)) }
        set { intensityRaw = newValue?.rawValue }
    }

    var duration: TimeInterval { TimeInterval(durationMinutes) * 60 }
}
