import Foundation
import SwiftData

/// One drill inside a training session, with its own workload and difficulty.
nonisolated struct TrainingDrillEntry: Identifiable, Hashable {
    /// Picker tag for a drill the player types instead of choosing.
    static let customSentinel = "__custom__"

    let id = UUID()
    var name: String
    var customName: String = ""
    var sets: Int = 1
    var intensity: Intensity?
}

/// A training session — skill work rather than match play.
@Model
final class TrainingSession {
    var date: Date = Date()
    /// Duration of the session in minutes.
    var durationMinutes: Int = 60
    /// Quick chips describing what the session focused on.
    var focusAreas: [String] = []
    /// Free-form description of what was actually done (drills, routines…).
    var drillsDescription: String = ""
    /// Every drill worked on in the session, preset or custom.
    var drillNames: [String] = []
    /// Sets completed for each drill. Parallel to `drillNames`.
    var drillSets: [Int] = []
    /// Intensity raw value for each drill, `""` for not set. Parallel to `drillNames`.
    var drillIntensities: [String] = []

    // Kept for backups written before drills had their own sets and difficulty.
    var setsDone: Int? = nil
    var intensityRaw: String? = nil
    var notes: String? = nil

    init(
        date: Date = Date(),
        durationMinutes: Int = 60,
        focusAreas: [String] = [],
        drillsDescription: String = "",
        drillNames: [String] = [],
        drillSets: [Int] = [],
        drillIntensities: [String] = [],
        setsDone: Int? = nil,
        intensity: Intensity? = nil,
        notes: String? = nil
    ) {
        self.date = date
        self.durationMinutes = durationMinutes
        self.focusAreas = focusAreas
        self.drillsDescription = drillsDescription
        self.drillNames = drillNames
        self.drillSets = drillSets
        self.drillIntensities = drillIntensities
        self.setsDone = setsDone
        self.intensityRaw = intensity?.rawValue
        self.notes = notes
    }

    var intensity: Intensity? {
        get { intensityRaw.flatMap(Intensity.init(rawValue:)) }
        set { intensityRaw = newValue?.rawValue }
    }

    /// Per-drill entries, falling back to the old session-wide values for
    /// sessions saved before sets and difficulty became per drill.
    var drillEntries: [TrainingDrillEntry] {
        drillNames.enumerated().map { index, name in
            let sets = index < drillSets.count ? drillSets[index] : (setsDone ?? 1)
            let raw = index < drillIntensities.count ? drillIntensities[index] : (intensityRaw ?? "")
            let level = raw.isEmpty ? nil : Intensity(rawValue: raw)
            return TrainingDrillEntry(name: name, sets: max(1, sets), intensity: level)
        }
    }

    var duration: TimeInterval { TimeInterval(durationMinutes) * 60 }
}
