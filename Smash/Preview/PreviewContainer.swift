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

    static func seed(context: ModelContext) {
        let calendar = Calendar.current
        let tournament = Tournament(
            name: "Club Open 2026",
            type: .knockout,
            placement: .semiFinal,
            strategyNotes: "Push the pace early — opponents tire in game two. Keep the serve low; Ravi loves flat kills."
        )
        context.insert(tournament)

        context.insert(Match(
            date: calendar.date(byAdding: .day, value: -1, to: .now) ?? .now,
            opponent: "Ravi",
            discipline: .singles,
            pointSystem: .points21,
            format: .bestOf3,
            myGameScores: [21, 18, 21],
            opponentGameScores: [15, 21, 19],
            notes: "Slow start in game two — stayed patient on the decider.",
            opponentLevel: .intermediate,
            intensity: .hard,
            tournament: tournament
        ))
        context.insert(Match(
            date: calendar.date(byAdding: .day, value: -2, to: .now) ?? .now,
            opponent: "Anil",
            discipline: .doubles,
            pointSystem: .points15,
            format: .singleGame,
            myGameScores: [15],
            opponentGameScores: [11],
            opponentLevel: .beginner,
            intensity: .easy
        ))
        context.insert(Match(
            date: calendar.date(byAdding: .day, value: -4, to: .now) ?? .now,
            opponent: "Ravi",
            discipline: .singles,
            pointSystem: .continuous,
            format: .singleGame,
            myGameScores: [38],
            opponentGameScores: [41],
            opponentLevel: .intermediate,
            intensity: .moderate
        ))

        for (offset, minutes) in [(0, 60), (1, 90), (3, 60), (4, 45)] {
            context.insert(PlaySession(
                date: calendar.date(byAdding: .day, value: -offset, to: .now) ?? .now,
                durationMinutes: minutes,
                discipline: .singles,
                intensity: .moderate,
                location: "Courts Club",
                opponents: ["Ravi", "Anil"]
            ))
        }
        context.insert(TrainingSession(
            durationMinutes: 90,
            coach: "Coach Manoj",
            focusAreas: [TrainingFocus.footwork.label, TrainingFocus.smashes.label],
            drillsDescription: "Shadow footwork 3×10, half-court smash rallies, net kill practice.",
            drillName: "Multi-shuttle",
            setsDone: 6,
            intensity: .hard,
            notes: "Lunge depth improving — keep an eye on right-knee position."
        ))
        context.insert(TrainingSession(
            durationMinutes: 45,
            focusAreas: [TrainingFocus.serves.label, TrainingFocus.netPlay.label],
            drillsDescription: "Short serve accuracy ladder, spin net shots.",
            drillName: "Serve accuracy",
            setsDone: 4,
            intensity: .easy
        ))
    }
}

/// In-memory container with sample data for Xcode Previews and SwiftUI previews.
enum PreviewContainer {
    static func make(withSampleData: Bool = true) -> ModelContainer {
        let schema = Schema([
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
