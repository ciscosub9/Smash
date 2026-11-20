import Foundation

// MARK: - Pure aggregation logic, kept free of SwiftData so it can be tested directly.

/// One day's combined activity across play and training.
struct DayActivity: Identifiable, Equatable {
    let day: Date
    let playMinutes: Int
    let trainingMinutes: Int
    /// Number of sessions logged that day, used by the dashboard chart.
    let playCount: Int
    let trainingCount: Int

    init(
        day: Date,
        playMinutes: Int,
        trainingMinutes: Int,
        playCount: Int = 0,
        trainingCount: Int = 0
    ) {
        self.day = day
        self.playMinutes = playMinutes
        self.trainingMinutes = trainingMinutes
        self.playCount = playCount
        self.trainingCount = trainingCount
    }

    var id: Date { day }
    var totalMinutes: Int { playMinutes + trainingMinutes }
    var totalSessions: Int { playCount + trainingCount }
}

/// Win/loss record for one opponent (or one segment).
struct Record: Identifiable, Equatable {
    let label: String
    let wins: Int
    let losses: Int
    let draws: Int

    var id: String { label }
    var total: Int { wins + losses + draws }
    /// Draws count as non-wins.
    var winRate: Double { total == 0 ? 0 : Double(wins) / Double(total) }
}

enum Stats {
    // MARK: Activity

    /// Imported sessions can carry a negative duration. Never let one erase
    /// legitimate minutes from a total.
    private static func nonNegativeMinutes(_ minutes: Int) -> Int {
        max(0, minutes)
    }

    /// Buckets sessions per day for the last `days` days ending `today` (inclusive).
    static func dailyActivity(
        play: [PlaySession],
        training: [TrainingSession],
        endingOn today: Date = .now,
        days: Int = 7,
        calendar: Calendar = .current
    ) -> [DayActivity] {
        let startOfToday = calendar.startOfDay(for: today)
        var buckets: [Date: (play: Int, training: Int, playCount: Int, trainingCount: Int)] = [:]
        for offset in 0..<days {
            if let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday) {
                buckets[day] = (0, 0, 0, 0)
            }
        }

        for session in play {
            let day = calendar.startOfDay(for: session.date)
            if buckets[day] != nil {
                buckets[day]!.play += nonNegativeMinutes(session.durationMinutes)
                buckets[day]!.playCount += 1
            }
        }
        for session in training {
            let day = calendar.startOfDay(for: session.date)
            if buckets[day] != nil {
                buckets[day]!.training += nonNegativeMinutes(session.durationMinutes)
                buckets[day]!.trainingCount += 1
            }
        }

