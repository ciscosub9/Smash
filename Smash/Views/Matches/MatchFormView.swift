import SwiftUI
import SwiftData

struct MatchFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tournament.startDate, order: .reverse) private var tournaments: [Tournament]

    enum Field { case opponent }
    @FocusState private var focusedField: Field?

    // Form state
    @State private var opponent = ""
    @State private var date = Date.now
    @State private var discipline: Discipline = .singles
    @State private var pointSystem: PointSystem = .points21
    @State private var format: MatchFormat = .bestOf3
    @State private var myScores: [Int] = [0, 0, 0]
    @State private var opponentScores: [Int] = [0, 0, 0]
    @State private var selectedTournament: Tournament?
    @State private var notes = ""
    @State private var saved = false
    @State private var knownOpponents: [String] = []

    private let editing: Match?
    private let presetTournament: Tournament?

    /// Pass `match` to edit an existing match, or `presetTournament`
    /// when opening from inside a tournament.
    init(match: Match? = nil, presetTournament: Tournament? = nil) {
        self.editing = match
        self.presetTournament = presetTournament
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Opponent") {
                    TextField("Name", text: $opponent)
                        .focused($focusedField)
                        .textInputAutocapitalization(.words)
                    if !suggestedOpponents.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestedOpponents, id: \.self) { name in
                                    Button {
                                        opponent = name
                                    } label: {
                                        Text(name)
                                            .font(.callout)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(.fill.tertiary, in: Capsule())
                                    }
                                    .buttonStyle(PressableStyle())
                                }
                            }
                        }
                    }
                }

                Section {
                    Picker("Discipline", selection: $discipline) {
                        ForEach(Discipline.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Point system", selection: $pointSystem) {
                        ForEach(PointSystem.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Format", selection: $format) {
                        ForEach(MatchFormat.allCases) { Text($0.label).tag($0) }
                    }
                    Text(pointSystem.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Rules")
                }

                Section {
                    ForEach(0..<gameCount, id: \.self) { index in
                        GameScoreRow(
                            gameNumber: index + 1,
                            myScore: Binding(
                                get: { myScores[index] },
                                set: { myScores[index] = $0 }
                            ),
                            opponentScore: Binding(
                                get: { opponentScores[index] },
                                set: { opponentScores[index] = $0 }
                            )
                        )
                    }
                    HStack {
                        Spacer()
                        OutcomeBadge(outcome: liveOutcome)
                            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: liveOutcome)
                    }
                } header: {
                    Text("Score")
                } footer: {
                    Text(scoreFooter)
                }

                Section("Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Tournament", selection: $selectedTournament) {
                        Text("None").tag(Tournament?.none)
                        ForEach(tournaments) { tournament in
                            Text(tournament.name).tag(Tournament?.some(tournament))
                        }
                    }
                }

                Section("Notes") {
                    TextField("Strategy, what worked, what didn't…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(editing == nil ? "New match" : "Edit match")
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

    private var gameCount: Int { format.gameCount }

    private var isValid: Bool {
        !opponent.trimmingCharacters(in: .whitespaces).isEmpty && totalPointsEntered > 0
    }

    private var totalPointsEntered: Int {
        myScores.reduce(0, +) + opponentScores.reduce(0, +)
    }

    private var liveOutcome: MatchOutcome {
        MatchLogic.matchOutcome(
            myGameScores: Array(myScores.prefix(gameCount)),
            opponentGameScores: Array(opponentScores.prefix(gameCount)),
            format: format
        )
    }

    private var scoreFooter: String {
        switch format {
        case .singleGame:
            "Enter the final score of the single game."
        case .bestOf3:
            "Two game wins take the match. Leave the third game at 0 – 0 if it wasn't played."
        }
    }

    private var suggestedOpponents: [String] {
        knownOpponents
            .filter { $0.localizedCaseInsensitiveCompare(opponent) != .orderedSame }
            .prefix(6)
            .map { $0 }
    }

    private func populate() {
        let allMatches = (try? context.fetch(FetchDescriptor<Match>())) ?? []
        knownOpponents = Array(Set(allMatches.map(\.opponent)).filter { !$0.isEmpty }).sorted()

        if let editing {
            opponent = editing.opponent
            date = editing.date
            discipline = editing.discipline
            pointSystem = editing.pointSystem
            format = editing.format
            var mine = editing.myGameScores
            var theirs = editing.opponentGameScores
            while mine.count < 3 { mine.append(0) }
            while theirs.count < 3 { theirs.append(0) }
            myScores = mine
            opponentScores = theirs
            selectedTournament = editing.tournament
            notes = editing.notes ?? ""
        } else if let presetTournament {
            selectedTournament = presetTournament
        }
    }

    private func save() {
        let games = gameCount
        let myGames = Array(myScores.prefix(games))
        let oppGames = Array(opponentScores.prefix(games))
        let name = opponent.trimmingCharacters(in: .whitespaces)

        if let editing {
            editing.opponent = name
            editing.date = date
            editing.discipline = discipline
            editing.pointSystem = pointSystem
            editing.format = format
            editing.myGameScores = myGames
            editing.opponentGameScores = oppGames
            editing.notes = notes.isEmpty ? nil : notes
            editing.tournament = selectedTournament
        } else {
            context.insert(Match(
                date: date,
                opponent: name,
                discipline: discipline,
                pointSystem: pointSystem,
                format: format,
                myGameScores: myGames,
                opponentGameScores: oppGames,
                notes: notes.isEmpty ? nil : notes,
                tournament: selectedTournament
            ))
        }
        saved = true
        dismiss()
    }
}

// MARK: - Game score row

private struct GameScoreRow: View {
    let gameNumber: Int
    @Binding var myScore: Int
    @Binding var opponentScore: Int

    var body: some View {
        HStack {
            Text("Game \(gameNumber)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            ScoreStepper(label: "You", score: $myScore, tint: .green)
            ScoreStepper(label: "Them", score: $opponentScore, tint: .red)
        }
    }
}

/// Big tappable minus/plus flanking the score — feedback lands on press-down,
/// the haptic fires on the same frame as the number changes.
struct ScoreStepper: View {
    let label: String
    @Binding var score: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button {
                score = max(0, score - 1)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Subtract point from \(label)")

            Text("\(score)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(minWidth: 28)

            Button {
                score += 1
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(tint)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Add point to \(label)")
        }
        .sensoryFeedback(.selection, trigger: score)
        .accessibilityElement(children: .contain)
        .accessibilityValue("\(label) \(score)")
    }
}
