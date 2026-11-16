import SwiftUI
import SwiftData

struct TournamentListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Tournament.startDate, order: .reverse) private var tournaments: [Tournament]

    @State private var showAdd = false

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
                } else {
                    List {
                        ForEach(tournaments) { tournament in
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
                Text("\(tournament.matches.count) matches")
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
