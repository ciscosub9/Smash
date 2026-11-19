import SwiftUI
import SwiftData

struct MatchListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Match.date, order: .reverse) private var matches: [Match]

    @State private var filter: PointSystem?
    @State private var showAdd = false
    @State private var searchText = ""

    private var filtered: [Match] {
        var result = matches
        if let filter { result = result.filter { $0.pointSystem == filter } }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return result }
        return result.filter { match in
            match.opponent.localizedCaseInsensitiveContains(query)
            || match.notes?.localizedCaseInsensitiveContains(query) == true
            || match.tournament?.name.localizedCaseInsensitiveContains(query) == true
            || match.discipline.label.localizedCaseInsensitiveContains(query)
            || match.intensity?.label.localizedCaseInsensitiveContains(query) == true
            || match.opponentLevel?.label.localizedCaseInsensitiveContains(query) == true
        }
    }

    private var opponentRecords: [Record] {
        Stats.recordsByOpponent(matches)
    }

    private var pointSystemRecords: [Record] {
        PointSystem.allCases.map { Stats.record(for: $0, in: matches) }.filter { $0.total > 0 }
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
                        if !opponentRecords.isEmpty || !pointSystemRecords.isEmpty {
                            Section("Your record") {
                                if !opponentRecords.isEmpty {
                                    DisclosureGroup("By opponent") {
                                        ForEach(opponentRecords) { record in
                                            RecordRow(record: record)
                                        }
                                    }
                                }
                                if !pointSystemRecords.isEmpty {
                                    DisclosureGroup("By point system") {
                                        ForEach(pointSystemRecords) { record in
                                            RecordRow(record: record)
                                        }
                                    }
                                }
                            }
                        }

                        Section("All matches") {
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
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Matches")
            .searchable(text: $searchText, prompt: "Opponent, notes, tournament…")
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
                Text(AppFormat.dateTime(match.date))
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

// MARK: - Records

private struct RecordRow: View {
    let record: Record

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.label)
                    .font(.subheadline.weight(.medium))
                Text("\(record.wins)W · \(record.losses)L\(record.draws > 0 ? " · \(record.draws)D" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(record.winRate.formatted(.percent.precision(.fractionLength(0))))
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(record.winRate >= 0.5 ? .green : .orange)
                .monospacedDigit()
        }
    }
}
