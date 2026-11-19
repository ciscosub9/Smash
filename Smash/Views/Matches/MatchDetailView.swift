import SwiftUI
import SwiftData

struct MatchDetailView: View {
    @Bindable var match: Match
    @Environment(\.modelContext) private var context
    @State private var showEdit = false
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section {
                HStack {
                    OutcomeBadge(outcome: MatchLogic.outcome(match))
                    Spacer()
                    Text(AppFormat.dateTime(match.date))
                        .foregroundStyle(.secondary)
                }
            }

            Section("Score") {
                ForEach(match.myGameScores.indices, id: \.self) { index in
                    HStack {
                        Text("Game \(index + 1)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(match.myGameScores[index]) – \(match.opponentGameScores[index])")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                    }
                }
                Text(match.pointSystem.label)
                    .foregroundStyle(.secondary)
            }

            Section("Details") {
                LabeledContent("Opponent", value: match.opponent)
                if let level = match.opponentLevel {
                    LabeledContent("Opponent level", value: level.label)
                }
                LabeledContent("Discipline", value: match.discipline.label)
                LabeledContent("Format", value: match.format.label)
                if let intensity = match.intensity {
                    LabeledContent("Intensity", value: intensity.label)
                }
                if let tournament = match.tournament {
                    NavigationLink {
                        TournamentDetailView(tournament: tournament)
                    } label: {
                        LabeledContent("Tournament", value: tournament.name)
                    }
                }
            }

            if let notes = match.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }
        }
        .navigationTitle("vs \(match.opponent)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit") { showEdit = true }
                    Button("Delete", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            MatchFormView(match: match)
        }
        .confirmationDialog(
            "Delete this match?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete match", role: .destructive) {
                context.delete(match)
            }
        } message: {
            Text("This can't be undone.")
        }
    }
}
