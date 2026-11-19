import SwiftUI
import SwiftData

struct TournamentListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Tournament.startDate, order: .reverse) private var tournaments: [Tournament]

    @State private var showAdd = false
    @State private var searchText = ""

    private var filtered: [Tournament] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return tournaments }
        return tournaments.filter { tournament in
            tournament.name.localizedCaseInsensitiveContains(query)
            || tournament.strategyNotes?.localizedCaseInsensitiveContains(query) == true
            || tournament.type.label.localizedCaseInsensitiveContains(query)
            || tournament.placement?.label.localizedCaseInsensitiveContains(query) == true
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if tournaments.isEmpty {
                    EmptyStateView(
                        symbol: "medal",
                        title: "No tournaments yet",
                        message: "Track the tournaments you play — round robin, knockout — with your placement and the matches inside them.",
                        actionTitle: "Add tournament"
                    ) { showAdd = true }
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(filtered) { tournament in
                            NavigationLink(value: tournament) {
                                TournamentRow(tournament: tournament)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(tournament)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Tournaments")
            .searchable(text: $searchText, prompt: "Name, type, placement, notes…")
            .navigationDestination(for: Tournament.self) { tournament in
                TournamentDetailView(tournament: tournament)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                TournamentFormView()
            }
        }
    }
}

private struct TournamentRow: View {
    let tournament: Tournament

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(tournament.name, systemImage: tournament.type.symbol)
                    .font(.headline)
                Spacer()
                if let placement = tournament.placement {
                    Text(placement.label)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }
            HStack {
                Text(tournament.type.label)
                Text("·")
                Text("\(tournament.wins)W – \(tournament.losses)L")
                    .monospacedDigit()
                Text("·")
                Text("\(tournament.matchList.count) matches")
                Spacer()
                Text(AppFormat.date(tournament.startDate))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    TournamentListView()
        .modelContainer(PreviewContainer.container)
}
