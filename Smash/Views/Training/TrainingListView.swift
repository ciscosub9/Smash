import SwiftUI
import SwiftData

struct TrainingListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TrainingSession.date, order: .reverse) private var sessions: [TrainingSession]

    @State private var showAdd = false

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
                } else {
                    List {
                        ForEach(sessions) { session in
                            TrainingRow(session: session)
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Training")
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
            context.delete(sessions[index])
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
                Text(AppFormat.date(session.date))
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
