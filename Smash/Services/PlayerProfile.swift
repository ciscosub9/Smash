import Foundation

/// The player's own profile — name, skill tier, and activity goal.
///
/// `UserDefaults` remains the local cache that `@AppStorage` binds to. When
/// the user is signed in to iCloud, the same small values are mirrored to
/// `NSUbiquitousKeyValueStore` so they follow the player to other devices.
/// A write timestamp decides which copy wins; without an iCloud account the
/// whole sync layer is a no-op and the app works locally as before.
///
/// Onboarding/tour flags stay device-only: replaying a tour on one iPhone
/// shouldn't mark it seen on another.
nonisolated enum PlayerProfile {
    static let nameKey = "SmashPlayerName"
    static let skillKey = "SmashPlayerSkill"
    static let avatarKey = "SmashPlayerAvatar"
    static let avatarColorKey = "SmashPlayerAvatarColor"
    static let onboardingKey = "SmashOnboardingDone"
    static let appTourKey = "SmashAppTourDone"

    /// Original icon artwork shipped with the app — no photo library permission.
    /// The icon name and colour are stored separately so either can change.
    static let avatarChoices = [
        "shuttle", "racquet", "bolt", "trophy", "flame", "target",
        "crown", "net", "medal", "pad", "rocket", "star",
    ]
    static let defaultAvatar = "shuttle"

    /// Colours used to tint the avatar icon. The badge stays black; only the
    /// icon changes. White is the default, paired with the swatches in the picker.
    static let avatarColors = [
        "#FFFFFF", "#34C759", "#007AFF", "#5E5CE6", "#AF52DE", "#FF2D55",
        "#FF3B30", "#FF9500", "#FFCC00", "#30B0C7", "#8E8E93", "#A2845E",
    ]
    static let defaultAvatarColor = "#FFFFFF"

    static var name: String {
        get { ProfileCloudSync.string(forKey: nameKey) ?? "" }
        set { ProfileCloudSync.set(newValue, forKey: nameKey) }
    }

    static var skillLevel: SkillLevel? {
        get { ProfileCloudSync.string(forKey: skillKey).flatMap { $0.isEmpty ? nil : SkillLevel(rawValue: $0) } }
        set { ProfileCloudSync.set(newValue?.rawValue, forKey: skillKey) }
    }

    static var avatar: String {
        get {
            let saved = ProfileCloudSync.string(forKey: avatarKey) ?? defaultAvatar
            return avatarChoices.contains(saved) ? saved : defaultAvatar
        }
        set { ProfileCloudSync.set(newValue, forKey: avatarKey) }
    }

    static var avatarColor: String {
        get {
            let saved = ProfileCloudSync.string(forKey: avatarColorKey) ?? defaultAvatarColor
            return avatarColors.contains(saved) ? saved : defaultAvatarColor
        }
        set { ProfileCloudSync.set(newValue, forKey: avatarColorKey) }
    }

    static var onboardingCompleted: Bool {
        get {
            // Read at launch by RootView, so this also kicks off the profile
            // mirror without needing a change in the app entry point.
            ProfileCloudSync.activate()
            return UserDefaults.standard.bool(forKey: onboardingKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: onboardingKey) }
    }

    /// The guided tour runs once after onboarding, and can be replayed from
    /// Settings whenever the player wants a reminder.
    static var appTourCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: appTourKey) }
        set { UserDefaults.standard.set(newValue, forKey: appTourKey) }
    }
}

// MARK: - iCloud key-value mirror
//
// Small, self-contained helper. It never replaces UserDefaults: writes land
// locally first, then (when iCloud is available) in the ubiquitous store.
// Reads compare a per-key timestamp and prefer the newer copy. The observer
// copies remote changes back into UserDefaults so @AppStorage views update.

