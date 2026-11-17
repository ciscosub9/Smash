import SwiftUI
import SwiftData

struct TrainingFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TrainingSession.date, order: .reverse) private var sessions: [TrainingSession]

    @State private var date = Date.now
    @State private var durationMinutes = 60
    @State private var coach = ""
    @State private var selectedFocus: Set<String> = []
    @State private var drillsDescription = ""
    @State private var drillSelection = ""
    @State private var customDrill = ""
    @State private var setsDone = 1
    @State private var intensity: Intensity?
    @State private var notes = ""
    @State private var saved = false

    private let editing: TrainingSession?

    init(session: TrainingSession? = nil) {
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
                    TextField("Coach", text: $coach)
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
                    Picker("Drill", selection: $drillSelection) {
                        Text("None").tag("")
                        ForEach(BadmintonDrill.presets, id: \.self) { preset in
                            Text(preset).tag(preset)
                        }
                        Text("Custom…").tag(Self.customDrillSentinel)
                    }
                    if drillSelection == Self.customDrillSentinel {
                        TextField("Drill name", text: $customDrill)
                    }
                    if isDrillSelected {
                        Stepper("Sets done: \(setsDone)", value: $setsDone, in: 1...50)
                            .sensoryFeedback(.selection, trigger: setsDone)
                    }
                    Picker("Difficulty", selection: $intensity) {
                        Text("Not set").tag(Intensity?.none)
                        ForEach(Intensity.allCases) { level in
                            Text(level.label).tag(Intensity?.some(level))
                        }
                    }
                } header: {
                    Text("Drills")
                } footer: {
                    Text("The main drill of the session and how many sets you completed.")
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
    }

    // MARK: - Logic

    /// Sentinel picker value for "type your own drill".
    private static let customDrillSentinel = "__custom__"

    private var isDrillSelected: Bool { drillSelection != "" }

    /// The drill name to persist — preset, custom text, or nothing.
    private var resolvedDrillName: String? {
        if drillSelection.isEmpty { return nil }
        if drillSelection == Self.customDrillSentinel {
            let trimmed = customDrill.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        return drillSelection
    }

    private var isValid: Bool {
        !selectedFocus.isEmpty || !drillsDescription.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var recentCoaches: [String] {
        Array(Set(sessions.compactMap(\.coach))).filter { !$0.isEmpty }.sorted().prefix(4).map { $0 }
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
        coach = editing.coach ?? ""
        selectedFocus = Set(editing.focusAreas)
        drillsDescription = editing.drillsDescription
        if let name = editing.drillName, !name.isEmpty {
            if BadmintonDrill.presets.contains(name) {
                drillSelection = name
            } else {
                drillSelection = Self.customDrillSentinel
                customDrill = name
            }
            setsDone = editing.setsDone ?? 1
        } else {
            drillSelection = ""
        }
        intensity = editing.intensity
        notes = editing.notes ?? ""
    }

    private func save() {
        let coachName = coach.trimmingCharacters(in: .whitespaces)
        let drills = drillsDescription.trimmingCharacters(in: .whitespaces)
        let drillName = resolvedDrillName

        if let editing {
            editing.date = date
            editing.durationMinutes = durationMinutes
            editing.coach = coachName.isEmpty ? nil : coachName
            editing.focusAreas = Array(selectedFocus).sorted()
            editing.drillsDescription = drills
            editing.drillName = drillName
            editing.setsDone = drillName == nil ? nil : setsDone
            editing.intensity = intensity
            editing.notes = notes.isEmpty ? nil : notes
        } else {
            context.insert(TrainingSession(
                date: date,
                durationMinutes: durationMinutes,
                coach: coachName.isEmpty ? nil : coachName,
                focusAreas: Array(selectedFocus).sorted(),
                drillsDescription: drills,
                drillName: drillName,
                setsDone: drillName == nil ? nil : setsDone,
                intensity: intensity,
                notes: notes.isEmpty ? nil : notes
            ))
        }
        saved = true
        dismiss()
    }
}
