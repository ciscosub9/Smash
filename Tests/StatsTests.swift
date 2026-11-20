import Foundation
import Testing
@testable import Smash

@Suite("Stats aggregation")
struct StatsTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ offset: Int, from now: Date = .distantFuture) -> Date {
        let reference = day0(now)
        return calendar.date(byAdding: .day, value: offset, to: reference)!
    }

    private func day0(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    // MARK: Daily activity

    @Test("Daily activity buckets play and training separately")
    func dailyActivityBuckets() {
        let now = day(0)
        let play = [
            PlaySession(date: day(0), durationMinutes: 60),
            PlaySession(date: day(-1), durationMinutes: 30),
        ]
        let training = [
            TrainingSession(date: day(0), durationMinutes: 45),
        ]

        let activity = Stats.dailyActivity(
            play: play, training: training, endingOn: now, days: 7, calendar: calendar
        )

        #expect(activity.count == 7)
        #expect(activity.last?.playMinutes == 60)
        #expect(activity.last?.trainingMinutes == 45)
        #expect(activity[activity.count - 2].playMinutes == 30)
        #expect(activity[activity.count - 2].trainingMinutes == 0)
    }

    @Test("Daily activity ignores sessions older than the window")
    func dailyActivityWindow() {
        let now = day(0)
        let play = [PlaySession(date: day(-30), durationMinutes: 120)]

        let activity = Stats.dailyActivity(
            play: play, training: [], endingOn: now, days: 7, calendar: calendar
        )

        #expect(activity.allSatisfy { $0.totalMinutes == 0 })
    }

    // MARK: Streak

    @Test("Activity streak counts consecutive days including today or yesterday")
    func activityStreak() {
        let now = day(0)
        let play = [
            PlaySession(date: day(0)),
            PlaySession(date: day(-1)),
            PlaySession(date: day(-2)),
        ]
        // Gap: day(-3) missing
        let older = [PlaySession(date: day(-5))]

        #expect(Stats.activityStreak(play: play, training: [], calendar: calendar, now: now) == 3)
        #expect(Stats.activityStreak(play: play + older, training: [], calendar: calendar, now: now) == 3)
        #expect(Stats.activityStreak(play: [], training: [], calendar: calendar, now: now) == 0)
    }

    // MARK: Opponent records

    @Test("Records group by opponent and sort best-first")
    func recordsByOpponent() {
        let matches = [
            Match(opponent: "Ravi", myGameScores: [21], opponentGameScores: [10]),
            Match(opponent: "Ravi", myGameScores: [15], opponentGameScores: [21]),
            Match(opponent: "Anil", myGameScores: [21], opponentGameScores: [5]),
        ]

        let records = Stats.recordsByOpponent(matches)

        #expect(records.first?.label == "Anil")
        #expect(records.first?.winRate == 1.0)
        #expect(records.first { $0.label == "Ravi" }?.winRate == 0.5)
    }

    @Test("Record ties break by opponent label in either direction")
    func recordOrderingIsDeterministic() {
        let matches = [
            Match(opponent: "Zoe", myGameScores: [21], opponentGameScores: [10]),
            Match(opponent: "Anil", myGameScores: [21], opponentGameScores: [10]),
            Match(opponent: "Mina", myGameScores: [21], opponentGameScores: [10]),
        ]

        #expect(Stats.recordsByOpponent(matches).map(\.label) == ["Anil", "Mina", "Zoe"])
        #expect(Stats.recordsByOpponent(matches, ascending: true).map(\.label) == ["Anil", "Mina", "Zoe"])
    }

    // MARK: Point system record

    @Test("Record filters by point system")
    func recordByPointSystem() {
        let matches = [
            Match(opponent: "Ravi", pointSystem: .points21, myGameScores: [21], opponentGameScores: [10]),
            Match(opponent: "Anil", pointSystem: .points15, myGameScores: [8], opponentGameScores: [15]),
        ]

        let record21 = Stats.record(for: .points21, in: matches)
        let record15 = Stats.record(for: .points15, in: matches)
        let recordCont = Stats.record(for: .continuous, in: matches)

        #expect(record21.wins == 1)
        #expect(record15.losses == 1)
        #expect(recordCont.total == 0)
    }

    // MARK: Win/loss streak

    @Test("Current streak counts consecutive same outcomes, newest first")
    func currentWinLossStreak() {
        let matches = [
            Match(date: day(-2), opponent: "A", myGameScores: [21], opponentGameScores: [10]), // win
            Match(date: day(-1), opponent: "B", myGameScores: [21], opponentGameScores: [10]), // win
            Match(date: day(0), opponent: "C", myGameScores: [9], opponentGameScores: [21]),   // loss
        ]

        let streak = Stats.currentStreak(matches)
        #expect(streak?.kind == .loss)
        #expect(streak?.count == 1)
    }

    @Test("Current streak: three straight wins")
    func currentWinStreak() {
        let matches = [
            Match(date: day(-2), opponent: "A", myGameScores: [21], opponentGameScores: [10]),
            Match(date: day(-1), opponent: "B", myGameScores: [21], opponentGameScores: [10]),
            Match(date: day(0), opponent: "C", myGameScores: [30], opponentGameScores: [29]),
        ]

        let streak = Stats.currentStreak(matches)
        #expect(streak?.kind == .win)
        #expect(streak?.count == 3)
    }

    @Test("Current streak: matches on the same date have a stable order")
    func currentStreakBreaksDateTies() {
        let sameDate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 12))!
        let earlier = calendar.date(byAdding: .day, value: -1, to: sameDate)!
        let matches = [
            Match(date: sameDate, opponent: "B", myGameScores: [10], opponentGameScores: [21]), // loss
            Match(date: earlier, opponent: "A", myGameScores: [21], opponentGameScores: [10]),   // win
            Match(date: sameDate, opponent: "A", myGameScores: [21], opponentGameScores: [10]),  // win
        ]

        // "A" sorts before "B" at the newest timestamp, so the win is first.
        let permutations: [[Match]] = [
            matches,
            Array(matches.reversed()),
            [matches[2], matches[0], matches[1]],
        ]
        for order in permutations {
            let streak = Stats.currentStreak(Array(order))
            #expect(streak?.kind == .win)
            #expect(streak?.count == 1)
        }
    }

    @Test("Negative durations are clamped at every aggregation point")
    func negativeDurationsClamped() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 12))!
        let interval = calendar.dateInterval(of: .day, for: date)!
        let play = [
            PlaySession(date: date, durationMinutes: -120),
            PlaySession(date: date, durationMinutes: 60),
        ]
        let training = [
            TrainingSession(date: date, durationMinutes: -30),
            TrainingSession(date: date, durationMinutes: 45),
        ]

        #expect(Stats.totalMinutes(play) == 60)
        #expect(Stats.totalMinutes(play: play, training: training, in: interval) == 105)
        #expect(Stats.dailyActivity(
            play: play, training: training, endingOn: date, days: 1, calendar: calendar
        ).first?.playMinutes == 60)
        #expect(Stats.dailyActivity(
            play: play, training: training, endingOn: date, days: 1, calendar: calendar
        ).first?.trainingMinutes == 45)
        #expect(Stats.dailyActivity(
            play: play, training: training, in: interval, calendar: calendar
        ).first?.totalMinutes == 105)
        #expect(Stats.sessions(play: play, training: training, in: interval) == 4)
    }
}

