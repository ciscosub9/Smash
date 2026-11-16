import Testing
@testable import Smash

@Suite("Match scoring logic")
struct MatchLogicTests {

    // MARK: Single game

    @Test("Single game: higher points wins")
    func singleGameWin() {
        let outcome = MatchLogic.matchOutcome(
            myGameScores: [21], opponentGameScores: [15], format: .singleGame
        )
        #expect(outcome == .win)
    }

    @Test("Single game: lower points loses")
    func singleGameLoss() {
        let outcome = MatchLogic.matchOutcome(
            myGameScores: [8], opponentGameScores: [15], format: .singleGame
        )
        #expect(outcome == .loss)
    }

    @Test("Continuous: higher points wins regardless of size")
    func continuousWin() {
        let outcome = MatchLogic.matchOutcome(
            myGameScores: [57], opponentGameScores: [41], format: .singleGame
        )
        #expect(outcome == .win)
    }

    // MARK: Best of 3

    @Test("Best of 3: straight games win")
    func bestOf3StraightWin() {
        let outcome = MatchLogic.matchOutcome(
            myGameScores: [21, 21, 0], opponentGameScores: [10, 17, 0], format: .bestOf3
        )
        #expect(outcome == .win)
    }

    @Test("Best of 3: three-game comeback win")
    func bestOf3ComebackWin() {
        let outcome = MatchLogic.matchOutcome(
            myGameScores: [21, 18, 21], opponentGameScores: [15, 21, 19], format: .bestOf3
        )
        #expect(outcome == .win)
    }

    @Test("Best of 3: loss in three")
    func bestOf3Loss() {
        let outcome = MatchLogic.matchOutcome(
            myGameScores: [19, 21, 17], opponentGameScores: [21, 18, 21], format: .bestOf3
        )
        #expect(outcome == .loss)
    }

    @Test("Best of 3: unfinished match falls back to total points")
    func bestOf3UnfinishedFallback() {
        // One game played and won 21-5: games 1-0, points 21-5 → win.
        let outcome = MatchLogic.matchOutcome(
            myGameScores: [21, 0, 0], opponentGameScores: [5, 0, 0], format: .bestOf3
        )
        #expect(outcome == .win)
    }

    // MARK: Win rate

    @Test("Win rate: empty history is zero")
    func winRateEmpty() {
        #expect(MatchLogic.winRate(of: []) == 0)
    }

    @Test("Win rate: counts wins over all matches")
    func winRateCounts() {
        let matches = [
            makeMatch(my: [21], opp: [10]),   // win
            makeMatch(my: [12], opp: [21]),   // loss
            makeMatch(my: [21], opp: [19]),   // win
        ]
        #expect(MatchLogic.winRate(of: matches) == 2.0 / 3.0)
    }

    @Test("Win rate: draws count in the denominator")
    func winRateDraws() {
        let matches = [
            makeMatch(my: [21], opp: [10]),   // win
            makeMatch(my: [15], opp: [15]),   // draw
        ]
        #expect(MatchLogic.winRate(of: matches) == 0.5)
    }

    // MARK: Helpers

    private func makeMatch(my: [Int], opp: [Int]) -> Match {
        Match(
            opponent: "Test",
            myGameScores: my,
            opponentGameScores: opp
        )
    }
}
