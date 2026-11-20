import SwiftUI

/// Which form opens after picking a session type.
enum LogFlow: Identifiable, Hashable {
    case play(Discipline)
    case training

    var id: String {
        switch self {
        case .play(let discipline): "play-\(discipline.rawValue)"
        case .training: "training"
        }
    }
}

/// Full page behind the plus button. Pick a type and the form opens straight
/// away, with no extra card in between.
struct SessionLogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var choice: Choice?
    @State private var flow: LogFlow?

    private enum Choice: String, CaseIterable {
        case singles, doubles, training

        var label: String {
            switch self {
            case .singles: "Singles"
            case .doubles: "Doubles"
            case .training: "Training"
            }
        }

        var symbol: String {
            switch self {
            case .singles: "figure.stand"
            case .doubles: "person.2"
            case .training: "dumbbell"
            }
        }

        var tint: Color {
            switch self {
            case .singles: .blue
            case .doubles: .purple
            case .training: SmashColor.training
            }
        }

        var flow: LogFlow {
            switch self {
            case .singles: .play(.singles)
            case .doubles: .play(.doubles)
            case .training: .training
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What are you logging?")
                            .font(.headline)
                        HStack(spacing: 10) {
                            ForEach(Choice.allCases, id: \.self) { item in
                                Button {
                                    choice = item
                                    flow = item.flow
                                } label: {
                                    tile(for: item, selected: choice == item)
                                }
                                .buttonStyle(PressableStyle())
                                .sensoryFeedback(.selection, trigger: choice == item)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Log a session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(item: $flow) { flow in
                switch flow {
                case .play(let discipline):
                    PlayFormView(presetDiscipline: discipline, embedded: true) { dismiss() }
                case .training:
                    TrainingFormView(embedded: true) { dismiss() }
                }
            }
        }
    }

    private func tile(for item: Choice, selected: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: item.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(item.tint)
            Text(item.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            selected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: SmashRadius.tile)
        )
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: SmashRadius.tile)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: SmashRadius.tile))
    }
}

#Preview {
    SessionLogView()
}
