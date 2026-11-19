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

@Suite("Score validation")
struct ScoreValidationTests {

    // MARK: 21-point game

    @Test("21-point: 21–20 is not a final score")
    func twentyOneTwentyInvalid() {
        #expect(!MatchLogic.isValidGame(myPoints: 21, opponentPoints: 20, pointSystem: .points21))
    }

    @Test("21-point: 22–20 is a deuce win")
    func twentyTwoTwentyValid() {
        #expect(MatchLogic.isValidGame(myPoints: 22, opponentPoints: 20, pointSystem: .points21))
    }

    @Test("21-point: 30–29 is valid at the cap")
    func capValid() {
        #expect(MatchLogic.isValidGame(myPoints: 30, opponentPoints: 29, pointSystem: .points21))
        #expect(!MatchLogic.isValidGame(myPoints: 30, opponentPoints: 30, pointSystem: .points21))
        #expect(!MatchLogic.isValidGame(myPoints: 31, opponentPoints: 20, pointSystem: .points21))
    }

    @Test("21-point: 29–28 is still one point short of the cap")
    func nearCapInvalid() {
        #expect(!MatchLogic.isValidGame(myPoints: 29, opponentPoints: 28, pointSystem: .points21))
    }

    // MARK: 15-point game

    @Test("15-point: 15–14 invalid, 16–14 valid, 21–20 valid at the cap")
    func fifteenPointRules() {
        #expect(!MatchLogic.isValidGame(myPoints: 15, opponentPoints: 14, pointSystem: .points15))
        #expect(MatchLogic.isValidGame(myPoints: 16, opponentPoints: 14, pointSystem: .points15))
        #expect(MatchLogic.isValidGame(myPoints: 21, opponentPoints: 20, pointSystem: .points15))
        #expect(!MatchLogic.isValidGame(myPoints: 22, opponentPoints: 20, pointSystem: .points15))
    }

    // MARK: Continuous and unplayed games

    @Test("Continuous: any score, and 0–0 counts as unplayed")
    func continuousRules() {
        #expect(MatchLogic.isValidGame(myPoints: 57, opponentPoints: 41, pointSystem: .continuous))
        #expect(MatchLogic.isValidGame(myPoints: 3, opponentPoints: 0, pointSystem: .continuous))
        #expect(MatchLogic.isValidGame(myPoints: 0, opponentPoints: 0, pointSystem: .points21))
    }

    @Test("Best of 3: an unplayed third game is allowed")
    func unplayedThirdGame() {
        #expect(MatchLogic.invalidGameIndexes(
            myGameScores: [21, 18, 0],
            opponentGameScores: [15, 21, 0],
            format: .bestOf3,
            pointSystem: .points21
        ).isEmpty)
    }

    @Test("Best of 3: the unfinished game is the one flagged")
    func flagsOnlyBadGame() {
        let indexes = MatchLogic.invalidGameIndexes(
            myGameScores: [21, 21, 0],
            opponentGameScores: [15, 20, 0],
            format: .bestOf3,
            pointSystem: .points21
        )
        #expect(indexes == [1])
        #expect(MatchLogic.validationMessage(
            myGameScores: [21, 21, 0],
            opponentGameScores: [15, 20, 0],
            format: .bestOf3,
            pointSystem: .points21
        )?.contains("Game 2") == true)
    }

    @Test("A match with no scores at all cannot be saved")
    func emptyMatchInvalid() {
        #expect(MatchLogic.validationMessage(
            myGameScores: [0],
            opponentGameScores: [0],
            format: .singleGame,
            pointSystem: .points21
        )?.contains("at least one game") == true)
    }
}
