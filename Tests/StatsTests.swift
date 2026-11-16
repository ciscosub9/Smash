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
}