private nonisolated enum ProfileCloudSync {
    /// Foundation's shared store is thread-safe but not marked Sendable.
    nonisolated(unsafe) private static let store = NSUbiquitousKeyValueStore.default

    private static let keys = [
        PlayerProfile.nameKey,
        PlayerProfile.skillKey,
        PlayerProfile.avatarKey,
        PlayerProfile.avatarColorKey,
        PlayerGoal.kindKey,
        PlayerGoal.targetKey,
    ]

    private static func stampKey(_ key: String) -> String { key + ".syncedAt" }

    private static var iCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private static let install: Void = {
        guard iCloudAvailable else { return }
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { notification in
            guard let changed = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }
            for key in changed where keys.contains(key) {
                if let value = store.object(forKey: key) {
                    UserDefaults.standard.set(value, forKey: key)
                    UserDefaults.standard.set(store.double(forKey: stampKey(key)), forKey: stampKey(key))
                }
            }
        }
        // ProfileView edits the same keys through @AppStorage (plain
        // UserDefaults). Mirror those edits too, otherwise only backup imports
        // and the typed setters would ever reach iCloud.
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { _ in
            mirrorLocalEdits()
        }
        _ = store.synchronize()
        pullNewerValues()
    }()

    static func activate() { _ = install }

    /// Copies direct @AppStorage edits into iCloud, unless the cloud copy is
    /// newer. Timestamp writes are idempotent, so the notification this posts
    /// back into UserDefaults doesn't loop.
    private static func mirrorLocalEdits() {
        guard iCloudAvailable else { return }
        for key in keys {
            guard let local = UserDefaults.standard.object(forKey: key),
                  !sameValue(local, store.object(forKey: key)) else { continue }
            let localStamp = UserDefaults.standard.double(forKey: stampKey(key))
            let cloudStamp = store.double(forKey: stampKey(key))
            guard localStamp >= cloudStamp else { continue }

            let now = Date().timeIntervalSince1970
            store.set(local, forKey: key)
            store.set(now, forKey: stampKey(key))
            UserDefaults.standard.set(now, forKey: stampKey(key))
        }
        _ = store.synchronize()
    }

    private static func sameValue(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case let (a as String, b as String): return a == b
        case let (a as Int, b as Int): return a == b
        default: return false
        }
    }

    /// On first activation, adopt values that are already in iCloud and newer
    /// than the local cache (e.g. after a reinstall or on a new device).
    private static func pullNewerValues() {
        guard iCloudAvailable else { return }
        for key in keys {
            let cloudStamp = store.double(forKey: stampKey(key))
            guard cloudStamp > 0,
                  cloudStamp >= UserDefaults.standard.double(forKey: stampKey(key)),
                  let value = store.object(forKey: key) else { continue }
            UserDefaults.standard.set(value, forKey: key)
            UserDefaults.standard.set(cloudStamp, forKey: stampKey(key))
        }
    }

    static func string(forKey key: String) -> String? {
        activate()
        let localStamp = UserDefaults.standard.double(forKey: stampKey(key))
        let cloudStamp = store.double(forKey: stampKey(key))
        if let cloud = store.string(forKey: key), cloudStamp > localStamp { return cloud }
        return UserDefaults.standard.string(forKey: key) ?? store.string(forKey: key)
    }

    static func integer(forKey key: String) -> Int? {
        activate()
        let localStamp = UserDefaults.standard.double(forKey: stampKey(key))
        let cloudStamp = store.double(forKey: stampKey(key))
        if let cloud = store.object(forKey: key) as? Int, cloudStamp > localStamp { return cloud }
        return UserDefaults.standard.object(forKey: key) as? Int ?? (store.object(forKey: key) as? Int)
    }

    /// Empty strings stand in for "not set" so removals propagate too.
    static func set(_ value: String?, forKey key: String) {
        write(value ?? "", forKey: key)
    }

    static func set(_ value: Int?, forKey key: String) {
        write(value ?? 0, forKey: key)
    }

    private static func write(_ value: Any, forKey key: String) {
        activate()
        let now = Date().timeIntervalSince1970
        UserDefaults.standard.set(value, forKey: key)
        UserDefaults.standard.set(now, forKey: stampKey(key))

        guard iCloudAvailable else { return }
        store.set(value, forKey: key)
        store.set(now, forKey: stampKey(key))
        _ = store.synchronize()
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

    /// Weekly by default — the goal streak card is meaningful on a fresh
    /// install without the player having to configure anything first.
    static var kind: GoalKind {
        get { ProfileCloudSync.string(forKey: kindKey).flatMap(GoalKind.init(rawValue:)) ?? .weekly }
        set { ProfileCloudSync.set(newValue.rawValue, forKey: kindKey) }
    }

    /// Sessions per week/month. Default 3 — a friendly starting point.
    static var target: Int {
        get { ProfileCloudSync.integer(forKey: targetKey) ?? 3 }
        set {
            let clamped = min(max(newValue, 1), PlayerGoal.kind.targetRange.upperBound)
            ProfileCloudSync.set(clamped, forKey: targetKey)
        }
    }
}

/// A snapshot of the profile (and goal) for backups.
nonisolated struct PlayerProfileSnapshot: Codable, Equatable, Sendable {
    var name: String = ""
    var skillLevel: String? = nil
    var avatar: String? = nil
    var avatarColor: String? = nil
    var goalKind: String? = nil
    var goalTarget: Int? = nil

    init(
        name: String,
        skillLevel: SkillLevel?,
        avatar: String? = nil,
        avatarColor: String? = nil,
        goalKind: GoalKind? = nil,
        goalTarget: Int? = nil
    ) {
        self.name = name
        self.skillLevel = skillLevel?.rawValue
        self.avatar = avatar
        self.avatarColor = avatarColor
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