@Suite("Goal progress")
struct GoalProgressTests {

    private func day(_ offset: Int, from reference: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: offset, to: reference)!
    }

    @Test("Sessions counts play and training inside the interval only")
    func countsInsideInterval() {
        let calendar = Calendar.current
        let now = Date()
        let week = calendar.dateInterval(of: .weekOfYear, for: now)!

        let playInWeek = PlaySession(date: calendar.date(byAdding: .hour, value: 1, to: week.start)!)
        let trainingInWeek = TrainingSession(date: now, durationMinutes: 45)
        let playBeforeWeek = PlaySession(date: calendar.date(byAdding: .day, value: -3, to: week.start)!)
        let playAfterWeek = PlaySession(date: calendar.date(byAdding: .day, value: 2, to: week.end)!)

        let count = Stats.sessions(
            play: [playInWeek, playBeforeWeek, playAfterWeek],
            training: [trainingInWeek],
            in: week
        )

        #expect(count == 2)
    }

    @Test("Monthly goal counts across the whole calendar month")
    func monthlyInterval() {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.dateInterval(of: .month, for: now)!

        let play = [
            PlaySession(date: month.start),
            PlaySession(date: calendar.date(byAdding: .day, value: 10, to: month.start)!),
            PlaySession(date: calendar.date(byAdding: .month, value: -1, to: month.start)!),
        ]

        #expect(Stats.sessions(play: play, training: [], in: month) == 2)
    }

    @Test("Goal streak counts consecutive periods, ignoring an unfinished current period")
    func goalStreakCountsConsecutivePeriods() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2 // Monday

        // Wednesday, so the current week is still in progress.
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 12))!
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)!
        let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek.start)!
        let twoWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -2, to: thisWeek.start)!
        let threeWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -3, to: thisWeek.start)!

        func sessions(in weekStart: Date, count: Int) -> [PlaySession] {
            (0..<count).map { offset in
                PlaySession(date: calendar.date(byAdding: .day, value: offset, to: weekStart)!, durationMinutes: 60)
            }
        }

        // Target 2/week. Current week only has 1 so far (unfinished) — streak
        // should start at last week and count back: last week met, two weeks met,
        // three weeks ago missed => streak 2.
        let play = sessions(in: thisWeek.start, count: 1)
            + sessions(in: lastWeek, count: 3)
            + sessions(in: twoWeeksAgo, count: 2)
            + sessions(in: threeWeeksAgo, count: 0)

        #expect(Stats.goalStreak(
            play: play,
            training: [],
            kind: .weekly,
            target: 2,
            calendar: calendar,
            now: now
        ) == 2)
    }

    @Test("Goal streak includes the current period once the target is met")
    func goalStreakIncludesCurrentPeriod() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2

        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 12))!
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)!
        let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek.start)!

        let play = [
            PlaySession(date: thisWeek.start),
            PlaySession(date: calendar.date(byAdding: .day, value: 1, to: thisWeek.start)!),
            PlaySession(date: lastWeek),
            PlaySession(date: calendar.date(byAdding: .day, value: 2, to: lastWeek)!),
        ]

        #expect(Stats.goalStreak(
            play: play,
            training: [],
            kind: .weekly,
            target: 2,
            calendar: calendar,
            now: now
        ) == 2)
    }

    @Test("Weekly interval starts on Monday even for a Sunday-first calendar")
    func weeklyIntervalStartsMonday() throws {
        var sundayFirst = Calendar(identifier: .gregorian)
        sundayFirst.timeZone = TimeZone(identifier: "UTC")!
        sundayFirst.firstWeekday = 1

        let sunday = sundayFirst.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 10))!
        let interval = try #require(Stats.weekInterval(at: sunday, calendar: sundayFirst))
        // Sunday 15 November closes the Monday week that began on 9 November.
        let monday = sundayFirst.date(from: DateComponents(year: 2026, month: 11, day: 9))!
        #expect(interval.start == monday)
        #expect(sundayFirst.component(.weekday, from: interval.start) == 2)
    }

    @Test("Goal streak uses Monday weeks regardless of the caller's firstWeekday")
    func goalStreakUsesCanonicalWeeklyCalendar() {
        var sundayFirst = Calendar(identifier: .gregorian)
        sundayFirst.timeZone = TimeZone(identifier: "UTC")!
        sundayFirst.firstWeekday = 1
        var mondayFirst = sundayFirst
        mondayFirst.firstWeekday = 2

        // Wednesday. The current Monday week has one session so it is still
        // unfinished; the previous two Monday weeks each have two sessions,
        // including a Sunday in each that a Sunday-first calendar would move.
        let now = sundayFirst.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 12))!
        func date(_ month: Int, _ day: Int) -> Date {
            sundayFirst.date(from: DateComponents(year: 2026, month: month, day: day, hour: 10))!
        }
        let play = [
            PlaySession(date: date(11, 16)), // this week: 1 of 2
            PlaySession(date: date(11, 14)), // Saturday of last Monday week
            PlaySession(date: date(11, 15)), // Sunday of last Monday week
            PlaySession(date: date(11, 2)),  // Monday two weeks ago
            PlaySession(date: date(11, 8)),  // Sunday two weeks ago
        ]

        let mondayStreak = Stats.goalStreak(
            play: play, training: [], kind: .weekly, target: 2,
            calendar: mondayFirst, now: now
        )
        let sundayStreak = Stats.goalStreak(
            play: play, training: [], kind: .weekly, target: 2,
            calendar: sundayFirst, now: now
        )
        #expect(mondayStreak == 2)
        #expect(sundayStreak == mondayStreak)
    }
}

