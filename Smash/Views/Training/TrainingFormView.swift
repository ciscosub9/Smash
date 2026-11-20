import SwiftUI
import SwiftData

struct TrainingFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date.now
    @State private var durationMinutes = 60
    @State private var selectedFocus: Set<String> = []
    @State private var drillsDescription = ""
    @State private var drills: [TrainingDrillEntry] = [TrainingDrillEntry(name: "")]
    @State private var notes = ""
    @State private var saved = false

    private let editing: TrainingSession?
    var embedded: Bool
    var onSaved: (() -> Void)?

    init(session: TrainingSession? = nil, embedded: Bool = false, onSaved: (() -> Void)? = nil) {
        self.editing = session
        self.embedded = embedded
        self.onSaved = onSaved
    }

    var body: some View {
        Group {
            if embedded {
                formContent
            } else {
                NavigationStack { formContent }
            }
        }
    }

    private var formContent: some View {
        Form {
            Section {
                DateTimeEntry(date: $date)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(AppFormat.duration(minutes: durationMinutes))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    DurationPicker(totalMinutes: $durationMinutes)
                }
            }

            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TrainingFocus.allCases) { focus in
                            Button {
                                toggleFocus(focus.label)
                            } label: {
                                Text(focus.label)
                                    .font(.callout)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        selectedFocus.contains(focus.label)
                                            ? Color.blue.opacity(0.2)
                                            : Color(.tertiarySystemFill),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(selectedFocus.contains(focus.label) ? .blue : .primary)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
            } header: {
                Text("Focus areas")
            } footer: {
                Text("Tap everything you worked on.")
            }

            Section {
                ForEach(drills.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Drill \(index + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("Drill", selection: $drills[index].name) {
                            Text("Choose a drill").tag("")
                            ForEach(BadmintonDrillLibrary.presets, id: \.self) { preset in
                                Text(preset).tag(preset)
                            }
                            Text("Custom…").tag(TrainingDrillEntry.customSentinel)
                        }
                        .pickerStyle(.menu)

                        if drills[index].name == TrainingDrillEntry.customSentinel {
                            TextField("Drill name", text: $drills[index].customName)
                                .textInputAutocapitalization(.words)
                        }

                        Picker("Sets done", selection: $drills[index].sets) {
                            ForEach(1...50, id: \.self) { count in
                                Text("\(count) sets").tag(count)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Difficulty", selection: $drills[index].intensity) {
                            Text("Not set").tag(Intensity?.none)
                            ForEach(Intensity.allCases) { level in
                                Text(level.label).tag(Intensity?.some(level))
                            }
                        }
                        .pickerStyle(.menu)

                        if drills.count > 1 {
                            Button(role: .destructive) {
                                drills.remove(at: index)
                            } label: {
                                Label("Remove drill", systemImage: "minus.circle")
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Button {
                    drills.append(TrainingDrillEntry(name: ""))
                } label: {
                    Label("Add more", systemImage: "plus.circle")
                }
            } header: {
                Text("Drills")
            } footer: {
                Text("Every drill keeps its own sets done and difficulty. Use Add more to add the next one.")
            }

            Section {
                TextField("e.g. Shadow footwork 3×10, half-court smash rallies, net kills…", text: $drillsDescription, axis: .vertical)
                    .lineLimit(3...8)
            } header: {
                Text("What was done")
            }

            Section("Notes") {
                TextField("How did it feel? What to repeat next time?", text: $notes, axis: .vertical)
                    .lineLimit(2...5)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(editing == nil ? "Log training" : "Edit session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
            }
        }
        .sensoryFeedback(.success, trigger: saved)
        .onAppear(perform: populate)
    }

    // MARK: - Logic

    /// Only complete drills are saved: an empty slot or an untyped custom name
    /// is ignored so the card can stay open for as long as the player needs.
    private var resolvedDrills: [TrainingDrillEntry] {
        drills.compactMap { entry in
            var resolved = entry
            if entry.name == TrainingDrillEntry.customSentinel {
                let name = entry.customName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return nil }
                resolved.name = name
            } else if entry.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return nil
            }
            return resolved
        }
    }

    private var isValid: Bool {
        !selectedFocus.isEmpty
            || !drillsDescription.trimmingCharacters(in: .whitespaces).isEmpty
            || !resolvedDrills.isEmpty
    }

    private func toggleFocus(_ label: String) {
        if selectedFocus.contains(label) {
            selectedFocus.remove(label)
        } else {
            selectedFocus.insert(label)
        }
    }

    private func populate() {
        guard let editing else { return }
        date = editing.date
        durationMinutes = editing.durationMinutes
        selectedFocus = Set(editing.focusAreas)
        drillsDescription = editing.drillsDescription
        notes = editing.notes ?? ""

        let stored = editing.drillEntries.map { entry -> TrainingDrillEntry in
            var result = entry
            if !BadmintonDrillLibrary.presets.contains(entry.name) {
                result.customName = entry.name
                result.name = TrainingDrillEntry.customSentinel
            }
            return result
        }
        drills = stored.isEmpty ? [TrainingDrillEntry(name: "")] : stored
    }

    private func save() {
        let entries = resolvedDrills
        let description = drillsDescription.trimmingCharacters(in: .whitespaces)
        let names = entries.map(\.name)
        let sets = entries.map(\.sets)
        let intensities = entries.map { $0.intensity?.rawValue ?? "" }

        if let editing {
            editing.date = date
            editing.durationMinutes = durationMinutes
            editing.focusAreas = Array(selectedFocus).sorted()
            editing.drillsDescription = description
            editing.drillNames = names
            editing.drillSets = sets
            editing.drillIntensities = intensities
            editing.setsDone = sets.first
            editing.intensity = entries.first?.intensity
            editing.notes = notes.isEmpty ? nil : notes
        } else {
            context.insert(TrainingSession(
                date: date,
                durationMinutes: durationMinutes,
                focusAreas: Array(selectedFocus).sorted(),
                drillsDescription: description,
                drillNames: names,
                drillSets: sets,
                drillIntensities: intensities,
                setsDone: sets.first,
                intensity: entries.first?.intensity,
                notes: notes.isEmpty ? nil : notes
            ))
        }
        saved = true
        if let onSaved {
            onSaved()
        } else {
            dismiss()
        }
    }
}
