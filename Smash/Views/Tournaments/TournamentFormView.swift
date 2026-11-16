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
                    DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                    Toggle("Multi-day", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("Ends", selection: $endDate, in: startDate..., displayedComponents: .date)
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
                        .disabled(!isValid)
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
            "Everyone plays everyone — most wins takes the title."
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
        guard let editing else { return }
        name = editing.name
        type = editing.type
        startDate = editing.startDate
        if let end = editing.endDate {
            hasEndDate = true
            endDate = end
        }
        placement = editing.placement
        strategyNotes = editing.strategyNotes ?? ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if let editing {
            editing.name = trimmedName
            editing.type = type
            editing.startDate = startDate
            editing.endDate = hasEndDate ? endDate : nil
            editing.placement = placement
            editing.strategyNotes = strategyNotes.isEmpty ? nil : strategyNotes
        } else {
            context.insert(Tournament(
                name: trimmedName,
                type: type,
                startDate: startDate,
                endDate: hasEndDate ? endDate : nil,
                placement: placement,
                strategyNotes: strategyNotes.isEmpty ? nil : strategyNotes
            ))
        }
        saved = true
        dismiss()
    }
}