// MARK: - Dashboard period math

@Suite("Dashboard period aggregation")
struct DashboardPeriodTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 12))!
    }

    @Test("Chart buckets cover the whole interval and ignore outside sessions")
    func chartBuckets() {
        let week = calendar.dateInterval(of: .weekOfYear, for: now)!
        let play = [
            PlaySession(date: week.start, durationMinutes: 60),
            PlaySession(date: calendar.date(byAdding: .day, value: 1, to: week.start)!, durationMinutes: 30),
            PlaySession(date: calendar.date(byAdding: .day, value: -1, to: week.start)!, durationMinutes: 999),
        ]
        let training = [
            TrainingSession(date: week.start, durationMinutes: 45),
        ]

        let activity = Stats.dailyActivity(play: play, training: training, in: week, calendar: calendar)

        #expect(activity.count == 7)
        #expect(activity.first?.playMinutes == 60)
        #expect(activity.first?.trainingMinutes == 45)
        #expect(activity[1].playMinutes == 30)
        #expect(activity.allSatisfy { $0.totalMinutes <= 105 })
    }

    @Test("On-court minutes and chart totals agree")
    func minutesConsistency() {
        let month = calendar.dateInterval(of: .month, for: now)!
        let play = (0..<8).map { offset in
            PlaySession(
                date: calendar.date(byAdding: .day, value: offset, to: month.start)!,
                durationMinutes: 25 + offset
            )
        }
        let training = (0..<3).map { offset in
            TrainingSession(
                date: calendar.date(byAdding: .day, value: offset, to: month.start)!,
                durationMinutes: 40
            )
        }

        let direct = Stats.totalMinutes(play: play, training: training, in: month)
        let charted = Stats.dailyActivity(play: play, training: training, in: month, calendar: calendar)
            .reduce(0) { $0 + $1.totalMinutes }

        #expect(direct == charted)
        #expect(direct == (0..<8).reduce(0) { $0 + 25 + $1 } + 120)
    }

    @Test("Matches in interval exclude other periods")
    func matchesInInterval() {
        let week = calendar.dateInterval(of: .weekOfYear, for: now)!
        let matches = [
            Match(date: week.start, myGameScores: [21], opponentGameScores: [10]),
            Match(date: calendar.date(byAdding: .day, value: -10, to: week.start)!,
                  myGameScores: [21], opponentGameScores: [10]),
            Match(date: week.end, myGameScores: [21], opponentGameScores: [10]),
        ]

        let inWeek = Stats.matches(matches, in: week)
        #expect(inWeek.count == 1)
    }

    @Test("Win rate treats draws as non-wins and empty as zero")
    func winRateMath() {
        #expect(MatchLogic.winRate(of: []) == 0)

        let matches = [
            Match(date: day(-2), myGameScores: [21], opponentGameScores: [10]),  // win
            Match(date: day(-1), myGameScores: [10], opponentGameScores: [21]),  // loss
            Match(date: day(0), myGameScores: [0], opponentGameScores: [0]),     // unplayed / draw
        ]
        #expect(MatchLogic.winRate(of: matches) == 1.0 / 3.0)
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: now)!
    }
}
