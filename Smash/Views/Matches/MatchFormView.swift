import SwiftUI
import SwiftData

struct MatchFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tournament.startDate, order: .reverse) private var tournaments: [Tournament]
    @Query(sort: \Player.name) private var savedPlayers: [Player]

    @FocusState private var nameFocused: Bool

    // Form state
    @State private var opponent = ""
    @State private var partner = ""
    @State private var date = Date.now
    @State private var discipline: Discipline = .singles
    @State private var pointSystem: PointSystem = .points21
    @State private var format: MatchFormat = .bestOf3
    @State private var gameCount = 3
    @State private var myScores: [Int] = [0, 0, 0]
    @State private var opponentScores: [Int] = [0, 0, 0]
    @State private var selectedTournament: Tournament?
    @State private var opponentLevel: SkillLevel?
    @State private var intensity: Intensity?
    @State private var notes = ""
    @State private var saved = false
    @State private var showValidation = false
    @State private var validationText = ""
    @State private var knownOpponents: [String] = []
    @State private var knownPartners: [String] = []
    /// Population happens once per editing target so a re-appear can't undo
    /// edits the player has already made.
    @State private var didPopulate = false
    /// Blocks a second Save tap while the first one is writing to the context.
    @State private var isSaving = false

    private let editing: Match?
    private let presetTournament: Tournament?
    private let presetDiscipline: Discipline?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Pass `match` to edit an existing match. `presetTournament` comes from
    /// a tournament screen; `presetDiscipline` comes from the Sessions add menu.
    init(match: Match? = nil, presetTournament: Tournament? = nil, presetDiscipline: Discipline? = nil) {
        self.editing = match
        self.presetTournament = presetTournament
        self.presetDiscipline = presetDiscipline
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Opponent") {
                    TextField("Name", text: $opponent)
                        .focused($nameFocused)
                        .textInputAutocapitalization(.words)
                    if !savedPlayers.isEmpty {
                        Menu {
                            ForEach(savedPlayers) { player in
                                Button {
                                    opponent = player.name
                                    opponentLevel = player.level
                                } label: {
                                    Label(player.name, systemImage: "person")
                                }
                            }
                        } label: {
                            Label("Choose a saved player", systemImage: "person.2")
                        }
                    }
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
                    Picker("Level", selection: $opponentLevel) {
                        Text("Not set").tag(SkillLevel?.none)
                        ForEach(SkillLevel.allCases) { level in
                            Text(level.label).tag(SkillLevel?.some(level))
                        }
                    }
                }

                if discipline != .singles {
                    Section("Partner") {
                        TextField("Partner", text: $partner)
                            .textInputAutocapitalization(.words)
                        if !savedPlayers.isEmpty {
                            Menu {
                                ForEach(savedPlayers) { player in
                                    Button { partner = player.name } label: {
                                        Label(player.name, systemImage: "person.2")
                                    }
                                }
                            } label: {
                                Label("Choose a saved player", systemImage: "person.2")
                            }
                        }
                        if !suggestedPartners.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(suggestedPartners, id: \.self) { name in
                                        Button {
                                            partner = name
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
                        Text("Adding a partner unlocks pairing insights in Coach's Corner.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Picker("Discipline", selection: $discipline) {
                        ForEach(Discipline.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Point system", selection: $pointSystem) {
                        // Include continuous so a stored continuous score can be
                        // edited without being rewritten as 21-point rules.
                        ForEach(PointSystem.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Format", selection: Binding(
                        get: { format },
                        set: { newValue in
                            // Reset the game count only on a genuine user choice.
                            // populate() assigns `format` directly, bypassing this
                            // binding, so variable-length continuous games survive.
                            guard newValue != format else { return }
                            format = newValue
                            setFormat(newValue)
                        }
                    )) {
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
                            ),
                            maximum: pointSystem.capPoints ?? 999
                        )
                    }
                    if format == .singleGame {
                        HStack {
                            Button { removeGame() } label: {
                                Label("Remove game", systemImage: "minus.circle")
                            }
                            .disabled(gameCount <= 1)
                            Spacer()
                            Button { addGame() } label: {
                                Label("Add game", systemImage: "plus.circle")
                            }
                            .disabled(gameCount >= 20)
                        }
                    }
                    HStack {
                        Spacer()
                        OutcomeBadge(outcome: liveOutcome)
                            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: liveOutcome)
                    }
                } header: {
                    Text("Score")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scoreFooter)
                        if let scoreMessage {
                            Label(scoreMessage, systemImage: "exclamationmark.circle")
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.footnote)
                }

                Section("Details") {
                    // DateTimeEntry is shared, so cap at its binding: a typo'd
                    // future date can't be selected, and attemptSave checks too.
                    DateTimeEntry(date: Binding(
                        get: { date },
                        set: { newDate in date = min(newDate, Date.now) }
                    ))
                    Picker("Tournament", selection: $selectedTournament) {
                        Text("None").tag(Tournament?.none)
                        ForEach(tournaments) { tournament in
                            Text(tournament.name).tag(Tournament?.some(tournament))
                        }
                    }
                    Picker("Intensity", selection: $intensity) {
                        Text("Not set").tag(Intensity?.none)
                        ForEach(Intensity.allCases) { level in
                            Text(level.label).tag(Intensity?.some(level))
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
                    Button("Save") { attemptSave() }
                        .fontWeight(.semibold)
                        .disabled(isSaving)
                }
            }
            .alert("Check the match", isPresented: $showValidation) {
                Button("Fix it", role: .cancel) {}
            } message: {
                Text(validationText)
            }
            .sensoryFeedback(.success, trigger: saved)
            .onAppear {
                populate()
                if editing == nil { nameFocused = true }
            }
        }
    }

    // MARK: - Logic

    private func setFormat(_ newValue: MatchFormat) {
        gameCount = newValue == .bestOf3 ? 3 : 1
        let target = max(3, gameCount)
        while myScores.count < target { myScores.append(0) }
        while opponentScores.count < target { opponentScores.append(0) }
    }

    private func addGame() {
        guard gameCount < 20 else { return }
        gameCount += 1
        myScores.append(0)
        opponentScores.append(0)
    }

    private func removeGame() {
        guard gameCount > 1 else { return }
        gameCount -= 1
        if myScores.count > gameCount { myScores.removeLast() }
        if opponentScores.count > gameCount { opponentScores.removeLast() }
    }

    private func attemptSave() {
        guard !isSaving else { return }
        var issues: [String] = []
        if opponent.trimmingCharacters(in: .whitespaces).isEmpty {
            issues.append("Add an opponent before saving.")
        }
        if date > Date.now {
            issues.append("Date can't be in the future.")
        }
        if let scoreMessage {
            issues.append(scoreMessage)
        }
        guard issues.isEmpty else {
            validationText = issues.joined(separator: "\n\n")
            showValidation = true
            return
        }
        isSaving = true
        save()
    }

    private var scoreMessage: String? {
        MatchLogic.validationMessage(
            myGameScores: Array(myScores.prefix(gameCount)),
            opponentGameScores: Array(opponentScores.prefix(gameCount)),
            format: format,
            pointSystem: pointSystem,
            gameCount: gameCount
        )
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
            "Add as many games as you played. Each one needs a final score."
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

    private var suggestedPartners: [String] {
        knownPartners
            .filter { $0.localizedCaseInsensitiveCompare(partner) != .orderedSame }
            .prefix(6)
            .map { $0 }
    }

    private func populate() {
        guard !didPopulate else { return }
        didPopulate = true

        let allMatches = (try? context.fetch(FetchDescriptor<Match>())) ?? []
        knownOpponents = Array(Set(allMatches.map(\.opponent)).filter { !$0.isEmpty }).sorted()
        knownPartners = Array(Set(allMatches.map(\.partner)).filter { !$0.isEmpty }).sorted()

        if let editing {
            opponent = editing.opponent
            partner = editing.partner
            date = editing.date
            discipline = editing.discipline
            // A stored continuous score has no cap; keep the system as-is.
            pointSystem = editing.pointSystem
            format = editing.format
            gameCount = editing.gameCount
            var mine = editing.myGameScores
            var theirs = editing.opponentGameScores
            let target = max(3, gameCount)
            while mine.count < target { mine.append(0) }
            while theirs.count < target { theirs.append(0) }
            myScores = mine
            opponentScores = theirs
            selectedTournament = editing.tournament
            opponentLevel = editing.opponentLevel
            intensity = editing.intensity
            notes = editing.notes ?? ""
        } else if let presetTournament {
            selectedTournament = presetTournament
            if let presetDiscipline { discipline = presetDiscipline }
        } else if let presetDiscipline {
            discipline = presetDiscipline
        }
    }

    private func save() {
        let games = gameCount
        let myGames = Array(myScores.prefix(games))
        let oppGames = Array(opponentScores.prefix(games))
        let name = opponent.trimmingCharacters(in: .whitespaces)
        let partnerName = discipline == .singles ? "" : partner.trimmingCharacters(in: .whitespaces)

        if let editing {
            editing.opponent = name
            editing.partner = partnerName
            editing.date = date
            editing.discipline = discipline
            editing.pointSystem = pointSystem
            editing.format = format
            editing.myGameScores = myGames
            editing.opponentGameScores = oppGames
            editing.notes = notes.isEmpty ? nil : notes
            editing.tournament = selectedTournament
            editing.opponentLevel = opponentLevel
            editing.intensity = intensity
        } else {
            context.insert(Match(
                date: date,
                opponent: name,
                partner: partnerName,
                discipline: discipline,
                pointSystem: pointSystem,
                format: format,
                myGameScores: myGames,
                opponentGameScores: oppGames,
                notes: notes.isEmpty ? nil : notes,
                opponentLevel: opponentLevel,
                intensity: intensity,
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
    let maximum: Int

    var body: some View {
        HStack {
            Text("Game \(gameNumber)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            ScoreStepper(label: "You", score: $myScore, tint: .green, maximum: maximum)
            ScoreStepper(label: "Opponent", score: $opponentScore, tint: .red, maximum: maximum)
        }
    }
}

/// Big tappable minus/plus flanking the score — feedback lands on press-down,
/// the haptic fires on the same frame as the number changes.
struct ScoreStepper: View {
    let label: String
    @Binding var score: Int
    let tint: Color
    var maximum: Int = 999

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
                // Never increase past the system's cap. An older score above
                // the cap (from before the rules were added) is left alone.
                score = min(score + 1, max(maximum, score))
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
