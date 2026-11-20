import Foundation
import SwiftData

/// Someone the player faces or partners with. Saved separately from match
/// history so names and levels can be reused when logging a session.
@Model
final class Player {
    var name: String = ""
    var levelRaw: String?
    var notes: String?
    var addedAt: Date = Date()

    init(name: String = "", level: SkillLevel? = nil, notes: String? = nil, addedAt: Date = Date()) {
        self.name = name
        self.levelRaw = level?.rawValue
        self.notes = notes
        self.addedAt = addedAt
    }

    @Transient var level: SkillLevel? {
        get { levelRaw.flatMap(SkillLevel.init(rawValue:)) }
        set { levelRaw = newValue?.rawValue }
    }
}
