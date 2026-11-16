import SwiftUI
import SwiftData

struct PlayFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PlaySession.date, order: .reverse) private var sessions: [PlaySession]

    @State private var date = Date.now
    /// Duration in 15-minute steps.
    @State private var durationMinutes = 60
    @State private var discipline: Discipline = .singles
    @State private var intensity: Intensity? = .moderate
    @State private var location = ""
    @State private var opponentsText = ""
    @State private var notes = ""
    @State private var saved = false

    private let editing: PlaySession?

    init(session: PlaySession? = nil) {
        self.editing = session
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(AppFormat.duration(minutes: durationMinutes))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: Binding(
                                get: { Double(durationMinutes) },
                                set: { durationMinutes = Int(($0 / 15).rounded()) * 15 }
                            ),
                            in: 15...240,
                            step: 15
                        )
                        .sensoryFeedback(.selection, trigger: durationMinutes)
                    }
                }

                Section("Game type") {
                    Picker("Discipline", selection: $discipline) {
                        ForEach(Discipline.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Intensity", selection: Binding(
                        get: { intensity },
                        set: { intensity = $0 == intensity ? intensity : $0 }
                    )) {
                        Text("Not set").tag(Intensity?.none)
                        ForEach(Intensity.allCases) { Text($0.label).tag(Intensity?.some($0)) }
                    }
                }

                Section {
                    TextField("Court, club, park…", text: $location)
                } header: {
                    Text("Where")
                }

                Section {
                    TextField("Comma separated — Ravi, Anil", text: $opponentsText)
                        .textInputAutocapitalization(.words)
                    if !opponentChips.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(opponentChips, id: \.self) { name in
                                    Text(name)
                                        .font(.callout)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                                }
                            }
                        }
                    }
                    if !recentOpponents.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recentOpponents, id: \.self) { name in
                                    Button {
                                        appendOpponent(name)
                                    } label: {
                                        HStack(spacing: 3) {
                                            Image(systemName: "plus")
                                                .font(.caption2)
                                            Text(name)
                                                .font(.callout)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(.fill.tertiary, in: Capsule())
                                    }
                                    .buttonStyle(PressableStyle())
                                }
                            }
                        }
                    }
                } header: {
                    Text("Who did you play with?")
                }

                Section("Notes") {
                    TextField("How did it feel? Anything worth remembering?", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(editing == nil ? "Log play session" : "Edit session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .sensoryFeedback(.success, trigger: saved)
            .onAppear(perform: populate)
        }
    }

    // MARK: - Logic

    private var opponentChips: [String] {
        opponentsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var recentOpponents: [String] {
        PlaySession.allOpponents(from: sessions).prefix(6).map { $0 }
    }

    private func appendOpponent(_ name: String) {
        if opponentsText.trimmingCharacters(in: .whitespaces).isEmpty {
            opponentsText = name
        } else if !opponentChips.contains(name) {
            opponentsText += ", \(name)"
        }
    }

    private func populate() {
        guard let editing else { return }
        date = editing.date
        durationMinutes = editing.durationMinutes
        discipline = editing.discipline
        intensity = editing.intensity
        location = editing.location ?? ""
        opponentsText = editing.opponents.joined(separator: ", ")
        notes = editing.notes ?? ""
    }

    private func save() {
        let opponents = opponentChips
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)

        if let editing {
            editing.date = date
            editing.durationMinutes = durationMinutes
            editing.discipline = discipline
            editing.intensity = intensity
            editing.location = trimmedLocation.isEmpty ? nil : trimmedLocation
            editing.opponents = opponents
            editing.notes = notes.isEmpty ? nil : notes
        } else {
            context.insert(PlaySession(
                date: date,
                durationMinutes: durationMinutes,
                discipline: discipline,
                intensity: intensity,
                location: trimmedLocation.isEmpty ? nil : trimmedLocation,
                opponents: opponents,
                notes: notes.isEmpty ? nil : notes
            ))
        }
        saved = true
        dismiss()
    }
}
