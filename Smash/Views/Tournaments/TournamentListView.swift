import SwiftUI
import SwiftData

struct TournamentListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                        message: "Track the tournaments you play with your placement and matches inside them."
                    )
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(filtered) { tournament in
                                NavigationLink(value: tournament) {
                                    TournamentCard(tournament: tournament)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        delete(tournament)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Tournaments")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Name, type, placement, notes…")
            .navigationDestination(for: Tournament.self) { tournament in
                TournamentDetailView(tournament: tournament)
            }
            // Match links on the tournament detail screen resolve here, on the
            // stack that owns both the list and the pushed detail screen.
            .navigationDestination(for: Match.self) { match in
                MatchDetailView(match: match)
            }
            .overlay(alignment: .bottomTrailing) {
                Button { showAdd = true } label: {
                    AddButtonLabel()
                        .accessibilityLabel("Add tournament")
                }
                .buttonStyle(PressableStyle())
                .padding(.trailing, 20)
                .padding(.bottom, 16)
            }
            .sheet(isPresented: $showAdd) {
                TournamentFormView()
            }
        }
    }

    private func delete(_ tournament: Tournament) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
            context.delete(tournament)
        }
    }
}

// MARK: - Tournament card

private struct TournamentCard: View {
    let tournament: Tournament

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: tournament.type.symbol)
                    .font(.title2)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tournament.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(tournament.type.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if let placement = tournament.placement {
                    Text(placement.label)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(SmashColor.warningText)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            Divider()

            HStack(alignment: .firstTextBaseline) {
                stat(value: "\(tournament.wins)-\(tournament.losses)", label: "W-L")
                Spacer()
                stat(value: "\(tournament.matchList.count)", label: "Matches")
                Spacer()
                stat(value: AppFormat.date(tournament.startDate), label: "Start")
            }
        }
        .cardStyle()
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    TournamentListView()
        .modelContainer(PreviewContainer.container)
}
