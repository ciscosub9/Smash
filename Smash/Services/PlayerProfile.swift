import Foundation

/// The player's own profile — name and skill tier.
///
/// Stored in `UserDefaults` (not SwiftData): one small record that the
/// backup bundles alongside the rest of the data.
nonisolated enum PlayerProfile {
    static let nameKey = "SmashPlayerName"
    static let skillKey = "SmashPlayerSkill"

    static var name: String {
        get { UserDefaults.standard.string(forKey: nameKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: nameKey) }
    }

    static var skillLevel: SkillLevel? {
        get { UserDefaults.standard.string(forKey: skillKey).flatMap(SkillLevel.init(rawValue:)) }
        set { UserDefaults.standard.set(newValue?.rawValue, forKey: skillKey) }
    }
}

/// A snapshot of the profile for backups.
nonisolated struct PlayerProfileSnapshot: Codable, Equatable {
    var name: String = ""
    var skillLevel: String? = nil

    init(name: String, skillLevel: SkillLevel?) {
        self.name = name
        self.skillLevel = skillLevel?.rawValue
    }

    var skill: SkillLevel? {
        skillLevel.flatMap(SkillLevel.init(rawValue:))
    }
}
