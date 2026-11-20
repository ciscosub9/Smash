import Foundation
import Testing
@testable import Smash

@Suite("Coach's Corner insights")
struct CoachInsightsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ offset: Int, from now: Date = .now) -> Date {
        calendar.date(
            byAdding: .day,
            value: offset,
            to: calendar.startOfDay(for: now)
        )!
    }

    private func match(
        _ offset: Int,
        opponent: String,
        level: SkillLevel = .intermediate,
        partner: String = "",
        discipline: Discipline = .singles,
        format: MatchFormat = .bestOf3,
        mine: [Int] = [21, 21],
        theirs: [Int] = [15, 15],
        now: Date = .now
    ) -> Match {
        Match(
            date: day(offset, from: now),
            opponent: opponent,
            partner: partner,
            discipline: discipline,
            format: format,
            myGameScores: mine,
            opponentGameScores: theirs,
            opponentLevel: level
        )
    }

    private func match(
        at date: Date,
        opponent: String,
        level: SkillLevel = .intermediate,
        mine: [Int] = [21, 21],
        theirs: [Int] = [15, 15]
    ) -> Match {
        Match(
            date: date,
            opponent: opponent,
            myGameScores: mine,
            opponentGameScores: theirs,
            opponentLevel: level
        )
    }

    @Test("A win over a stronger opponent lifts the rating more than a win over a beginner")
    func beatingStrongerPlayerCountsMore() {
        let winOverStrong = match(-1, opponent: "Ace", level: .advanced)
        let winOverBeginner = match(-1, opponent: "Novice", level: .beginner)

        let strongRating = CoachInsights.rating(matches: [winOverStrong], calendar: calendar)
        let beginnerRating = CoachInsights.rating(matches: [winOverBeginner], calendar: calendar)

        #expect(strongRating.current > 1400)
        #expect(beginnerRating.current > 1400)
        #expect(strongRating.current > beginnerRating.current)
    }

    @Test("A loss lowers the rating")
    func lossLowersRating() {
        let loss = match(-1, opponent: "Ace", level: .advanced, mine: [17, 19], theirs: [21, 21])
        let rating = CoachInsights.rating(matches: [loss], calendar: calendar)
        #expect(rating.current < 1400)
    }

    @Test("Thirty-day trend ignores older results")
    func trendUsesWindow() {
        let now = Date.now
        let oldLoss = match(-45, opponent: "Old", level: .beginner, format: .singleGame, mine: [10], theirs: [21], now: now)
        let recentWin = match(-2, opponent: "New", level: .advanced, now: now)

        let rating = CoachInsights.rating(matches: [oldLoss, recentWin], now: now, calendar: calendar)

        #expect(rating.matchesRated == 1)
        #expect(rating.trend > 0)
    }

    @Test("A big straight-games vs decider gap produces the clutch insight")
    func deciderInsight() {
        let now = Date.now
        var matches: [Match] = []
        for index in 0..<3 {
            matches.append(match(-index - 1, opponent: "Straight\(index)", mine: [21, 21], theirs: [15, 18], now: now))
        }
        for index in 0..<3 {
            let mine = index == 0 ? [21, 18, 21] : [21, 19, 16]
            let theirs = index == 0 ? [18, 21, 19] : [19, 21, 21]
            matches.append(match(-index - 4, opponent: "Close\(index)", mine: mine, theirs: theirs, now: now))
        }

        let insights = CoachInsights.insights(matches: matches, now: now, calendar: calendar)
        let decider = insights.first { $0.id == "decider" }

        #expect(decider != nil)
        #expect(decider?.tone == .clutch)
        #expect(decider?.observation.contains("straight games") == true)
    }

    @Test("Named partners produce a pairing insight, singles partners do not")
    func partnerInsight() {
        let now = Date.now
        let matches = [
            match(-1, opponent: "A", partner: "Sam", discipline: .doubles, now: now),
            match(-2, opponent: "B", partner: "Sam", discipline: .doubles, now: now),
            match(-3, opponent: "C", partner: "Sam", discipline: .singles, now: now),
        ]

        let insights = CoachInsights.insights(matches: matches, now: now, calendar: calendar)
        // Grouping keys are normalized (lowercased) for deterministic ids.
        let pairing = insights.first { $0.id == "partner-sam" }

        #expect(pairing != nil)
        #expect(pairing?.tone == .partner)
        #expect(pairing?.evidence.contains("2 doubles matches") == true)
    }

    @Test("Fewer than three recent matches shows no advice")
    func minimumSample() {
        let now = Date.now
        let matches = [
            match(-1, opponent: "A", now: now),
            match(-2, opponent: "B", now: now),
        ]

        #expect(CoachInsights.insights(matches: matches, now: now, calendar: calendar).isEmpty)
    }

    @Test("Every insight carries evidence and an action")
    func insightsAreActionable() {
        let now = Date.now
        let matches = [
            match(-1, opponent: "Ravi", now: now),
            match(-2, opponent: "Ravi", mine: [19, 21], theirs: [21, 18], now: now),
            match(-3, opponent: "Meera", level: .advanced, partner: "Sam", discipline: .mixedDoubles, now: now),
            match(-4, opponent: "Sam", partner: "Meera", discipline: .doubles, now: now),
        ]

        let insights = CoachInsights.insights(matches: matches, now: now, calendar: calendar)

        #expect(!insights.isEmpty)
        for insight in insights {
            #expect(!insight.observation.isEmpty)
            #expect(!insight.evidence.isEmpty)
            #expect(!insight.action.isEmpty)
            #expect(!insight.title.isEmpty)
        }
    }

    // MARK: - Revalidated fixes

    @Test("Mismatched score arrays are treated as unknown and never crash")
    func mismatchedScoreArraysAreSafe() {
        let now = Date.now
        let matches = [
            match(-1, opponent: "A", mine: [21, 21, 18], theirs: [15, 18], now: now),
            match(-2, opponent: "B", mine: [21, 21], theirs: [15, 18, 12], now: now),
            match(-3, opponent: "C", mine: [21], theirs: [15], now: now),
            match(-4, opponent: "D", now: now),
        ]

        let rating = CoachInsights.rating(matches: matches, now: now, calendar: calendar)
        let insights = CoachInsights.insights(matches: matches, now: now, calendar: calendar)

        #expect(rating.matchesRated == 4)
        #expect(insights.contains(where: { $0.id == "decider" }) == false)
        #expect(insights.allSatisfy { !$0.title.isEmpty })
    }

    @Test("Future-dated matches do not change the rating or the insights")
    func futureDatesAreExcluded() {
        let now = Date.now
        let past = (0..<3).map { match(-$0 - 1, opponent: "P\($0)", level: .beginner, now: now) }
        let future = match(1, opponent: "Future", level: .beginner, now: now)

        let pastRating = CoachInsights.rating(matches: past, now: now, calendar: calendar)
        let mixedRating = CoachInsights.rating(matches: past + [future], now: now, calendar: calendar)
        let pastInsights = CoachInsights.insights(matches: past, now: now, calendar: calendar)
        let mixedInsights = CoachInsights.insights(matches: past + [future], now: now, calendar: calendar)

        #expect(mixedRating == pastRating)
        #expect(mixedInsights == pastInsights)
        #expect(mixedInsights.allSatisfy { !$0.evidence.contains("Future") })
    }

    @Test("The window includes its first instant and excludes either side")
    func windowBoundaryIsExact() {
        let now = Date.now
        let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))!
        let justBefore = calendar.date(byAdding: .second, value: -1, to: start)!
        let justAfterNow = calendar.date(byAdding: .second, value: 1, to: now)!

        let matches = [
            match(at: justBefore, opponent: "TooOld"),
            match(at: start, opponent: "OnBoundary"),
            match(at: justAfterNow, opponent: "TooNew"),
        ]
        let rating = CoachInsights.rating(matches: matches, now: now, calendar: calendar)
        #expect(rating.matchesRated == 1)

        let onBoundary = (0..<3).map { match(at: start, opponent: "B\($0)") }
        #expect(CoachInsights.insights(matches: onBoundary, now: now, calendar: calendar).isEmpty == false)
    }

    @Test("Losing to advanced or professional players never produces coast advice")
    func strongOpponentsDoNotProduceCoastAdvice() {
        let now = Date.now
        let matches = (0..<4).map { index in
            match(
                -index - 1,
                opponent: "Pro\(index)",
                level: index.isMultiple(of: 2) ? .professional : .advanced,
                mine: [12, 14],
                theirs: [21, 21],
                now: now
            )
        }

        let insights = CoachInsights.insights(matches: matches, now: now, calendar: calendar)

        #expect(insights.contains(where: { $0.title.localizedCaseInsensitiveContains("coast") }) == false)
        #expect(insights.contains(where: { $0.id.hasPrefix("level-") }) == false)
    }

    @Test("An opponent at exactly 50 percent is not a pattern")
    func exactlyFiftyPercentOpponentIsNotAPattern() {
        let now = Date.now
        let matches = [
            match(-1, opponent: "Ravi", now: now),
            match(-2, opponent: "Ravi", mine: [15, 18], theirs: [21, 21], now: now),
            match(-3, opponent: "Other", now: now),
        ]

        let insights = CoachInsights.insights(matches: matches, now: now, calendar: calendar)

        #expect(insights.contains(where: { $0.id.hasPrefix("opponent-") }) == false)
    }

    @Test("A slipping rating reads 'down N', not 'down -N'")
    func slippingCopyUsesAbsoluteValue() {
        let now = Date.now
        let matches = (0..<3).map { index in
            match(-index - 1, opponent: "Novice\(index)", level: .beginner,
                  mine: [10, 12], theirs: [21, 21], now: now)
        }

        let form = CoachInsights.insights(matches: matches, now: now, calendar: calendar)
            .first { $0.id == "form" }

        #expect(form != nil)
        #expect(form?.observation.contains("down ") == true)
        #expect(form?.observation.contains("down -") == false)
    }

    @Test("Draws appear in the match record inside insight copy")
    func drawsAppearInEvidence() {
        let now = Date.now
        let matches = [
            match(-1, opponent: "Ravi", now: now),
            match(-2, opponent: "Ravi", mine: [15, 18], theirs: [21, 21], now: now),
            match(-3, opponent: "Ravi", mine: [21, 21], theirs: [21, 21], now: now),
            match(-4, opponent: "Other", now: now),
            match(-5, opponent: "Other", now: now),
            match(-6, opponent: "Other", now: now),
        ]

        let ravi = CoachInsights.insights(matches: matches, now: now, calendar: calendar)
            .first { $0.id == "opponent-ravi" }

        #expect(ravi != nil)
        #expect(ravi?.observation.contains("1W–1L–1D") == true)
    }

    @Test("Opponent names are normalized for grouping but keep a display name")
    func opponentNamesAreNormalized() {
        let now = Date.now
        let matches = [
            match(-4, opponent: "Ravi", now: now),
            match(-3, opponent: "ravi ", mine: [15, 18], theirs: [21, 21], now: now),
            match(-2, opponent: "RAVI", mine: [12, 14], theirs: [21, 21], now: now),
            match(-1, opponent: "Other", now: now),
        ]

        let insights = CoachInsights.insights(matches: matches, now: now, calendar: calendar)
        let ravi = insights.first { $0.id == "opponent-ravi" }

        #expect(ravi != nil)
        #expect(ravi?.evidence.contains("3 matches") == true)
        #expect(ravi?.observation.contains("Ravi") == true)
        #expect(CoachInsights.rating(matches: matches, now: now, calendar: calendar).matchesRated == 4)
    }

    @Test("Partner names are normalized for grouping")
    func partnerNamesAreNormalized() {
        let now = Date.now
        let matches = [
            match(-4, opponent: "A", partner: "Sam", discipline: .doubles, now: now),
            match(-3, opponent: "B", partner: " sam ", discipline: .doubles, now: now),
            match(-2, opponent: "C", partner: "SAM", discipline: .doubles, now: now),
            match(-1, opponent: "D", discipline: .singles, now: now),
        ]

        let insights = CoachInsights.insights(matches: matches, now: now, calendar: calendar)
        let partner = insights.first { $0.id == "partner-sam" }

        #expect(partner != nil)
        #expect(partner?.evidence.contains("3 doubles matches") == true)
        #expect(partner?.observation.contains("Sam") == true)
    }

    @Test("Tied groups prefer the larger sample, then the alphabetically first label")
    func deterministicTieBreaks() {
        let now = Date.now
        let losing = [10, 10]
        let winning = [21, 21]

        let sampleSizeMatches: [Match] = [
            match(-1, opponent: "Amy", mine: losing, theirs: winning, now: now),
            match(-2, opponent: "Amy", mine: losing, theirs: winning, now: now),
            match(-3, opponent: "Zed", mine: losing, theirs: winning, now: now),
            match(-4, opponent: "Zed", mine: losing, theirs: winning, now: now),
            match(-5, opponent: "Zed", mine: losing, theirs: winning, now: now),
            match(-6, opponent: "Zed", mine: losing, theirs: winning, now: now),
            match(-7, opponent: "W1", now: now),
            match(-8, opponent: "W2", now: now),
            match(-9, opponent: "W3", now: now),
            match(-10, opponent: "W4", now: now),
        ]
        let bySample = CoachInsights.insights(matches: sampleSizeMatches, now: now, calendar: calendar)
            .first { $0.id.hasPrefix("opponent-") }
        #expect(bySample?.id == "opponent-zed")
        #expect(bySample?.evidence.contains("4 matches") == true)

        let alphabeticalMatches: [Match] = [
            match(-1, opponent: "Zoe", mine: losing, theirs: winning, now: now),
            match(-2, opponent: "Zoe", mine: losing, theirs: winning, now: now),
            match(-3, opponent: "Amy", mine: losing, theirs: winning, now: now),
            match(-4, opponent: "Amy", mine: losing, theirs: winning, now: now),
            match(-5, opponent: "W1", now: now),
            match(-6, opponent: "W2", now: now),
        ]
        let byName = CoachInsights.insights(matches: alphabeticalMatches, now: now, calendar: calendar)
            .first { $0.id.hasPrefix("opponent-") }
        #expect(byName?.id == "opponent-amy")
    }

    @Test("Empty or whitespace-only input is safe")
    func emptyInputIsSafe() {
        let now = Date.now
        let emptyRating = CoachInsights.rating(matches: [], now: now, calendar: calendar)
        #expect(emptyRating.matchesRated == 0)
        #expect(emptyRating.history.isEmpty)
        #expect(emptyRating.trend == 0)
        #expect(CoachInsights.insights(matches: [], now: now, calendar: calendar).isEmpty)

        let blank = (0..<3).map { match(-$0 - 1, opponent: "   ", now: now) }
        #expect(CoachInsights.rating(matches: blank, now: now, calendar: calendar).matchesRated == 0)
        #expect(CoachInsights.insights(matches: blank, now: now, calendar: calendar).isEmpty)
    }

    @Test("Form insight confidence follows the sample size")
    func formConfidenceFollowsSampleSize() {
        let now = Date.now
        let few = (0..<3).map { match(-$0 - 1, opponent: "F\($0)", now: now) }
        let many = (0..<12).map { match(-$0 - 1, opponent: "M\($0)", now: now) }

        let fewForm = CoachInsights.insights(matches: few, now: now, calendar: calendar)
            .first { $0.id == "form" }
        let manyForm = CoachInsights.insights(matches: many, now: now, calendar: calendar)
            .first { $0.id == "form" }

        #expect(fewForm?.confidence == .early)
        #expect(manyForm?.confidence == .high)
        #expect(manyForm?.evidence.contains("12 matches rated") == true)
    }

    @Test("Discipline insight uses the discipline's own symbol")
    func disciplineSymbolComesFromTheDiscipline() {
        let now = Date.now

        func set(singlesWin: Bool) -> [Match] {
            var result: [Match] = []
            for index in 0..<4 {
                result.append(match(
                    -index - 1,
                    opponent: "S\(index)",
                    mine: singlesWin ? [21, 21] : [10, 10],
                    theirs: singlesWin ? [15, 15] : [21, 21],
                    now: now
                ))
                result.append(match(
                    -index - 1,
                    opponent: "D\(index)",
                    discipline: .doubles,
                    mine: singlesWin ? [10, 10] : [21, 21],
                    theirs: singlesWin ? [21, 21] : [15, 15],
                    now: now
                ))
            }
            return result
        }

        let worstSingles = CoachInsights.insights(matches: set(singlesWin: false), now: now, calendar: calendar)
            .first { $0.id == "discipline-Singles" }
        #expect(worstSingles?.symbol == Discipline.singles.symbol)

        let worstDoubles = CoachInsights.insights(matches: set(singlesWin: true), now: now, calendar: calendar)
            .first { $0.id == "discipline-Doubles" }
        #expect(worstDoubles?.symbol == Discipline.doubles.symbol)
    }
}
