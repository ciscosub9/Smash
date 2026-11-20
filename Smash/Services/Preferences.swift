import Foundation

/// Clock format used when *entering* and *displaying* session times.
/// The app defaults to a 12-hour clock with AM/PM; 24-hour hides AM/PM.
nonisolated enum TimePreference {
    static let storageKey = "SmashTimeFormat"

    enum Format: String, CaseIterable, Identifiable {
        case twelveHour
        case twentyFourHour

        var id: String { rawValue }

        var label: String {
            switch self {
            case .twelveHour: "12-hour"
            case .twentyFourHour: "24-hour"
            }
        }
    }

    static var format: Format {
        get {
            UserDefaults.standard.string(forKey: storageKey)
                .flatMap(Format.init(rawValue:)) ?? .twelveHour
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: storageKey) }
    }
}

/// Which calendar window the Dashboard summarises. Weekly is the default;
/// choosing monthly recalculates time, matches, win rate, streaks and the
/// chart over the current calendar month.
nonisolated enum DashboardPeriod {
    static let storageKey = "SmashDashboardPeriod"

    enum Period: String, CaseIterable, Identifiable {
        case weekly
        case monthly

        var id: String { rawValue }

        var label: String {
            switch self {
            case .weekly: "Weekly"
            case .monthly: "Monthly"
            }
        }

        var goalKind: GoalKind {
            switch self {
            case .weekly: .weekly
            case .monthly: .monthly
            }
        }
    }

    static var current: Period {
        get {
            UserDefaults.standard.string(forKey: storageKey)
                .flatMap(Period.init(rawValue:)) ?? .weekly
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: storageKey) }
    }
}
