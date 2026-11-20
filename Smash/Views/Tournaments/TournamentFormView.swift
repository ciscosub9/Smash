import SwiftUI
import SwiftData

struct TournamentFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: TournamentType = .roundRobin
    @State private var startDate = Date.now
    @State private var hasEndDate = false
    @State private var endDate = Date.now
    @State private var placement: Placement?
    @State private var strategyNotes = ""
    @State private var saved = false
    @State private var isSaving = false
    @State private var didPopulate = false

    private let editing: Tournament?

    init(tournament: Tournament? = nil) {
        self.editing = tournament
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Club Open 2026", text: $name)
                } header: {
                    Text("Name")
                }

                Section {
                    Picker("Type", selection: $type) {
                        ForEach(TournamentType.allCases) { Text($0.label).tag($0) }
                    }
                } header: {
                    Text("Format")
                } footer: {
                    Text(typeSummary)
                }

                Section {
                    DatePicker("Starts", selection: $startDate, in: ...Date.now, displayedComponents: .date)
                    Toggle("Multi-day", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("Ends", selection: $endDate, in: startDate...Date.now, displayedComponents: .date)
                    }
                } header: {
                    Text("Dates")
                }

                Section {
                    Picker("Placement", selection: $placement) {
                        Text("Not placed yet").tag(Placement?.none)
                        ForEach(Placement.allCases) { Text($0.label).tag(Placement?.some($0)) }
                    }
                } header: {
                    Text("Result")
                }

                Section {
                    TextField("Game plans, tactics against specific opponents, lessons…", text: $strategyNotes, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("Strategy notes")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(editing == nil ? "New tournament" : "Edit tournament")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid || isSaving)
                        .fontWeight(.semibold)
                }
            }
            .sensoryFeedback(.success, trigger: saved)
            .onAppear(perform: populate)
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var typeSummary: String {
        switch type {
        case .roundRobin:
            "Everyone plays everyone — the most wins takes the title."
        case .knockout:
            "Lose once and you're out."
        case .league:
            "Season-long play across multiple meetups."
        case .ladder:
            "Challenge players above you to climb the ranks."
        case .other:
            "Anything with its own format."
        }
    }

    private func populate() {
        guard let editing, !didPopulate else { return }
        didPopulate = true
        name = editing.name
        type = editing.type
        // Imported records can hold future or reversed dates; normalise them
        // before they reach a constrained DatePicker.
        let today = Date.now
        startDate = min(editing.startDate, today)
        if let end = editing.endDate {
            hasEndDate = true
            endDate = min(max(end, startDate), today)
        }
        placement = editing.placement
        strategyNotes = editing.strategyNotes ?? ""
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let start = min(startDate, Date.now)
        let end = hasEndDate ? min(max(endDate, start), Date.now) : nil

        if let editing {
            editing.name = trimmedName
            editing.type = type
            editing.startDate = start
            editing.endDate = end
            editing.placement = placement
            editing.strategyNotes = strategyNotes.isEmpty ? nil : strategyNotes
        } else {
            context.insert(Tournament(
                name: trimmedName,
                type: type,
                startDate: start,
                endDate: end,
                placement: placement,
                strategyNotes: strategyNotes.isEmpty ? nil : strategyNotes
            ))
        }
        saved = true
        dismiss()
    }
}