        return (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday),
                  let bucket = buckets[day] else { return nil }
            return DayActivity(
                day: day,
                playMinutes: bucket.play,
                trainingMinutes: bucket.training,
                playCount: bucket.playCount,
                trainingCount: bucket.trainingCount
            )
        }
        .sorted { $0.day < $1.day }
    }

    /// Buckets sessions into every day of `interval` (e.g. one calendar week
    /// or month). Days with no activity are included as zeroes so the chart
    /// keeps a stable shape.
    static func dailyActivity(
        play: [PlaySession],
        training: [TrainingSession],
        in interval: DateInterval,
        calendar: Calendar = .current
    ) -> [DayActivity] {
        var buckets: [Date: (play: Int, training: Int, playCount: Int, trainingCount: Int)] = [:]
        var day = calendar.startOfDay(for: interval.start)
        while day < interval.end {
            buckets[day] = (0, 0, 0, 0)
            // A calendar that fails to advance must not spin here forever.
            guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
            day = next
        }
        for session in play {
            let key = calendar.startOfDay(for: session.date)
            if buckets[key] != nil {
                buckets[key]!.play += nonNegativeMinutes(session.durationMinutes)
                buckets[key]!.playCount += 1
            }
        }
        for session in training {
            let key = calendar.startOfDay(for: session.date)
            if buckets[key] != nil {
                buckets[key]!.training += nonNegativeMinutes(session.durationMinutes)
                buckets[key]!.trainingCount += 1
            }
        }
        return buckets.keys.sorted().map { day in
            let bucket = buckets[day]!
            return DayActivity(
                day: day,
                playMinutes: bucket.play,
                trainingMinutes: bucket.training,
                playCount: bucket.playCount,
                trainingCount: bucket.trainingCount
            )
        }
    }

    /// A Monday-to-Sunday week containing `date`, unlike `Calendar`'s default
    /// Sunday start.
    static func weekInterval(
        at date: Date = .now,
        calendar: Calendar = .current
    ) -> DateInterval? {
        var mondayFirst = calendar
        mondayFirst.firstWeekday = 2
        return mondayFirst.dateInterval(of: .weekOfYear, for: date)
    }

    /// Total minutes across the given sessions.
    static func totalMinutes(_ sessions: [PlaySession]) -> Int {
        sessions.reduce(0) { $0 + nonNegativeMinutes($1.durationMinutes) }
    }

    /// Half-open containment: `start <= date < end`. Foundation's
    /// `DateInterval.contains` includes the end, which would count an item
    /// logged at exactly the next period's start in both periods.
    private static func contains(_ date: Date, in interval: DateInterval) -> Bool {
        date >= interval.start && date < interval.end
    }

    /// On-court minutes (play + training) inside a calendar interval.
    static func totalMinutes(
        play: [PlaySession],
        training: [TrainingSession],
        in interval: DateInterval
    ) -> Int {
        play.filter { contains($0.date, in: interval) }
            .reduce(0) { $0 + nonNegativeMinutes($1.durationMinutes) }
            + training.filter { contains($0.date, in: interval) }
            .reduce(0) { $0 + nonNegativeMinutes($1.durationMinutes) }
    }

    /// Matches played inside a calendar interval.
    static func matches(_ matches: [Match], in interval: DateInterval) -> [Match] {
        matches.filter { contains($0.date, in: interval) }
    }

    /// Consecutive-day streak of any activity, counting backwards from today
    /// (or yesterday if today has nothing yet — a streak shouldn't break at noon).
    static func activityStreak(
        play: [PlaySession],
        training: [TrainingSession],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> Int {
        let activeDays = Set(
            (play.map { calendar.startOfDay(for: $0.date) }
                + training.map { calendar.startOfDay(for: $0.date) })
        )
        guard !activeDays.isEmpty else { return 0 }

        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        if !activeDays.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  yesterday < cursor else { return 0 }
            cursor = yesterday
        }
        while activeDays.contains(cursor) {
            streak += 1
            // Guard against a calendar that returns the same date repeatedly.
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor),
                  previous < cursor else { break }
            cursor = previous
        }
        return streak
    }

    // MARK: Goals

    /// Sessions (play + training) whose date falls inside `interval`.
    /// Matches don't count — they're games played *within* sessions.
    static func sessions(
        play: [PlaySession],
        training: [TrainingSession],
        in interval: DateInterval
    ) -> Int {
        play.filter { contains($0.date, in: interval) }.count
            + training.filter { contains($0.date, in: interval) }.count
    }

    /// The calendar interval for the user's goal cadence at `date`.
    static func interval(
        for kind: GoalKind,
        at date: Date = .now,
        calendar: Calendar = .current
    ) -> DateInterval? {
        switch kind {
        case .none: return nil
        case .weekly: return weekInterval(at: date, calendar: calendar)
        case .monthly: return calendar.dateInterval(of: .month, for: date)
        }
    }

    /// Consecutive weeks (or months) in which the activity goal was met.
    ///
    /// An unfinished current period doesn't break the streak: if this week
    /// isn't complete yet, counting starts from last week.
    static func goalStreak(
        play: [PlaySession],
        training: [TrainingSession],
        kind: GoalKind,
        target: Int,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> Int {
        guard kind != .none, target > 0 else { return 0 }

        // Weekly goals are always Monday-to-Sunday in this app. Use one
        // canonical calendar for the current *and* every earlier period,
        // otherwise a caller's Sunday-first calendar moves Sunday sessions
        // into a different week only for the older periods.
        var periodCalendar = calendar
        if kind == .weekly { periodCalendar.firstWeekday = 2 }

        let component: Calendar.Component = kind == .weekly ? .weekOfYear : .month
        func met(_ interval: DateInterval) -> Bool {
            sessions(play: play, training: training, in: interval) >= target
        }
        func previous(_ interval: DateInterval) -> DateInterval? {
            guard let start = periodCalendar.date(byAdding: component, value: -1, to: interval.start),
                  let earlier = periodCalendar.dateInterval(of: component, for: start),
                  earlier.start < interval.start else { return nil }
            return earlier
        }

        guard var interval = Self.interval(for: kind, at: now, calendar: periodCalendar) else { return 0 }
        // Only an unfinished current period is skipped. If the period has
        // ended and the target was missed, it breaks the streak instead.
        if !met(interval), now < interval.end {
            guard let earlier = previous(interval) else { return 0 }
            interval = earlier
        }

        var streak = 0
        while met(interval), streak < 1200 {
            streak += 1
            guard let earlier = previous(interval) else { break }
            interval = earlier
        }
        return streak
    }

    // MARK: Matches

    /// Win/loss record grouped by opponent, worst-first for improvement, best-first by default.
    static func recordsByOpponent(_ matches: [Match], ascending: Bool = false) -> [Record] {
        let grouped = Dictionary(grouping: matches, by: \.opponent)
        return grouped
            .map { opponent, matches in
                Record(
                    label: opponent.isEmpty ? "Unknown" : opponent,
                    wins: matches.filter { MatchLogic.outcome($0) == .win }.count,
                    losses: matches.filter { MatchLogic.outcome($0) == .loss }.count,
                    draws: matches.filter { MatchLogic.outcome($0) == .draw }.count
                )
            }
            .sorted { lhs, rhs in
                // Dictionary iteration order is arbitrary; break ties by name.
                if lhs.winRate == rhs.winRate { return lhs.label < rhs.label }
                return ascending ? lhs.winRate < rhs.winRate : lhs.winRate > rhs.winRate
            }
    }

    /// Record restricted to one point system (15 / 21 / continuous).
    static func record(for pointSystem: PointSystem, in matches: [Match]) -> Record {
        let filtered = matches.filter { $0.pointSystem == pointSystem }
        return Record(
            label: pointSystem.label,
            wins: filtered.filter { MatchLogic.outcome($0) == .win }.count,
            losses: filtered.filter { MatchLogic.outcome($0) == .loss }.count,
            draws: filtered.filter { MatchLogic.outcome($0) == .draw }.count
        )
    }

    /// Current consecutive win/loss streak, newest match first.
    /// Returns `(.win, 3)` for three straight wins.
    static func currentStreak(_ matches: [Match]) -> (kind: MatchOutcome, count: Int)? {
        let sorted = matches.sorted(by: newerFirst)
        guard let first = sorted.first, let kind = normalizedOutcome(first) else { return nil }
        var count = 0
        for match in sorted {
            guard normalizedOutcome(match) == kind else { break }
            count += 1
        }
        return (kind, count)
    }

    /// Newest first, with deterministic tie-breaks so matches logged at the
    /// same instant can't change a streak when input order changes.
    private static func newerFirst(_ lhs: Match, _ rhs: Match) -> Bool {
        if lhs.date != rhs.date { return lhs.date > rhs.date }
        if lhs.opponent != rhs.opponent { return lhs.opponent < rhs.opponent }
        if lhs.pointSystemRaw != rhs.pointSystemRaw { return lhs.pointSystemRaw < rhs.pointSystemRaw }
        if lhs.myGameScores != rhs.myGameScores {
            return lhs.myGameScores.lexicographicallyPrecedes(rhs.myGameScores)
        }
        return lhs.opponentGameScores.lexicographicallyPrecedes(rhs.opponentGameScores)
    }

    private static func normalizedOutcome(_ match: Match) -> MatchOutcome? {
        matchOutcomeIgnoringDraws(match)
    }

    private static func matchOutcomeIgnoringDraws(_ match: Match) -> MatchOutcome? {
        let outcome = MatchLogic.outcome(match)
        return outcome == .draw ? nil : outcome
    }
}
