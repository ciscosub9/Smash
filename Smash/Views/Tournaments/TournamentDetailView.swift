import SwiftUI
import SwiftData

struct TournamentDetailView: View {
    @Bindable var tournament: Tournament
    @Environment(\.modelContext) private var context

    @State private var showEdit = false
    @State private var showAddMatch = false
    @State private var confirmDelete = false

    private var sortedMatches: [Match] {
        tournament.matches.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(tournament.type.label, systemImage: tournament.type.symbol)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let placement = tournament.placement {
                            Text(placement.label)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }

                    HStack(spacing: 0) {
                        resultStat("\(tournament.wins)", label: "Wins", tint: .green)
                        resultStat("\(tournament.losses)", label: "Losses", tint: .red)
                        resultStat(
                            tournament.matches.isEmpty ? "–" : tournament.winRate.formatted(.percent),
                            label: "Win rate",
                            tint: .blue
                        )
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                ForEach(sortedMatches) { match in
                    NavigationLink(value: match) {
                        MatchRow(match: match)
                    }
                }
                .onDelete(perform: deleteMatch)
            } header: {
                Text("Matches")
            } footer: {
                Text("Matches you add here count toward the tournament record. Delete one here and it's gone — it isn't moved out.")
            }

            if let notes = tournament.strategyNotes, !notes.isEmpty {
                Section("Strategy") {
                    Text(notes)
                }
            }
        }
        .navigationTitle(tournament.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Edit") { showEdit = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showAddMatch = true
                    } label: {
                        Label("Add match", systemImage: "plus")
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Delete tournament", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            TournamentFormView(tournament: tournament)
        }
        .sheet(isPresented: $showAddMatch) {
            MatchFormView(presetTournament: tournament)
        }
        .confirmationDialog(
            "Delete this tournament?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete tournament", role: .destructive) {
                context.delete(tournament)
            }
        } message: {
            Text("Its matches stay in your match history but will no longer belong to a tournament.")
        }
    }

    private func resultStat(_ value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func deleteMatch(at offsets: IndexSet) {
        for index in offsets {
            context.delete(sortedMatches[index])
        }
    }
}
