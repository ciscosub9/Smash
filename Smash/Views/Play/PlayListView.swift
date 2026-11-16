import SwiftUI
import SwiftData

struct PlayListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PlaySession.date, order: .reverse) private var sessions: [PlaySession]

    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    EmptyStateView(
                        symbol: "figure.play",
                        title: "No play sessions",
                        message: "Track your daily badminton — hours on court, who you played with, how it felt.",
                        actionTitle: "Log session"
                    ) { showAdd = true }
                } else {
                    List {
                        ForEach(sessions) { session in
                            PlayRow(session: session)
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Play")
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
                PlayFormView()
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(sessions[index])
        }
    }
}

private struct PlayRow: View {
    let session: PlaySession

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
            HStack(spacing: 8) {
                Label(session.discipline.label, systemImage: session.discipline.symbol)
                if let intensity = session.intensity {
                    Text(intensity.label)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(intensityTint.opacity(0.15), in: Capsule())
                        .foregroundStyle(intensityTint)
                }
                Spacer()
                if !session.opponents.isEmpty {
                    Text(session.opponents.prefix(2).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var intensityTint: Color {
        switch session.intensity {
        case .easy: .green
        case .moderate: .orange
        case .hard: .red
        case nil: .gray
        }
    }
}

#Preview {
    PlayListView()
        .modelContainer(PreviewContainer.container)
}
