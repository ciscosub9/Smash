import SwiftUI
import SwiftData

struct MatchListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Match.date, order: .reverse) private var matches: [Match]

    @State private var filter: PointSystem?
    @State private var showAdd = false

    private var filtered: [Match] {
        guard let filter else { return matches }
        return matches.filter { $0.pointSystem == filter }
    }

    var body: some View {
        NavigationStack {
            Group {
                if matches.isEmpty {
                    EmptyStateView(
                        symbol: "trophy",
                        title: "No matches yet",
                        message: "Record your matches to start building your win rate and spotting patterns against opponents.",
                        actionTitle: "Add match"
                    ) { showAdd = true }
                } else {
                    List {
                        ForEach(filtered) { match in
                            NavigationLink(value: match) {
                                MatchRow(match: match)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(match)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Matches")
            .navigationDestination(for: Match.self) { match in
                MatchDetailView(match: match)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    filterMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                MatchFormView()
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Button("All point systems") { filter = nil }
            ForEach(PointSystem.allCases) { system in
                Button(system.label) { filter = system }
            }
        } label: {
            Image(systemName: filter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
    }
}

// MARK: - Row

struct MatchRow: View {
    let match: Match

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("vs \(match.opponent)")
                    .font(.headline)
                Spacer()
                OutcomeBadge(outcome: MatchLogic.outcome(match))
            }
            HStack(spacing: 8) {
                Text(scoreSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text(match.pointSystem.label)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.fill.tertiary, in: Capsule())
                if match.tournament != nil {
                    Image(systemName: "medal")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text(AppFormat.date(match.date))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var scoreSummary: String {
        zip(match.myGameScores, match.opponentGameScores)
            .map { "\($0)-\($1)" }
            .joined(separator: "  ")
    }
}

#Preview {
    MatchListView()
        .modelContainer(PreviewContainer.container)
}
