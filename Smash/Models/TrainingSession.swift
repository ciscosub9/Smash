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
    var notes: String? = nil

    init(
        date: Date = Date(),
        durationMinutes: Int = 60,
        coach: String? = nil,
        focusAreas: [String] = [],
        drillsDescription: String = "",
        notes: String? = nil
    ) {
        self.date = date
        self.durationMinutes = durationMinutes
        self.coach = coach
        self.focusAreas = focusAreas
        self.drillsDescription = drillsDescription
        self.notes = notes
    }

    var duration: TimeInterval { TimeInterval(durationMinutes) * 60 }
}
