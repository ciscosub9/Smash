import Foundation

// MARK: - Pure aggregation logic, kept free of SwiftData so it can be tested directly.

/// One day's combined activity across play and training.
struct DayActivity: Identifiable, Equatable {
    let day: Date
    let playMinutes: Int
    let trainingMinutes: Int

    var id: Date { day }
    var totalMinutes: Int { playMinutes + trainingMinutes }
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

    /// Buckets sessions per day for the last `days` days ending `today` (inclusive).
    static func dailyActivity(
        play: [PlaySession],
        training: [TrainingSession],
        endingOn today: Date = .now,
        days: Int = 7,
        calendar: Calendar = .current
    ) -> [DayActivity] {
        let startOfToday = calendar.startOfDay(for: today)
        var buckets: [Date: (play: Int, training: Int)] = [:]
        for offset in 0..<days {
            if let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday) {
                buckets[day] = (0, 0)
            }
        }

        for session in play {
            let day = calendar.startOfDay(for: session.date)
            if buckets[day] != nil {
                buckets[day]!.play += session.durationMinutes
            }
        }
        for session in training {
            let day = calendar.startOfDay(for: session.date)
            if buckets[day] != nil {
                buckets[day]!.training += session.durationMinutes
            }
        }

        return (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday),
                  let bucket = buckets[day] else { return nil }
            return DayActivity(day: day, playMinutes: bucket.play, trainingMinutes: bucket.training)
        }
        .sorted { $0.day < $1.day }
    }

    /// Total minutes across the given sessions.
    static func totalMinutes(_ sessions: [PlaySession]) -> Int {
        sessions.reduce(0) { $0 + $1.durationMinutes }
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
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        while activeDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    // MARK: Matches

    /// All distinct opponents across matches, alphabetically.
    static func allOpponents(from matches: [Match]) -> [String] {
        Array(Set(matches.map(\.opponent))).filter { !$0.isEmpty }.sorted()
    }

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
            .sorted { ascending ? $0.winRate < $1.winRate : $0.winRate > $1.winRate }
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
    /// Returns `("win", 3)` for three straight wins.
    static func currentStreak(_ matches: [Match]) -> (kind: MatchOutcome, count: Int)? {
        let sorted = matches.sorted { $0.date > $1.date }
        guard let first = sorted.first, let kind = normalizedOutcome(first) else { return nil }
        var count = 0
        for match in sorted {
            guard normalizedOutcome(match) == kind else { break }
            count += 1
        }
        return (kind, count)
    }

    private static func normalizedOutcome(_ match: Match) -> MatchOutcome? {
        matchOutcomeIgnoringDraws(match)
    }

    private static func matchOutcomeIgnoringDraws(_ match: Match) -> MatchOutcome? {
        let outcome = MatchLogic.outcome(match)
        return outcome == .draw ? nil : outcome
    }
}
