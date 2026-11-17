import Foundation

/// The player's own profile — name, skill tier, and activity goal.
///
/// Stored in `UserDefaults` (not SwiftData): small records that the
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

// MARK: - Activity goal

/// Cadence of the activity goal — sessions per week or per month.
nonisolated enum GoalKind: String, CaseIterable, Identifiable {
    case none
    case weekly
    case monthly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "None"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        }
    }

    /// Unit noun for status lines.
    var unit: String {
        switch self {
        case .none: ""
        case .weekly: "week"
        case .monthly: "month"
        }
    }

    var targetRange: ClosedRange<Int> {
        switch self {
        case .none: 1...1
        case .weekly: 1...14
        case .monthly: 1...60
        }
    }
}

/// The user's activity goal — "play 5 times a week" style targets.
/// Counts play + training sessions; matches are games *within* sessions.
nonisolated enum PlayerGoal {
    static let kindKey = "SmashGoalKind"
    static let targetKey = "SmashGoalTarget"

    static var kind: GoalKind {
        get { UserDefaults.standard.string(forKey: kindKey).flatMap(GoalKind.init(rawValue:)) ?? .none }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: kindKey) }
    }

    /// Sessions per week/month. Default 3 — a friendly starting point.
    static var target: Int {
        get { UserDefaults.standard.object(forKey: targetKey) as? Int ?? 3 }
        set {
            let clamped = min(max(newValue, 1), PlayerGoal.kind.targetRange.upperBound)
            UserDefaults.standard.set(clamped, forKey: targetKey)
        }
    }
}

/// A snapshot of the profile (and goal) for backups.
nonisolated struct PlayerProfileSnapshot: Codable, Equatable {
    var name: String = ""
    var skillLevel: String? = nil
    var goalKind: String? = nil
    var goalTarget: Int? = nil

    init(
        name: String,
        skillLevel: SkillLevel?,
        goalKind: GoalKind? = nil,
        goalTarget: Int? = nil
    ) {
        self.name = name
        self.skillLevel = skillLevel?.rawValue
        self.goalKind = goalKind?.rawValue
        self.goalTarget = goalTarget
    }

    var skill: SkillLevel? {
        skillLevel.flatMap(SkillLevel.init(rawValue:))
    }

    var goal: GoalKind? {
        goalKind.flatMap(GoalKind.init(rawValue:))
    }
}
