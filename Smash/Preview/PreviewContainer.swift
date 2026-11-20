import Foundation
import SwiftData

/// Sample data for Xcode Previews, SwiftUI previews, and `-sampleData` launches.
enum SampleData {
    /// Inserts demo records once, only if the store is empty.
    static func seedIfNeeded(context: ModelContext) {
        do {
            guard try context.fetchCount(FetchDescriptor<PlaySession>()) == 0 else { return }
        } catch {
            return
        }
        seed(context: context)
    }

    /// Generates a month of realistic sample data across every section.
    /// Safe to call repeatedly in an empty store; intended for previews and
    /// launch-argument-driven QA (`-sampleData`).
    static func seed(context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()

        // Player profile + goal so the Dashboard goal card and streaks light up.
        PlayerProfile.name = "Alex"
        PlayerProfile.skillLevel = .intermediate
        PlayerGoal.kind = .weekly
        PlayerGoal.target = 3

        let savedPlayers = [
            Player(name: "Ravi", level: .advanced, notes: "Flat kills off a low serve."),
            Player(name: "Anil", level: .intermediate),
            Player(name: "Priya", level: .intermediate),
            Player(name: "Marcus", level: .beginner),
            Player(name: "Mei", level: .advanced),
        ]
        savedPlayers.forEach { context.insert($0) }

        func at(dayOffset: Int, hour: Int, minute: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        // MARK: - Tournaments
        let clubOpen = Tournament(
            name: "Club Open 2026",
            type: .knockout,
            startDate: at(dayOffset: -27, hour: 9),
            endDate: at(dayOffset: -26, hour: 17),
            placement: .semiFinal,
            strategyNotes: "Push the pace early — opponents tire in game two. Keep the serve low; Ravi loves flat kills."
        )
        let ladder = Tournament(
            name: "City Ladder League",
            type: .ladder,
            startDate: at(dayOffset: -20, hour: 18),
            endDate: at(dayOffset: -5, hour: 21),
            placement: .runnerUp,
            strategyNotes: "Play percentage shots on tired legs. Use the backhand clear to reset rallies."
        )
        let roundRobin = Tournament(
            name: "Friday Round Robin",
            type: .roundRobin,
            startDate: at(dayOffset: -12, hour: 19),
            placement: .third,
            strategyNotes: "Stay aggressive at the net. Mixed doubles — hold the front court."
        )
        [clubOpen, ladder, roundRobin].forEach { context.insert($0) }

        // MARK: - Matches (21-point, 15-point, continuous, best-of-3, singles/doubles/mixed)
        let matches: [Match] = [
            Match(date: at(dayOffset: -1, hour: 19, minute: 30), opponent: "Ravi", discipline: .singles, pointSystem: .points21, format: .bestOf3,
                  myGameScores: [21, 18, 22], opponentGameScores: [15, 21, 20],
                  notes: "Slow start in game two — stayed patient in the decider (deuce).",
                  opponentLevel: .intermediate, intensity: .hard),
            Match(date: at(dayOffset: -3, hour: 18), opponent: "Anil", partner: "Sanjay", discipline: .doubles, pointSystem: .points15, format: .singleGame,
                  myGameScores: [15], opponentGameScores: [11],
                  opponentLevel: .beginner, intensity: .easy),
            Match(date: at(dayOffset: -4, hour: 20), opponent: "Ravi", discipline: .singles, pointSystem: .continuous, format: .singleGame,
                  myGameScores: [38], opponentGameScores: [41],
                  notes: "Long continuous rally session — focus was consistency.",
                  opponentLevel: .intermediate, intensity: .moderate),
            Match(date: at(dayOffset: -6, hour: 19), opponent: "Meera", partner: "Priya", discipline: .mixedDoubles, pointSystem: .points21, format: .bestOf3,
                  myGameScores: [21, 21], opponentGameScores: [17, 19],
                  notes: "Good net control with partner.", opponentLevel: .advanced, intensity: .hard),
            Match(date: at(dayOffset: -8, hour: 18, minute: 30), opponent: "Sanjay", discipline: .singles, pointSystem: .points21, format: .singleGame,
                  myGameScores: [30], opponentGameScores: [29],
                  notes: "Reached the 30-point cap — marathon game.", opponentLevel: .advanced, intensity: .hard),
            Match(date: at(dayOffset: -10, hour: 17), opponent: "Priya", partner: "Anil", discipline: .doubles, pointSystem: .points15, format: .bestOf3,
                  myGameScores: [15, 13, 21], opponentGameScores: [9, 15, 20],
                  notes: "Tight decider at the 21 cap.", opponentLevel: .intermediate, intensity: .moderate, tournament: roundRobin),
            Match(date: at(dayOffset: -12, hour: 20), opponent: "Kiran", discipline: .singles, pointSystem: .points21, format: .bestOf3,
                  myGameScores: [21, 21], opponentGameScores: [13, 16],
                  opponentLevel: .amateur, intensity: .easy, tournament: roundRobin),
            Match(date: at(dayOffset: -14, hour: 19), opponent: "Anil", discipline: .singles, pointSystem: .points21, format: .bestOf3,
                  myGameScores: [19, 21, 18], opponentGameScores: [21, 17, 21],
                  notes: "Lost the third — footwork faded late.", opponentLevel: .beginner, intensity: .moderate),
            Match(date: at(dayOffset: -16, hour: 18), opponent: "Ravi", discipline: .singles, pointSystem: .points21, format: .bestOf3,
                  myGameScores: [21, 22], opponentGameScores: [18, 20],
                  opponentLevel: .intermediate, intensity: .hard, tournament: ladder),
            Match(date: at(dayOffset: -18, hour: 19, minute: 15), opponent: "Meera", partner: "Priya", discipline: .mixedDoubles, pointSystem: .points15, format: .singleGame,
                  myGameScores: [12], opponentGameScores: [15],
                  opponentLevel: .advanced, intensity: .hard, tournament: ladder),
            Match(date: at(dayOffset: -21, hour: 18), opponent: "Sanjay", discipline: .singles, pointSystem: .points21, format: .bestOf3,
                  myGameScores: [21, 16, 21], opponentGameScores: [19, 21, 17],
                  opponentLevel: .advanced, intensity: .hard, tournament: ladder),
            Match(date: at(dayOffset: -23, hour: 17, minute: 30), opponent: "Priya", partner: "Anil", discipline: .doubles, pointSystem: .continuous, format: .singleGame,
                  myGameScores: [45], opponentGameScores: [39],
                  opponentLevel: .intermediate, intensity: .moderate),
            Match(date: at(dayOffset: -26, hour: 14), opponent: "Ravi", discipline: .singles, pointSystem: .points21, format: .bestOf3,
                  myGameScores: [21, 19, 18], opponentGameScores: [17, 21, 21],
                  notes: "Semi-final loss — needed better recovery between points.",
                  opponentLevel: .intermediate, intensity: .hard, tournament: clubOpen),
            Match(date: at(dayOffset: -27, hour: 10), opponent: "Kiran", discipline: .singles, pointSystem: .points21, format: .bestOf3,
                  myGameScores: [21, 21], opponentGameScores: [12, 14],
                  opponentLevel: .amateur, intensity: .moderate, tournament: clubOpen),
            Match(date: at(dayOffset: -29, hour: 18), opponent: "Anil", partner: "Sanjay", discipline: .doubles, pointSystem: .points15, format: .singleGame,
                  myGameScores: [16], opponentGameScores: [14],
                  opponentLevel: .beginner, intensity: .easy),
            // Logged together with the play session below — one card in Sessions.
            Match(date: at(dayOffset: -2, hour: 17), opponent: "Kiran", discipline: .singles, pointSystem: .points21, format: .bestOf3,
                  myGameScores: [21, 16, 21], opponentGameScores: [18, 21, 19],
                  notes: "Close decider — kept the net game tight.", opponentLevel: .intermediate, intensity: .moderate),
        ]
        matches.forEach { context.insert($0) }

        // MARK: - Play sessions (spread across the month, varied times/durations/partners)
        let playData: [(Int, Int, Int, Int, Discipline, Intensity, String, [String], String?)] = [
            (0,  18, 30, 75, .singles,     .moderate, "Courts Club", ["Ravi"],                "Quick evening hit after work."),
            (1,  19,  0, 90, .doubles,     .hard,     "Courts Club", ["Ravi", "Anil"],        "Fast doubles — lots of net exchanges."),
            (2,  10,  0, 60, .mixedDoubles,.moderate, "City Sports Hall", ["Meera"],          "Weekend mixed session."),
            (2,  17,  0, 75, .singles,     .moderate, "Courts Club", ["Kiran"],               "Scored session with a tight third game."),
            (3,  18,  0, 45, .singles,     .easy,     "Courts Club", ["Kiran"],               "Light rally, focused on clears."),
            (5,  19, 30, 80, .doubles,     .hard,     "Courts Club", ["Priya", "Sanjay"],     nil),
            (6,  9,   0, 70, .singles,     .moderate, "Park Courts", ["Ravi"],                "Outdoor courts — wind made drops tricky."),
            (7,  18, 15, 60, .mixedDoubles,.moderate, "Courts Club", ["Meera", "Anil"],       nil),
            (9,  19,  0, 90, .doubles,     .hard,     "City Sports Hall", ["Sanjay", "Priya"], "League practice night."),
            (10, 10, 30, 55, .singles,     .easy,     "Courts Club", ["Kiran"],               nil),
            (12, 18,  0, 75, .singles,     .moderate, "Courts Club", ["Ravi"],                "Worked on backhand defense."),
            (13, 19, 30, 60, .doubles,     .moderate, "City Sports Hall", ["Anil", "Priya"],  nil),
            (15, 9,   0, 85, .mixedDoubles,.hard,     "Courts Club", ["Meera"],               "Intense mixed drills into play."),
            (16, 18, 45, 50, .singles,     .easy,     "Park Courts", ["Kiran"],               nil),
            (18, 19,  0, 90, .doubles,     .hard,     "Courts Club", ["Ravi", "Sanjay"],      nil),
            (19, 10,  0, 65, .singles,     .moderate, "Courts Club", ["Anil"],                nil),
            (21, 18, 30, 70, .mixedDoubles,.moderate, "City Sports Hall", ["Meera", "Priya"], nil),
            (22, 19,  0, 60, .singles,     .easy,     "Courts Club", ["Kiran"],               "Recovery session."),
            (24, 18,  0, 80, .doubles,     .hard,     "Courts Club", ["Ravi", "Anil"],        nil),
            (25, 9,  30, 55, .singles,     .moderate, "Park Courts", ["Priya"],               nil),
            (27, 17,  0, 90, .doubles,     .moderate, "City Sports Hall", ["Sanjay", "Meera"], "Pre-tournament warm-up."),
            (28, 18, 30, 60, .singles,     .easy,     "Courts Club", ["Ravi"],                nil),
            (30, 19,  0, 75, .mixedDoubles,.moderate, "Courts Club", ["Anil", "Meera"],       "End-of-month social games."),
        ]
        for item in playData {
            context.insert(PlaySession(
                date: at(dayOffset: -item.0, hour: item.1, minute: item.2),
                durationMinutes: item.3,
                discipline: item.4,
                intensity: item.5,
                location: item.6,
                opponents: item.7,
                notes: item.8
            ))
        }

        // MARK: - Training sessions (varied drills, each with its own load)
        let trainingData: [(Int, Int, Int, Int, [String], String, [String], [Int], [Intensity?], String?)] = [
            (1,  17,  0, 90, [TrainingFocus.footwork.label, TrainingFocus.smashes.label],
             "Shadow footwork 3×10, half-court smash rallies, net kill practice.", ["Multi-shuttle", "Net kills"], [6, 4], [.hard, .moderate],
             "Lunge depth improving — keep an eye on right-knee position."),
            (4,  18,  0, 60, [TrainingFocus.clears.label, TrainingFocus.defense.label],
             "High clear consistency, defensive lifts under pressure.", ["Clear drills", "Lifts"], [5, 5], [.moderate, .easy], nil),
            (7,  17, 30, 75, [TrainingFocus.netPlay.label, TrainingFocus.serves.label],
             "Short serve accuracy ladder, spin net shots, tumble net kills.", ["Serve accuracy", "Net shots"], [8, 6], [.moderate, .moderate],
             "Serve toss is more consistent now."),
            (9,  18,  0, 50, [TrainingFocus.drops.label, TrainingFocus.strategy.label],
             "Cross-court drops, deception practice, rally patterns.", ["Drop shots"], [4], [.easy], nil),
            (11, 17,  0, 90, [TrainingFocus.footwork.label, TrainingFocus.defense.label],
             "Split-step timing, corner-to-corner drives, block defense.", ["Shadow footwork", "Block defense"], [6, 6], [.hard, .moderate],
             "Recovery to base still a beat slow on the backhand side."),
            (14, 18, 30, 60, [TrainingFocus.smashes.label, TrainingFocus.netPlay.label],
             "Jump smash timing, follow-up net kill, rotation work.", ["Smash practice", "Net kills"], [5, 4], [.hard, .moderate], nil),
            (17, 17,  0, 45, [TrainingFocus.serves.label],
             "Flick serve variation, low serve tightness.", ["Serve accuracy"], [7], [.easy], nil),
            (20, 18,  0, 80, [TrainingFocus.footwork.label, TrainingFocus.clears.label, TrainingFocus.drops.label],
             "Full-court movement, clear-drop combinations, endurance rally.", ["Footwork ladder", "Clear drills", "Drop shots"], [6, 6, 4], [.hard, .moderate, .moderate],
             "Good stamina today — kept intensity through the last set."),
            (23, 17, 30, 55, [TrainingFocus.defense.label, TrainingFocus.strategy.label],
             "Drive defense, counter-attack patterns, reading the opponent's body.", ["Defense drills"], [4], [.moderate], nil),
            (26, 18,  0, 70, [TrainingFocus.netPlay.label, TrainingFocus.drops.label],
             "Net kill pressure, tight spinning net shots, cross-court net exchanges.", ["Net shots", "Drop shots"], [5, 5], [.moderate, .easy], nil),
            (29, 17,  0, 60, [TrainingFocus.footwork.label, TrainingFocus.serves.label],
             "Agility ladder, serve placement targets.", ["Conditioning"], [3], [.easy],
             "Light session before the new month."),
        ]
        for item in trainingData {
            context.insert(TrainingSession(
                date: at(dayOffset: -item.0, hour: item.1, minute: item.2),
                durationMinutes: item.3,
                focusAreas: item.4,
                drillsDescription: item.5,
                drillNames: item.6,
                drillSets: item.7,
                drillIntensities: item.8.map { $0?.rawValue ?? "" },
                setsDone: item.7.first,
                intensity: item.8.first ?? nil,
                notes: item.9
            ))
        }
    }
}

/// In-memory container with sample data for Xcode Previews and SwiftUI previews.
enum PreviewContainer {
    static func make(withSampleData: Bool = true) -> ModelContainer {
        let schema = Schema([
            Player.self,
            PlaySession.self,
            TrainingSession.self,
            Match.self,
            Tournament.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(for: schema, configurations: [config])

        if withSampleData {
            SampleData.seed(context: container.mainContext)
        }

        return container
    }

    static var container: ModelContainer { make() }
}
