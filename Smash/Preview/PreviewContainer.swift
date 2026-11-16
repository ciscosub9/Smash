import Foundation
import SwiftData

/// In-memory container with sample data for Xcode Previews and SwiftUI previews.
enum PreviewContainer {
    static func make(withSampleData: Bool = true) -> ModelContainer {
        let schema = Schema([
            PlaySession.self,
            TrainingSession.self,
            Match.self,
            Tournament.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])

        if withSampleData {
            let context = container.mainContext
            let tournament = Tournament(
                name: "Club Open 2026",
                type: .knockout,
                placement: .semiFinal,
                strategyNotes: "Push the pace early — opponents tire in game two."
            )
            context.insert(tournament)

            context.insert(Match(
                opponent: "Ravi",
                discipline: .singles,
                pointSystem: .points21,
                format: .bestOf3,
                myGameScores: [21, 18, 21],
                opponentGameScores: [15, 21, 19],
                tournament: tournament
            ))
            context.insert(Match(
                opponent: "Anil",
                discipline: .doubles,
                pointSystem: .points15,
                format: .singleGame,
                myGameScores: [15],
                opponentGameScores: [11]
            ))
            context.insert(Match(
                opponent: "Ravi",
                discipline: .singles,
                pointSystem: .continuous,
                format: .singleGame,
                myGameScores: [38],
                opponentGameScores: [41]
            ))

            let calendar = Calendar.current
            for (offset, minutes) in [(0, 60), (1, 90), (3, 60), (4, 45)] {
                context.insert(PlaySession(
                    date: calendar.date(byAdding: .day, value: -offset, to: .now) ?? .now,
                    durationMinutes: minutes,
                    discipline: .singles,
                    intensity: .moderate,
                    opponents: ["Ravi", "Anil"]
                ))
            }
            context.insert(TrainingSession(
                durationMinutes: 90,
                coach: "Coach Manoj",
                focusAreas: [TrainingFocus.footwork.label, TrainingFocus.smashes.label],
                drillsDescription: "Shadow footwork 3×10, half-court smash rallies, net kill practice."
            ))
        }

        return container
    }

    static var container: ModelContainer { make() }
}
