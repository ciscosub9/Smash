import SwiftUI
import SwiftData

struct TrainingListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TrainingSession.date, order: .reverse) private var sessions: [TrainingSession]

    @State private var showAdd = false
    @State private var searchText = ""

    private var filtered: [TrainingSession] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sessions }
        return sessions.filter { session in
            session.coach?.localizedCaseInsensitiveContains(query) == true
            || session.focusAreas.contains(where: { $0.localizedCaseInsensitiveContains(query) })
            || session.drillsDescription.localizedCaseInsensitiveContains(query)
            || session.drillName?.localizedCaseInsensitiveContains(query) == true
            || session.notes?.localizedCaseInsensitiveContains(query) == true
            || session.intensity?.label.localizedCaseInsensitiveContains(query) == true
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    EmptyStateView(
                        symbol: "dumbbell",
                        title: "No training sessions",
                        message: "Log coaching and drills — footwork, clears, smashes — and see what you've been working on.",
                        actionTitle: "Log training"
                    ) { showAdd = true }
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(filtered) { session in
                            TrainingRow(session: session)
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Training")
            .searchable(text: $searchText, prompt: "Coach, drill, focus, notes…")
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
                TrainingFormView()
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filtered[index])
        }
    }
}

private struct TrainingRow: View {
    let session: TrainingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(AppFormat.duration(minutes: session.durationMinutes), systemImage: "clock")
                    .font(.headline)
                Spacer()
                Text(AppFormat.dateTime(session.date))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if !session.focusAreas.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(session.focusAreas, id: \.self) { focus in
                            Text(focus)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.12), in: Capsule())
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            if let coach = session.coach, !coach.isEmpty {
                Text("with \(coach)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !session.drillsDescription.isEmpty {
                Text(session.drillsDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    TrainingListView()
        .modelContainer(PreviewContainer.container)
}
