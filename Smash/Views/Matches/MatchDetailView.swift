import SwiftUI
import SwiftData

struct MatchDetailView: View {
    @Bindable var match: Match
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.tabSelection) private var tabSelection
    @State private var showEdit = false
    @State private var confirmDelete = false

    /// Imported or hand-edited backups can have unequal score arrays. Only
    /// show pairs that exist in both, so indexing can never go out of bounds.
    private var pairedGameCount: Int {
        min(match.myGameScores.count, match.opponentGameScores.count)
    }

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
                ForEach(0..<pairedGameCount, id: \.self) { index in
                    HStack {
                        Text("Game \(index + 1)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(match.gameDescription(index))
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                    }
                }
                Text(match.pointSystem.label)
                    .foregroundStyle(.secondary)
            }

            Section("Details") {
                LabeledContent("Opponent", value: match.opponent)
                if match.usesPartner {
                    LabeledContent("Partner", value: match.partner.isEmpty ? "Not set" : match.partner)
                }
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
        .navigationTitle("Me vs \(match.opponent)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit") { showEdit = true }
                    Button("Delete", role: .destructive) { confirmDelete = true }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            PlayFormView(match: match) {
                showEdit = false
                tabSelection.wrappedValue = .sessions
                dismiss()
            }
        }
        .confirmationDialog(
            "Delete this match?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete match", role: .destructive) {
                context.delete(match)
                dismiss()
            }
        } message: {
            Text("This can't be undone.")
        }
    }
}
